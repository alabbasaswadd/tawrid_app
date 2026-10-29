import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/sales_offer_models.dart';
import 'package:tawrid_app/models/warehouse_models.dart';
import 'package:tawrid_app/repositories/sales_offer_repository.dart';
import 'package:tawrid_app/repositories/warehouse_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
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

class _PhWarehouseProfilePageState extends ConsumerState<PhWarehouseProfilePage> {
  WarehouseProfile? _profile;
  List<SalesOfferSummary> _offers = const [];
  bool _loading = true;
  String? _error;

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
      final profile =
          await ref.read(warehouseRepositoryProvider).getProfile(widget.warehouseId);
      final offers = await ref
          .read(salesOfferRepositoryProvider)
          .getAvailableOffers(warehouseId: widget.warehouseId, limit: 30);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _offers = offers;
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
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.x3l),
      children: [
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
                          style: context.text.bodySmall?.copyWith(color: tk.hint),
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
                      child: AppIcon(AppIcons.warehouse,
                          size: 26, color: context.colors.primary),
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
                      icon: Icons.verified_outlined),
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
                text: '${p.activeOffersCount} '
                    '${p.activeOffersCount == 1 ? 'عرض ساري' : 'عروض سارية'}',
              ),
            ],
          ),
        ),

        if (!p.servesAllAreas && p.serviceAreas.length > 3) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('مناطق الخدمة', style: context.text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final area in p.serviceAreas)
                Chip(
                  label: Text(area, style: context.text.bodySmall),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        Text('عروضه السارية (${_offers.length})', style: context.text.titleLarge),
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
            child: Text(text,
                style: context.text.bodySmall?.copyWith(color: tk.hint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
