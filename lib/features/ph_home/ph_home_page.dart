import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/cart/cart_controller.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/supply_order_models.dart';
import 'package:tawrid_app/repositories/notification_repository.dart';
import 'package:tawrid_app/repositories/pharmacy_profile_repository.dart';
import 'package:tawrid_app/repositories/supply_order_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

// الحالات الجارية: من بانتظار الموافقة إلى جاري الشحن (لا مكتملة ولا ملغاة).
const _activeStatuses = {
  SupplyOrderStatus.pending,
  SupplyOrderStatus.confirmed,
  SupplyOrderStatus.processing,
  SupplyOrderStatus.shipped,
};

// الرئيسية (الصيدلي).
//
// مرتَّبة بحسب ما يفعله الصيدلي لا بحسب ما يملكه التطبيق من شاشات:
//   ١ ابحث عن دواء        — شريط بحث يفتح البحث المقارن بالنصّ أو بالباركود
//   ٢ ما الذي ينتظرك الآن — شريط تنبيه واحد: سلّة لم تُتمَّ، أو طلب قيد التوصيل
//   ٣ ابدأ عملاً جديداً    — إجراء رئيسي واحد بارز، ثم إجراءان ثانويان
//   ٤ صيدلي إلى صيدلي والتقارير — ميزات ثانوية أسفل الصفحة
//
// الطلبيات الجارية لها تبويبها المستقل، فلا تُكرَّر هنا. تبقى قائمتها
// محمَّلة لغرض واحد: شريط «طلبك قيد التوصيل». الشاشة تُرسَم فوراً ولا
// تنتظر تلك الشبكة.
class PhHomePage extends ConsumerStatefulWidget {
  const PhHomePage({super.key});

  @override
  ConsumerState<PhHomePage> createState() => _PhHomePageState();
}

class _PhHomePageState extends ConsumerState<PhHomePage> {
  List<SupplyOrderSummary> _activeOrders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await ref
          .read(supplyOrderRepositoryProvider)
          .getMyOrders(limit: 100);
      if (!mounted) return;
      setState(() {
        _activeOrders = orders
            .where((o) => _activeStatuses.contains(o.status))
            .toList();
      });
    } catch (_) {
      // شريط «قيد التوصيل» زينةٌ مفيدة لا عمود الشاشة: فشل قراءته يُخفيه
      // ولا يُسقط الرئيسية. الخطأ نفسه يظهر في تبويب الطلبيات حيث يَهُمّ.
      if (mounted) setState(() => _activeOrders = const []);
    }
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير،';
    if (h < 17) return 'طاب يومك،';
    return 'مساء الخير،';
  }

  /// «صنف واحد» · «صنفان» · «٥ أصناف» · «١٢ صنفاً» — الرقم وحده يُقرأ
  /// ببطء في سطر عربي.
  static String _itemsLabel(int n) => switch (n) {
    1 => 'صنف واحد',
    2 => 'صنفان',
    _ when n <= 10 => '$n أصناف',
    _ => '$n صنفاً',
  };

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(pharmacyMeProvider);
    final unread = ref.watch(phUnreadCountProvider).value ?? 0;

    return Scaffold(
      appBar: WelcomeTopBar(
        greeting: _greeting(),
        name: me.value?.pharmacyName ?? 'صيدليتي',
        hasUnread: unread > 0,
        onNotificationsTap: () => context.push(TRoutes.phNotifications),
        actions: [
          CartButton(
            count: ref.watch(cartCountProvider),
            onTap: () => context.push(TRoutes.phCart),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final cartCount = ref.watch(cartCountProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.x3l,
      ),
      children: [
        // ١ — ما الذي ينتظرك: تنبيه واحد لا أكثر، وإلا صار ضجيجاً.
        ..._alertStrip(cartCount),

        const SizedBox(height: AppSpacing.xl),

        // ٣ — ابدأ عملاً جديداً: إجراء رئيسي واحد بارز يسبق الباقي.
        _ActionTile(
          icon: AppIcons.package,
          label: 'طلبية جديدة',
          subtitle: 'ابحث عن دواء، قارن أسعاره، وأضفه إلى السلّة',
          primary: true,
          onTap: () => context.push(TRoutes.phPriceSearch),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: AppIcons.fileText,
                label: 'طلب تسعير',
                onTap: () => context.push(TRoutes.phCreateTender),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ActionTile(
                icon: AppIcons.pill,
                label: 'كتالوج الأدوية',
                onTap: () => context.push(TRoutes.phMedicineSearch),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // كاتالوج المستودعات — سؤالٌ غير سؤال الكتالوج الوطني: ذاك مرجعٌ
        // دوائي، وهذا سوقٌ حيّ يُشترى منه. فله مدخلُه الخاصّ لا تابٌ مطويّ.
        _ActionTile(
          icon: AppIcons.warehouse,
          label: 'كاتالوج المستودعات',
          onTap: () => context.push(TRoutes.phWarehouseCatalog),
        ),

        const SizedBox(height: AppSpacing.x2l),

        // ٤ — ميزات ثانوية.
        _PhToPhBanner(
          onBrowse: () => context.push(TRoutes.phListings),
          onMyListings: () => context.push(TRoutes.phMyListings),
        ),

        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: AppIcons.clipboardList,
                label: 'تقرير مشترياتي',
                onTap: () => context.push(TRoutes.phReports),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ActionTile(
                icon: AppIcons.search,
                label: 'بحث عن دواء',
                onTap: () => context.push(TRoutes.phPriceSearch),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// تنبيه واحد بأولوية واضحة: سلّة لم تُتمَّ أولاً (عملٌ بدأه الصيدلي ولم
  /// ينهه)، وإلا طلبٌ قيد التوصيل (ما ينتظره منّا).
  List<Widget> _alertStrip(int cartCount) {
    if (cartCount > 0) {
      return [
        const SizedBox(height: AppSpacing.md),
        _AlertStrip(
          icon: AppIcons.shoppingCart,
          title: 'في سلّتك ${_itemsLabel(cartCount)}',
          subtitle: 'اضغط لإتمام الطلبية',
          tone: _AlertTone.brand,
          onTap: () => context.push(TRoutes.phCart),
        ),
      ];
    }

    final shipping = _activeOrders
        .where((o) => o.status == SupplyOrderStatus.shipped)
        .firstOrNull;
    if (shipping != null) {
      return [
        const SizedBox(height: AppSpacing.md),
        _AlertStrip(
          icon: AppIcons.truck,
          title: 'طلبك ${shipping.orderNumber} قيد التوصيل',
          subtitle: 'اضغط لتتبّع مراحل التسليم',
          tone: _AlertTone.info,
          onTap: () => context.push(TRoutes.phOrderDetail(shipping.id)),
        ),
      ];
    }

    return const [];
  }
}

// ── شريط التنبيه ─────────────────────────────────────────────────────────
enum _AlertTone { brand, info }

// سطر واحد يقول «هذا ما ينتظرك»: أيقونة في بداية القراءة، عنوان وسطر
// إرشاد، وشيفرون في نهايتها.
class _AlertStrip extends StatelessWidget {
  const _AlertStrip({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  final AppIcons icon;
  final String title;
  final String subtitle;
  final _AlertTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    final (Color surface, Color accent) = switch (tone) {
      _AlertTone.brand => (tk.brandSurface, cs.primary),
      _AlertTone.info => (tk.successSurface, tk.success),
    };

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(child: AppIcon(icon, size: 18, color: accent)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall?.copyWith(color: accent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: context.text.labelSmall?.copyWith(color: tk.hint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppIcon(AppIcons.chevronForwardRtl, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ── بلاطة إجراء ──────────────────────────────────────────────────────────
// نمطان من مكوّن واحد: [primary] إجراء الشاشة الرئيسي — بعرض كامل وبلون
// العلامة وشيفرون؛ والعادي بلاطة هادئة تُصفّ جنب أختها.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.primary = false,
  });

  final AppIcons icon;
  final String label;
  final String? subtitle;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    final fg = primary ? cs.onPrimary : cs.onSurface;
    final iconBg = primary ? cs.onPrimary.withValues(alpha: 0.16) : cs.primary;
    final iconFg = primary ? cs.onPrimary : cs.onPrimary;

    return Material(
      color: primary ? cs.primary : cs.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: primary ? cs.primary : cs.outline),
            boxShadow: tk.cardShadow,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: primary ? 14 : AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: primary ? 40 : 32,
                height: primary ? 40 : 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: AppIcon(icon, size: primary ? 20 : 16, color: iconFg),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style:
                          (primary
                                  ? context.text.titleMedium
                                  : context.text.titleSmall)
                              ?.copyWith(color: fg),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: context.text.labelSmall?.copyWith(
                          color: fg.withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (primary) ...[
                const SizedBox(width: AppSpacing.sm),
                AppIcon(AppIcons.chevronForwardRtl, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// بانر «صيدلي إلى صيدلي» — يعرّف بالميزة ويفتح تصفح الإعلانات أو إعلاناتي.
class _PhToPhBanner extends StatelessWidget {
  const _PhToPhBanner({required this.onBrowse, required this.onMyListings});

  final VoidCallback onBrowse;
  final VoidCallback onMyListings;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tk.brandSurface, tk.brandSurfaceSubtle],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.primary.withValues(alpha: .18)),
        boxShadow: tk.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AppIcon(AppIcons.pill, size: 18, color: cs.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  // «صيدلي إلى صيدلي» اسمٌ اصطلاحي لا يقول ما يفعله القسم:
                  // الصيدلي يقرؤه فلا يعرف أيبيع أم يشتري. فصار العنوان
                  // يسمّي الفعل، والسطر تحته يخاطبه مباشرةً.
                  child: Text(
                    'بيع واشترِ من زملائك الصيادلة',
                    style: context.text.titleMedium?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              // الشرح السابق ذكر البيع وحده، والقسم وجهان: الصيدلي بائعٌ
              // لفائضه ومشترٍ من فائض غيره — وإغفال الشقّ الثاني كان يترك
              // زرّ التصفّح بلا سبب ظاهر.
              'عندك دواء كاسد أو قاربت صلاحيته؟ أعلن عنه لصيادلة منطقتك.\n'
              'ناقصك صنف؟ تصفّح ما يعرضه زملاؤك وتواصل معهم مباشرةً.',
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                // هذان نداءا البانر الرئيسيان لا زرّا بطاقةٍ في قائمة، فيأخذان
                // ارتفاع الزرّ القياسي من الثيم: ٣٢ كان يضغط النصّ فيبهت.
                Expanded(
                  child: AppButton(
                    // «تصفح الإعلانات» فعلٌ بلا مفعول: إعلاناتُ مَن؟ الاسم
                    // يسمّي القسم، ويطابق عنوان الشاشة التي يفتحها.
                    label: 'إعلانات الصيادلة',
                    icon: Icons.search,
                    variant: AppButtonVariant.tonal,
                    onPressed: onBrowse,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'إعلاناتي',
                    icon: Icons.sell_outlined,
                    onPressed: onMyListings,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
