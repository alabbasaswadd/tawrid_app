import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/announcement_models.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/models/warehouse_models.dart';
import 'package:tawrid_app/repositories/announcement_repository.dart';
import 'package:tawrid_app/repositories/conversation_repository.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/repositories/warehouse_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/money.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';
import 'package:tawrid_app/shared/widgets/offer_summary_card.dart';

// ملف المستودع كما تراه الصيدلية: بيانات تعريفية + مدن الخدمة + عروضه
// السارية. لا شيء داخلي هنا (لا موظفين ولا طلبيات) — الخادم لا يُرجعه أصلاً.
//
// العروض تُجلب بـ `GET /offers?warehouseId=` فتمرّ بنفس فلتر التغطية: ما
// يظهر هنا هو ما يحقّ لهذه الصيدلية رؤيته، لا كل عروض المستودع.
class PhWarehouseProfilePage extends ConsumerStatefulWidget {
  const PhWarehouseProfilePage({required this.warehouseId, super.key});

  final String warehouseId;

  @override
  ConsumerState<PhWarehouseProfilePage> createState() =>
      _PhWarehouseProfilePageState();
}

class _PhWarehouseProfilePageState
    extends ConsumerState<PhWarehouseProfilePage> {
  WarehouseProfile? _profile;
  List<SalesOfferSummary> _offers = const [];
  WarehouseAnnouncement? _announcement;
  bool _loading = true;
  String? _error;

  /// كم منطقة تُعرَض قبل الطيّ. مستودعٌ يغطّي محافظةً كاملة قد يُدرج ١٨٦
  /// موضعاً، فعرضُها كلها جدارُ شرائح يدفن ما تحته.
  static const int _areasPreview = 10;
  bool _areasExpanded = false;

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
      final profile = await ref
          .read(warehouseRepositoryProvider)
          .getProfile(widget.warehouseId);
      final offers = await ref
          .read(salesOfferRepositoryProvider)
          .getAvailableOffers(warehouseId: widget.warehouseId, limit: 30);
      final announcement = await ref
          .read(announcementRepositoryProvider)
          .getActiveAnnouncement(widget.warehouseId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _offers = offers;
        _announcement = announcement;
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

  Future<void> _contactWarehouse() async {
    final p = _profile!;
    try {
      final conv = await ref
          .read(phConversationRepositoryProvider)
          .openConversation(otherPartyId: p.id);
      if (!mounted) return;
      context.push(
        TRoutes.phConversationDetail(
          conv.id,
          conv.otherPartyName,
          partyId: conv.otherPartyId,
          partyType: conv.otherPartyType,
        ),
      );
    } catch (e) {
      if (mounted) AppSnackbar.error(context, ApiException.from(e).message);
    }
  }

  // شاشة التفاصيل الكاملة: منها تُنشأ الطلبية، وفيها التعليقات.
  void _openDetails(SalesOfferSummary offer) =>
      context.push(TRoutes.phOfferDetail(offer.id));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'ملف المستودع'),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final p = _profile!;
    final tk = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.x3l,
      ),
      children: [
        if (_announcement != null && _announcement!.isActive) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                AppIcon(AppIcons.tag, size: 20, color: context.colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _announcement!.title,
                        style: context.text.titleSmall,
                      ),
                      Text(
                        _announcement!.discountLabel,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                      if (_announcement!.body != null)
                        Text(
                          _announcement!.body!,
                          style: context.text.bodySmall?.copyWith(
                            color: tk.hint,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        // بطاقة الهوية (Figma: ملف المستودع) — صورة دائرية، الاسم، سطر
        // المدينة وسنة الانضمام، وشارة الاعتماد في الطرف المقابل.
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: context.text.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          '${p.governorate} - ${p.city} · '
                          'يعمل على توريد منذ ${p.createdOn.year}',
                          style: context.text.bodySmall?.copyWith(
                            color: tk.hint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: tk.brandSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppIcon(
                        AppIcons.warehouse,
                        size: 26,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // «معتمد» ليست مجاملة: الخادم لا يُرجع ملف مستودع إلا وهو
              // نشط ومقبول، فالشارة صادقة بحكم الوصول إلى هذه الشاشة.
              Row(
                children: [
                  StatusBadge(
                    label: 'معتمد على المنصّة',
                    tone: StatusTone.success,
                    icon: Icons.verified_outlined,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  StatusBadge(label: p.code, tone: StatusTone.neutral),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              _Line(
                icon: Icons.place_outlined,
                text: p.servesAllAreas
                    ? 'يخدم كل المناطق — لم يحدّد مدناً بعينها'
                    : 'يغطي: ${p.serviceAreas.take(3).join('، ')}'
                          '${p.serviceAreas.length > 3 ? ' — ${p.serviceAreas.length} مدن' : ''}',
              ),
              _Line(icon: Icons.phone_outlined, text: p.phone),
              _Line(
                icon: Icons.sell_outlined,
                text:
                    '${p.activeOffersCount} '
                    '${p.activeOffersCount == 1 ? 'عرض ساري' : 'عروض سارية'}',
              ),
              // عملة أسعاره — تُقال صراحةً لأن المنصّة لا تحوّل: أرقام هذا
              // المستودع كلها بها، وقد تخالف عملة صيدلية الزائر.
              _Line(
                icon: Icons.payments_outlined,
                text:
                    'يسعّر بـ${currencyName(p.pricingCurrency)}'
                    ' (${currencySymbol(p.pricingCurrency)})',
              ),

              // إحصائيات الأداء — تُظهر فقط إذا أرسلها الخادم
              if (p.avgAcceptanceDays != null || p.avgDeliveryDays != null) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                Text('إحصائيات الأداء', style: context.text.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        label: 'متوسط القبول',
                        value: p.avgAcceptanceDays != null
                            ? '${p.avgAcceptanceDays!.toStringAsFixed(1)} يوم'
                            : 'غير متاح',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatChip(
                        label: 'متوسط التسليم',
                        value: p.avgDeliveryDays != null
                            ? '${p.avgDeliveryDays!.toStringAsFixed(1)} يوم'
                            : 'غير متاح',
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.md),
              // عروضه السارية أدناه لا تُظهر إلا ما جمّعه في عروض. البحث
              // هنا يصل إلى كل أصنافه — عروضاً وتسعيراً مباشراً — بالاسم
              // أو بالباركود، ومنه تُضاف الأصناف إلى السلّة.
              AppButton(
                label: 'ابحث عن دواء في هذا المستودع',
                icon: Icons.search,
                variant: AppButtonVariant.tonal,
                onPressed: () => context.push(
                  TRoutes.phPriceSearchInWarehouse(p.id, p.name),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'تواصل مع هذا المستودع',
                icon: Icons.chat_outlined,
                variant: AppButtonVariant.outline,
                onPressed: _contactWarehouse,
              ),
            ],
          ),
        ),

        if (!p.servesAllAreas && p.serviceAreas.length > 3) ...[
          const SizedBox(height: AppSpacing.lg),
          // العنوان وزرّ الطيّ في سطر واحد أعلى القائمة: مع ١٨٦ شريحة
          // يصير زرٌّ أسفلها بعيداً عن متناول من فتحها، فيُطوى من حيث
          // فُتح.
          Row(
            children: [
              Expanded(
                child: Text(
                  'مناطق الخدمة (${p.serviceAreas.length})',
                  style: context.text.titleSmall,
                ),
              ),
              if (p.serviceAreas.length > _areasPreview)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _areasExpanded = !_areasExpanded),
                  icon: Icon(
                    _areasExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    _areasExpanded
                        ? 'طيّ'
                        : 'عرض الكل (${p.serviceAreas.length})',
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final area
                  in _areasExpanded
                      ? p.serviceAreas
                      : p.serviceAreas.take(_areasPreview))
                Chip(
                  label: Text(area, style: context.text.bodySmall),
                  visualDensity: VisualDensity.compact,
                ),
              // شريحةٌ تقول كم بقي، وتفتح الباقي بنقرة — فالعدد المطويّ
              // مرئيّ حيث انقطعت القائمة لا في الزرّ أعلاها وحده.
              if (!_areasExpanded && p.serviceAreas.length > _areasPreview)
                ActionChip(
                  label: Text(
                    '+${p.serviceAreas.length - _areasPreview}',
                    style: context.text.bodySmall,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _areasExpanded = true),
                ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        Text(
          'عروضه السارية (${_offers.length})',
          style: context.text.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_offers.isEmpty)
          Text(
            p.activeOffersCount > 0
                // الفارق بين العدّاد والقائمة يعني أن عروضه الحالية لا تستهدف
                // منطقة هذه الصيدلية — نقولها صراحةً بدل إظهار «لا عروض».
                ? 'لديه ${p.activeOffersCount} عرض ساري، لكن لا شيء منها يستهدف '
                      'منطقتك حالياً.'
                : 'لا عروض سارية من هذا المستودع حالياً.',
            style: context.text.bodySmall?.copyWith(color: tk.hint),
          )
        else
          // نفس بطاقة العروض في الرئيسية وشاشة العروض — البطاقة واحدة في
          // كل موضع يعرض فيه الصيدلي عرضاً.
          for (final offer in _offers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: OfferSummaryCard(
                offer: offer,
                onAdd: () => _openDetails(offer),
                onDetails: () => _openDetails(offer),
              ),
            ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.bodySmall?.copyWith(
              color: tk.hint,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.text.titleSmall?.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: tk.hint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(color: tk.hint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
