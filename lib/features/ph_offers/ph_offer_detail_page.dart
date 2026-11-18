import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/cart/cart_controller.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/repositories/conversation_repository.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/chat_sheet.dart';
import 'package:tawrid_app/shared/widgets/quantity_dialog.dart';
import 'package:tawrid_app/shared/widgets/offer_summary_card.dart';

/// سعر الوحدة بعد الحسم.
double _netUnitPrice(SalesOfferItem i) =>
    i.unitPrice * (1 - (i.discountPercentage ?? 0) / 100);

// تفاصيل العرض للصيدلي (Figma: الصيدلي / تفاصيل العرض).
//
// الشاشة ليست للقراءة فقط: منها تُنشأ الطلبية. الصيدلي يختار ما يحتاجه من
// أصناف العرض ويحدّد كمية كلٍّ منها — ليس ملزماً بالعرض كاملاً.
class PhOfferDetailPage extends ConsumerStatefulWidget {
  const PhOfferDetailPage({required this.offerId, super.key});

  final String offerId;

  @override
  ConsumerState<PhOfferDetailPage> createState() => _PhOfferDetailPageState();
}

class _PhOfferDetailPageState extends ConsumerState<PhOfferDetailPage> {
  SalesOfferDetail? _offer;
  bool _loading = true;
  String? _error;

  /// معرّف الصنف الجاري إضافته — يُظهر التحميل على زرّه وحده.
  String? _addingItemId;

  /// فتح المحادثة جارٍ — يمنع فتح محادثتين بضغطتين متتاليتين.
  bool _contacting = false;

  final _scrollCtrl = ScrollController();

  /// هل غابت بطاقة الرأس عن الشاشة؟ عندها يحمل الشريط اسم المستودع بدل
  /// «تفاصيل العرض» — فيبقى مصدر العرض ظاهراً بعد أن يمرّ الرأس.
  bool _headerGone = false;

  /// العتبة: ارتفاع تقريبي لبطاقة الرأس. لا نقيسها فعلياً لأن تبديل
  /// العنوان لا يحتمل دقّة البكسل، وقياسها يستدعي مفتاحاً عالمياً وإطاراً
  /// إضافياً عند كل بناء.
  static const double _headerThreshold = 120;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    final gone =
        _scrollCtrl.hasClients && _scrollCtrl.offset > _headerThreshold;
    if (gone != _headerGone) setState(() => _headerGone = gone);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offer = await ref
          .read(salesOfferRepositoryProvider)
          .getOfferById(widget.offerId);
      if (!mounted) return;
      setState(() {
        _offer = offer;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  // الكمية الافتراضية هي كامل ما يعرضه المستودع للصنف، والصيدلي ينزل منها.
  int _maxFor(SalesOfferItem i) => i.quantity < 1 ? 1 : i.quantity.round();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// يُضيف صنفاً واحداً إلى السلّة بعد حوار الكمية.
  ///
  /// الحوار هو المشترك نفسه المستعمَل في بحث الأسعار والكتالوج: يبدأ من
  /// أصغر عتبة بونص ويقفز بخطوتها ويُظهر ما سيُنال مجاناً عند كل كمية.
  /// حقلٌ نصّي حرّ كان يُدخل الصيدلي كمية تفوّت عتبةً بفارق وحدة بلا أن
  /// يدري.
  ///
  /// ولا يُرسَل من هنا سعر ولا بونص: الخادم يقرأ سعر الصنف وحسمه وسلّم
  /// بونصه ويُجمّدها في السطر — وهو ما يمنع اختلاف ما في السلّة عمّا في
  /// العرض.
  Future<void> _addItem(SalesOfferItem item) async {
    final offer = _offer;
    if (offer == null || _addingItemId != null) return;

    final qty = await showQuantityDialog(
      context,
      medicineName: item.medicineName,
      initialQuantity: 1,
      maxQuantity: _maxFor(item),
      tiers: item.bonusTiers,
      unit: item.unit,
      unitPrice: _netUnitPrice(item),
      currency: offer.currency,
      warehouseName: offer.warehouseName,
      hint: item.quantity <= 0
          ? 'كمية مفتوحة'
          : 'المتاح في العرض: ${item.quantity.toStringAsFixed(0)} ${item.unit}',
    );
    if (qty == null || !mounted) return;

    setState(() => _addingItemId = item.id);
    try {
      await ref
          .read(cartProvider.notifier)
          .addOfferItem(item.id, quantity: qty);
      if (!mounted) return;
      AppSnackbar.success(context, 'أُضيف ${item.medicineName} إلى السلّة');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _addingItemId = null);
    }
  }

  /// يفتح محادثة مع مستودع العرض بنصٍّ مبدئي يذكر العرض.
  ///
  /// النصّ مسوّدة لا رسالة مُرسَلة: يظهر في حقل الكتابة ليعدّله المستخدم
  /// أو يمحوه. إرسالٌ تلقائي باسمه لشيء لم يقرأه ليس تسهيلاً.
  ///
  /// وفائدته أن المستودع يستقبل سؤالاً يعرف سياقه من أول سطر، بدل
  /// «السلام عليكم» مجرّدة يتبعها سؤال «أيّ عرض تقصد؟».
  Future<void> _contactWarehouse() async {
    final offer = _offer;
    if (offer == null || _contacting) return;

    setState(() => _contacting = true);
    try {
      final conv = await ref
          .read(phConversationRepositoryProvider)
          .openConversation(otherPartyId: offer.supplyWarehouseId);
      if (!mounted) return;

      context.push(
        TRoutes.phConversationDetail(
          conv.id,
          conv.otherPartyName,
          draft: 'السلام عليكم، بخصوص عرض «${offer.title}»',
        ),
      );
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  void _openComments() {
    final repo = ref.read(salesOfferRepositoryProvider);
    ChatSheet.show(
      context,
      title: 'دردشة مع المستودع',
      currentUserType: 'pharmacy',
      loadMessages: () => repo.getPharmacyComments(widget.offerId),
      sendMessage: (text) => repo.addPharmacyComment(widget.offerId, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    // بعد مرور بطاقة الرأس يحلّ اسم العرض محلّ العنوان العام، والمستودع
    // تحته: المستخدم يعرف أنه في «تفاصيل العرض» بمجرّد وصوله، والمفيد
    // بعدها هو أيّ عرضٍ يتصفّح ومن أين — وهما ما غابا مع البطاقة.
    final scrolled = _headerGone && _offer != null;

    return Scaffold(
      appBar: InnerTopBar(
        title: scrolled ? _offer!.title : 'تفاصيل العرض',
        subtitle: scrolled ? _offer!.warehouseName : null,
        // نصّ لا أيقونة: فقاعة الحوار تُقرأ «محادثة مع المستودع» وهي
        // التعليقات العامة على العرض — وزرّ «تواصل» في البطاقة يفتح
        // المحادثة الخاصّة فعلاً. التسمية تفصل بينهما.
        trailing: TextButton(
          onPressed: _loading ? null : _openComments,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('التعليقات'),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _offer == null ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final offer = _offer!;
    final tk = context.tokens;

    // بطاقة الرأس تمرّ مع المحتوى لا فوقه: تثبيتها كان يقتطع ثلث الشاشة
    // دائماً، وما يحتاجه الصيدلي بعد قراءتها مرّة هو مساحة للأصناف. ما
    // يبقى منها مفيداً — اسم المستودع — ينتقل إلى الشريط العلوي.
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      children: [
        _HeaderCard(
          offer: offer,
          onContact: _contactWarehouse,
          contacting: _contacting,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('أصناف العرض', style: context.text.titleLarge),
        const SizedBox(height: 2),
        Text(
          'اختر ما تحتاجه من الأصناف — الطلبية تُنشأ بأصنافها والكميات التي تحددها.',
          style: context.text.bodySmall?.copyWith(color: tk.hint),
        ),
        const SizedBox(height: AppSpacing.md),

        for (final item in offer.items) ...[
          OfferItemRow(
            name: item.medicineName,
            // الشركة الصانعة أولاً: هي أول ما يميّز صنفاً عن مثيله
            // عند الصيدلي. تُغفَل للأصناف غير المرتبطة بالكتالوج.
            form: [
              if (item.manufacturerName != null &&
                  item.manufacturerName!.isNotEmpty)
                item.manufacturerName!,
              item.quantity <= 0
                  ? item.unit
                  : '${item.unit} · الكمية ${item.quantity.toStringAsFixed(0)}',
              if (item.discountPercentage != null)
                'حسم ${item.discountPercentage!.toStringAsFixed(0)}٪',
            ].join(' · '),
            unitPrice: formatMoneyWith(_netUnitPrice(item), offer.currency),
            bonusLabel: item.bonusLabel,
            availableText: item.quantity <= 0
                ? 'كمية مفتوحة'
                : 'الكمية المتاحة: ${item.quantity.toStringAsFixed(0)} ${item.unit}',
            // إجراءا الصنف داخل بطاقته: الإضافة تمرّ بحوار الكمية الواعي
            // بالبونص، والمقارنة تُخرج إلى بحث الأسعار محصوراً بهذا الصنف.
            actions: [
              AppButton(
                label: 'أضف للسلة',
                icon: Icons.add,
                fullWidth: false,
                compact: true,
                loading: _addingItemId == item.id,
                onPressed: offer.status != SalesOfferStatus.active
                    ? null
                    : () => _addItem(item),
              ),
              if (item.catalogItemId != null)
                AppButton(
                  label: 'مقارنة الأسعار',
                  icon: Icons.compare_arrows,
                  fullWidth: false,
                  compact: true,
                  variant: AppButtonVariant.tonal,
                  onPressed: () => context.push(
                    TRoutes.phPriceCompareItem(
                      catalogItemId: item.catalogItemId,
                      name: item.medicineName,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        if (offer.bonusMedicineName != null ||
            offer.items.any((i) => i.hasBonus))
          _BonusExplainer(offer: offer),

        if (offer.consignmentTerms != null &&
            offer.consignmentTerms!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('شروط الدفع', style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(offer.consignmentTerms!, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // الشريط السفلي صار جسراً إلى السلّة لا زرّ إضافة: الإضافة انتقلت إلى
  // كل صنف بحواره. ويُخفى حين تكون السلّة فارغة فلا يأكل مساحة بلا وعد.
  Widget? _buildBottomBar() {
    final inCart = ref.watch(cartCountProvider);
    if (inCart == 0) return null;

    final cs = context.colors;
    final tk = context.tokens;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline)),
          boxShadow: tk.navShadow,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.md,
        ),
        child: AppButton(
          label: 'إتمام الطلبية — في سلّتك $inCart',
          icon: Icons.shopping_cart_checkout,
          onPressed: () => context.push(TRoutes.phCart),
        ),
      ),
    );
  }
}

// بطاقة رأس العرض (Figma): العنوان وشارة البونص، ثم أسطر البيانات، ثم
// شريط بونص العرض الكامل إن وُجد.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.offer,
    required this.onContact,
    required this.contacting,
  });

  final SalesOfferDetail offer;

  /// فتح محادثة مع مستودع العرض.
  final VoidCallback onContact;
  final bool contacting;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final hasBonus =
        offer.bonusMedicineName != null || offer.items.any((i) => i.hasBonus);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(offer.title, style: context.text.titleLarge),
              ),
              if (hasBonus) const BonusBadge(label: 'يشمل بونص', compact: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetaLine(
                  icon: AppIcons.warehouse,
                  text: offer.warehouseName,
                ),
              ),
              // التواصل بجوار اسم المستودع لا في شريط منفصل: السؤال عن
              // العرض يخطر وأنت تقرأ مَن يعرضه.
              AppButton(
                label: 'تواصل',
                icon: Icons.chat_bubble_outline,
                fullWidth: false,
                compact: true,
                variant: AppButtonVariant.tonal,
                loading: contacting,
                onPressed: onContact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _MetaLine(
            icon: AppIcons.clock,
            text: offerExpiryText(offer.expiresAt),
            color: isOfferExpiringSoon(offer.expiresAt) ? tk.warning : null,
          ),
          const SizedBox(height: 6),
          _MetaLine(
            icon: AppIcons.package,
            text: '${offer.items.length} أصناف · العملة: ${offer.currency}',
          ),
          if (offer.description != null && offer.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(offer.description!, style: context.text.bodySmall),
          ],
          if (offer.bonusMedicineName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tk.goldSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: tk.gold),
              ),
              child: Row(
                children: [
                  AppIcon(AppIcons.gift, size: 16, color: tk.goldStrong),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'بونص العرض: '
                      '${offer.bonusMedicineQuantity?.toStringAsFixed(0) ?? ''} '
                      '${offer.bonusMedicineUnit ?? ''} '
                      '${offer.bonusMedicineName} مجاناً مع الطلبية',
                      style: context.text.bodySmall?.copyWith(
                        color: tk.goldStrong,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (offer.targetRegions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: cs.outline),
            const SizedBox(height: 10),
            Text(
              'يغطي: ${offer.targetRegions.map((r) => r.label).join(' · ')}',
              style: context.text.labelSmall?.copyWith(color: tk.hint),
            ),
          ],
        ],
      ),
    );
  }
}

// بطاقة «كيف يُحسب البونص؟» (Figma) — البونص مستويان ويُربك بلا شرح.
class _BonusExplainer extends StatelessWidget {
  const _BonusExplainer({required this.offer});
  final SalesOfferDetail offer;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tk.goldSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tk.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.gift, size: 16, color: tk.goldStrong),
              const SizedBox(width: 6),
              Text(
                'كيف يُحسب البونص؟',
                style: context.text.titleSmall?.copyWith(color: tk.goldStrong),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'للبونص مستويان: نسبة بونص لكل صنف تظهر بجانبه، وبونص على العرض '
            'كاملاً يُمنح مرة واحدة مع الطلبية. الإجمالي أدناه لا يشمل قيمة '
            'البونص — البونص يُسلَّم عيناً لا حسماً.',
            style: context.text.bodySmall?.copyWith(color: tk.goldStrong),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text, this.color});
  final AppIcons icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.onSurfaceVariant;
    return Row(
      children: [
        AppIcon(icon, size: 15, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: context.text.bodySmall?.copyWith(color: c)),
        ),
      ],
    );
  }
}

// ورقة تأكيد الإضافة إلى السلّة — تعرض ملخّص الأصناف والإجمالي قبل التنفيذ.
