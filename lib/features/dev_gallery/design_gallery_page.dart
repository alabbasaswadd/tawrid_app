import 'package:flutter/material.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/shared/ui/ui.dart';

// معرض نظام التصميم — مرجع حي لكل المكوّنات بترتيب البناء (ذرّات ← بطاقات).
// للمعاينة أثناء التطوير: GoRoute إلى TRoutes.devGallery.
class DesignGalleryPage extends StatefulWidget {
  const DesignGalleryPage({super.key});

  @override
  State<DesignGalleryPage> createState() => _DesignGalleryPageState();
}

class _DesignGalleryPageState extends State<DesignGalleryPage> {
  int _qty = 20;
  int _chip = 0;
  bool _govExpanded = true;
  bool _itemSelected = true;
  final Set<String> _cities = {'سراقب'};

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: const InnerTopBar(title: 'نظام التصميم'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.x3l,
        ),
        children: [
          _section(context, 'الألوان'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _swatch(context, 'أساسي', context.colors.primary),
              _swatch(context, 'داكن', t.brandDeep),
              _swatch(context, 'سطح العلامة', t.brandSurface),
              _swatch(context, 'ذهبي', t.gold),
              _swatch(context, 'نجاح', t.success),
              _swatch(context, 'تحذير', t.warning),
              _swatch(context, 'خطأ', t.danger),
            ],
          ),

          _section(context, 'الخطوط'),
          Text('عنوان رئيسي ٢٢', style: context.text.displayMedium),
          Text('عنوان قسم ١٨', style: context.text.titleLarge),
          Text('عنوان عنصر ١٦', style: context.text.titleMedium),
          Text('نص أساسي ١٤', style: context.text.bodyMedium),
          Text('نص مساعد ١٢', style: context.text.bodySmall),
          Text('بيانات ثانوية ١١', style: context.text.labelSmall),
          Text('٣٢٤٬٠٠٠ ل.س — سعر وأرقام', style: context.priceBrandStyle),

          _section(context, 'الأزرار'),
          AppButton(label: 'أساسي', onPressed: () {}),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'ثانوي',
            variant: AppButtonVariant.outline,
            onPressed: () {},
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'نصي',
            variant: AppButtonVariant.text,
            onPressed: () {},
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'تحذيري',
            variant: AppButtonVariant.danger,
            onPressed: () {},
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppButton(label: 'معطل', onPressed: null),
          const SizedBox(height: AppSpacing.sm),
          AppButton(label: 'تحميل', loading: true, onPressed: () {}),

          _section(context, 'حقول الإدخال'),
          const AppTextField(label: 'رقم الهاتف', hint: 'أدخل رقم الهاتف'),

          _section(context, 'شريط البحث'),
          AppSearchBar(
            hint: 'ابحث عن دواء، مادة فعالة، أو مستودع…',
            onScanTap: () {},
          ),

          _section(context, 'الشارات'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              StatusBadge(label: 'مكتمل', tone: StatusTone.success),
              StatusBadge(label: 'قيد التجهيز', tone: StatusTone.brand),
              StatusBadge(label: 'بانتظار الرد', tone: StatusTone.warning),
              StatusBadge(label: 'مرفوض', tone: StatusTone.danger),
              StatusBadge(label: 'مسودة'),
              BonusBadge(label: 'بونص ١٠ + ٢'),
            ],
          ),

          _section(context, 'شرائح الفلترة'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (i, label) in [
                'الكل',
                'عروض البونص',
                'الأحدث',
              ].indexed)
                AppFilterChip(
                  label: label,
                  selected: _chip == i,
                  onTap: () => setState(() => _chip = i),
                ),
              AppFilterChip(label: 'قابلة للإزالة', onRemoved: () {}),
            ],
          ),

          _section(context, 'منتقي الكمية'),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: QuantityStepper(
              value: '$_qty',
              onIncrement: () => setState(() => _qty++),
              onDecrement: () => setState(() => _qty = _qty > 0 ? _qty - 1 : 0),
            ),
          ),

          _section(context, 'زر السلة'),
          Row(
            children: [
              CartButton(count: 0, onTap: () {}),
              const SizedBox(width: AppSpacing.lg),
              CartButton(count: 3, onTap: () {}),
              const SizedBox(width: AppSpacing.lg),
              CartButton(count: 128, onTap: () {}),
            ],
          ),

          _section(context, 'انتظار الأزرار (نقاط)'),
          Row(
            children: [
              AppButton(
                label: 'أضف للسلة',
                fullWidth: false,
                compact: true,
                loading: true,
                onPressed: () {},
              ),
              const SizedBox(width: AppSpacing.lg),
              AppButton(
                label: 'حفظ',
                fullWidth: false,
                loading: true,
                onPressed: () {},
              ),
            ],
          ),

          _section(context, 'أزرار أيقونة دائرية'),
          Row(
            children: [
              CircleIconButton(icon: AppIcons.search, onTap: () {}),
              const SizedBox(width: AppSpacing.lg),
              CircleIconButton(
                  icon: AppIcons.warehouse, bordered: true, onTap: () {}),
              const SizedBox(width: AppSpacing.lg),
              CircleIconButton(icon: AppIcons.sliders, bordered: true, onTap: () {}),
            ],
          ),

          _section(context, 'عدادات الملخص'),
          Row(
            children: [
              Expanded(
                child: SummaryCounter(
                  value: '٥',
                  label: 'طلبات جديدة',
                  icon: AppIcons.clipboardList,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SummaryCounter(
                  value: '٣',
                  label: 'عروض فعالة',
                  icon: AppIcons.tag,
                ),
              ),
            ],
          ),

          _section(context, 'بطاقة العرض — الحالات'),
          for (final status in OfferCardStatus.values) ...[
            OfferCard(
              title: 'حزمة المضادات الحيوية',
              itemsPreview: 'أموكسيسيلين ٥٠٠ · سيفترياكسون ١غ · +٣ أصناف',
              warehouse: 'مستودع الشفاء — دمشق',
              expiryText: status == OfferCardStatus.expiring
                  ? 'ينتهي خلال ٣ أيام'
                  : 'ينتهي في ٣٠ ذو الحجة',
              minOrderText: '٥ أصناف · الحد الأدنى: ٢٠ عبوة لكل صنف',
              totalPrice: '٣٢٤٬٠٠٠ ل.س',
              status: status,
              statusLabel: status == OfferCardStatus.bonus
                  ? 'بونص ١٠ + ٢'
                  : null,
              onAdd: () {},
              onDetails: () {},
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          _section(context, 'بطاقة الطلب'),
          OrderCard(
            title: 'طلب رقم TW-1024',
            subtitle: 'مستودع الشفاء — دمشق',
            metaText: 'أُنشئ في ١٢ ذو القعدة · ٨ أصناف',
            price: '٤٨٥٬٠٠٠ ل.س',
            statusLabel: 'قيد التجهيز',
            onDetails: () {},
          ),

          _section(context, 'صف صنف العرض'),
          const OfferItemRow(
            name: 'أموكسيسيلين ٥٠٠ ملغ',
            form: 'كبسول · ٢٠ كبسولة بالعبوة',
            unitPrice: '١٢٬٥٠٠ ل.س',
            bonusLabel: 'بونص ١٠ + ٢',
            availableText: 'الكمية المتاحة: ٢٠٠ عبوة',
          ),
          const SizedBox(height: AppSpacing.md),
          OfferItemRow(
            name: 'أموكسيسيلين ٥٠٠ ملغ',
            form: 'كبسول · ٢٠ كبسولة بالعبوة',
            unitPrice: '١٢٬٥٠٠ ل.س',
            bonusLabel: 'بونص ١٠ + ٢',
            mode: OfferItemRowMode.edit,
            onEdit: () {},
            onDelete: () {},
          ),
          const SizedBox(height: AppSpacing.md),
          OfferItemRow(
            name: 'أموكسيسيلين ٥٠٠ ملغ',
            form: 'كبسول · ٢٠ كبسولة بالعبوة',
            unitPrice: '١٢٬٥٠٠ ل.س',
            bonusLabel: 'بونص ١٠ + ٢',
            availableText: 'الكمية المتاحة: ٢٠٠ عبوة',
            mode: OfferItemRowMode.select,
            selected: _itemSelected,
            onSelectedChanged: (v) => setState(() => _itemSelected = v),
          ),

          _section(context, 'الحالات'),
          UiEmpty(
            description: 'جرّب تعديل كلمات البحث أو إزالة بعض الفلاتر',
            actionLabel: 'مسح الفلاتر',
            onAction: () {},
          ),
          UiError(onRetry: () {}),
          const OfferCardSkeleton(),

          _section(context, 'بطاقة عرض المستودع'),
          WarehouseOfferCard(
            title: 'حزمة المضادات الحيوية',
            itemsText: '٥ أصناف · بونص أصناف + ٥٪ على كامل العرض',
            expiryText: 'ينتهي في ٣٠ ذو الحجة ١٤٤٧',
            statusLabel: 'منشور',
            lastUpdateText: 'آخر تحديث: اليوم',
            onEdit: () {},
            onStop: () {},
          ),

          _section(context, 'بطاقة طلب تسعير'),
          TenderCard(
            title: 'طلب تسعير — أدوية القلب',
            itemsText: '٦ أصناف مطلوبة · كميات محددة',
            deadlineText: 'استقبال العروض حتى بعد غدٍ ٦ مساءً',
            deliveryText: 'التسليم: إدلب — سراقب',
            statusLabel: 'مفتوحة',
            offersCountLabel: '٤ عروض مستلمة',
            onCompare: () {},
          ),

          _section(context, 'منتقي مناطق التغطية'),
          GovernorateRow(
            name: 'إدلب',
            selection: _cities.isEmpty
                ? AppCheckState.none
                : (_cities.length == 3
                      ? AppCheckState.all
                      : AppCheckState.partial),
            countLabel: '${_cities.length} من ٣',
            expanded: _govExpanded,
            onTap: () => setState(() => _govExpanded = !_govExpanded),
            onCheckboxTap: () => setState(
              () => _cities.length == 3
                  ? _cities.clear()
                  : _cities.addAll(['سراقب', 'معرة النعمان', 'أريحا']),
            ),
          ),
          if (_govExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                children: [
                  for (final city in ['سراقب', 'معرة النعمان', 'أريحا'])
                    CityRow(
                      name: city,
                      selected: _cities.contains(city),
                      onTap: () => setState(
                        () => _cities.contains(city)
                            ? _cities.remove(city)
                            : _cities.add(city),
                      ),
                    ),
                ],
              ),
            ),

          _section(context, 'الأيقونات'),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              for (final icon in AppIcons.values)
                AppIcon(icon, size: 24, color: context.colors.onSurface),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.x2l, bottom: AppSpacing.md),
    child: Text(title, style: context.text.titleLarge),
  );

  Widget _swatch(BuildContext context, String label, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 64,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: context.colors.outline),
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(label, style: context.text.labelSmall),
    ],
  );
}
