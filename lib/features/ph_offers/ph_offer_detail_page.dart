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
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/comments_sheet.dart';
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
  bool _submitting = false;
  String? _error;

  /// معرّف الصنف ← الكمية المطلوبة. وجود المفتاح يعني أن الصنف مُحدَّد.
  final Map<String, int> _selected = {};

  /// متحكّمات حقول الكمية — تُنشأ عند التحديد وتُتلف عند الإلغاء.
  final Map<String, TextEditingController> _qtyControllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offer =
          await ref.read(salesOfferRepositoryProvider).getOfferById(widget.offerId);
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
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggle(SalesOfferItem item, bool selected) {
    setState(() {
      if (selected) {
        final initial = _maxFor(item);
        _selected[item.id] = initial;
        _qtyControllers[item.id] = TextEditingController(text: '$initial');
      } else {
        _selected.remove(item.id);
        _qtyControllers.remove(item.id)?.dispose();
      }
    });
  }

  void _setQuantity(SalesOfferItem item, int value) {
    final max = _maxFor(item);
    final clamped = value.clamp(1, max);
    setState(() => _selected[item.id] = clamped);
    // تصحيح النص في الحقل إذا تجاوز الحد الأقصى.
    if (clamped != value) {
      final ctrl = _qtyControllers[item.id];
      if (ctrl != null) {
        final text = '$clamped';
        ctrl.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  }

  double get _selectedTotal {
    final items = _offer?.items ?? const <SalesOfferItem>[];
    var total = 0.0;
    for (final i in items) {
      final qty = _selected[i.id];
      if (qty != null) total += _netUnitPrice(i) * qty;
    }
    return total;
  }

  bool get _canOrder {
    final o = _offer;
    return o != null &&
        _selected.isNotEmpty &&
        o.status == SalesOfferStatus.active &&
        !_submitting;
  }

  /// يُضيف الأصناف المحدَّدة إلى السلّة — لا يُنشئ طلبية.
  ///
  /// الإضافة صنفاً صنفاً عبر `addOfferItem`: الخادم هو من يقرأ سعر الصنف
  /// وحسمه وسلّم بونصه ويُجمّدها في السطر، فلا يُرسَل من هنا سعرٌ ولا بونص
  /// — وهو ما يمنع اختلاف ما في السلّة عمّا في العرض.
  ///
  /// والفشل جزئيّ لا كلّي: صنفٌ لم يعد متاحاً لا يُسقِط إضافة بقيّته، ويُقال
  /// عددُ ما نجح وما أخفق صراحةً.
  Future<void> _addSelectedToCart() async {
    final offer = _offer;
    if (offer == null || _selected.isEmpty) return;

    final chosen =
        offer.items.where((i) => _selected.containsKey(i.id)).toList();

    setState(() => _submitting = true);
    var added = 0;
    String? firstError;

    try {
      final cart = ref.read(cartProvider.notifier);
      for (final item in chosen) {
        final qty = _selected[item.id] ?? _maxFor(item);
        try {
          await cart.addOfferItem(item.id, quantity: qty);
          added++;
        } catch (e) {
          firstError ??= ApiException.from(e).message;
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }

    if (!mounted) return;

    if (added == 0) {
      AppSnackbar.error(context, firstError ?? 'تعذّرت الإضافة إلى السلّة');
      return;
    }

    setState(() => _selected.clear());

    final failed = chosen.length - added;
    AppSnackbar.success(
      context,
      failed == 0
          ? 'أُضيف $added ${added == 1 ? 'صنف' : 'أصناف'} إلى السلّة'
          : 'أُضيف $added، وتعذّر $failed — ${firstError ?? ''}',
    );
  }

  void _openComments() {
    final repo = ref.read(salesOfferRepositoryProvider);
    CommentsSheet.show(
      context,
      loadComments: () => repo.getPharmacyComments(widget.offerId),
      addComment: (text) => repo.addPharmacyComment(widget.offerId, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InnerTopBar(
        title: 'تفاصيل العرض',
        trailing: IconButton(
          icon: const Icon(Icons.chat_bubble_outline, size: 20),
          tooltip: 'التعليقات',
          onPressed: _loading ? null : _openComments,
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.x3l),
      children: [
        _HeaderCard(offer: offer),

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
            form: [
              '${item.unit} · الكمية ${item.quantity.toStringAsFixed(0)}',
              if (item.discountPercentage != null)
                'حسم ${item.discountPercentage!.toStringAsFixed(0)}٪',
            ].join(' · '),
            unitPrice: formatMoneyWith(_netUnitPrice(item), offer.currency),
            bonusLabel: item.bonusLabel,
            availableText:
                'الكمية المتاحة: ${item.quantity.toStringAsFixed(0)} ${item.unit}',
            mode: OfferItemRowMode.select,
            selected: _selected.containsKey(item.id),
            onSelectedChanged: (v) => _toggle(item, v),
          ),
          // حقل الكمية يظهر عند التحديد فقط — حقل نصي للإدخال المباشر.
          if (_selected.containsKey(item.id))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Text('الكمية المطلوبة',
                      style: context.text.bodySmall?.copyWith(color: tk.hint)),
                  const Spacer(),
                  SizedBox(
                    width: 72,
                    child: TextFormField(
                      controller: _qtyControllers[item.id],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v.trim());
                        if (n != null && n > 0) _setQuantity(item, n);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ ${_maxFor(item)} ${item.unit}',
                    style: context.text.bodySmall?.copyWith(color: tk.hint),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],

        if (offer.bonusMedicineName != null || offer.items.any((i) => i.hasBonus))
          _BonusExplainer(offer: offer),

        if (offer.consignmentTerms != null && offer.consignmentTerms!.isNotEmpty) ...[
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

  // الشريط السفلي الثابت (Figma): إجمالي المحدد + زر الإضافة بعدد المحدد.
  Widget _buildBottomBar() {
    final cs = context.colors;
    final tk = context.tokens;
    final offer = _offer!;
    final count = _selected.length;
    final closed = offer.status != SalesOfferStatus.active;
    final inCart = ref.watch(cartCountProvider);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline)),
          boxShadow: tk.navShadow,
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('إجمالي المحدد',
                    style: context.text.labelSmall?.copyWith(color: tk.hint)),
                Text(formatMoneyWith(_selectedTotal, offer.currency),
                    style: context.priceBrandStyle),
                // ما في السلّة أصلاً يُقال هنا: بعد الإضافة يحتاج الصيدلي
                // أن يعرف أين ذهب ما أضافه وكيف يُتمّه.
                if (inCart > 0)
                  GestureDetector(
                    onTap: () => context.push(TRoutes.phCart),
                    child: Text(
                      'في سلّتك $inCart — إتمام الطلبية',
                      style: context.text.labelSmall
                          ?.copyWith(color: context.colors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: closed
                    ? 'العرض ${offer.status.label}'
                    : count == 0
                        ? 'اختر صنفاً لإضافته'
                        : 'إضافة المحدد إلى السلّة ($count)',
                icon: Icons.add_shopping_cart,
                loading: _submitting,
                onPressed: _canOrder ? _addSelectedToCart : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// بطاقة رأس العرض (Figma): العنوان وشارة البونص، ثم أسطر البيانات، ثم
// شريط بونص العرض الكامل إن وُجد.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.offer});
  final SalesOfferDetail offer;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final hasBonus = offer.bonusMedicineName != null ||
        offer.items.any((i) => i.hasBonus);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(offer.title, style: context.text.titleLarge)),
              if (hasBonus) const BonusBadge(label: 'يشمل بونص', compact: true),
            ],
          ),
          const SizedBox(height: 10),
          _MetaLine(icon: AppIcons.warehouse, text: offer.warehouseName),
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
                      style: context.text.bodySmall
                          ?.copyWith(color: tk.goldStrong),
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
              Text('كيف يُحسب البونص؟',
                  style: context.text.titleSmall?.copyWith(color: tk.goldStrong)),
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
