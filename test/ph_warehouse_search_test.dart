// «ابحث عنه في المستودعات» — قسم الدواء نفسه وقسم البدائل بالتركيب.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawrid_app/app/theme/app_theme.dart';
import 'package:tawrid_app/core/cart/cart_controller.dart';
import 'package:tawrid_app/features/ph_medicines/ph_price_search_page.dart';
import 'package:tawrid_app/models/medicine_search_models.dart';
import 'package:tawrid_app/repositories/medicine_search_repository.dart';

MedicineSearchResult _r({
  required String name,
  required MedicineMatchKind kind,
  bool offer = false,
  double price = 1000,
}) =>
    MedicineSearchResult(
      resultType:
          offer ? MedicineResultType.offer : MedicineResultType.warehouseListing,
      matchKind: kind,
      salesOfferItemId: offer ? 'OI-$name' : null,
      warehouseMedicineId: offer ? null : 'WM-$name',
      supplyWarehouseId: 'W1',
      warehouseName: 'مستودع الشفاء',
      city: 'إدلب',
      governorate: 'إدلب',
      unitPrice: price,
      netUnitPrice: price,
      currency: 'SYP',
      unit: 'عبوة',
      medicineName: name,
      genericName: 'Amoxicillin',
    );

class _FakeRepo implements MedicineSearchRepository {
  _FakeRepo(this.items);
  final List<MedicineSearchResult> items;

  bool? sawIncludeAlternatives;
  String? sawCatalogItemId;

  @override
  Future<MedicineSearchPage> search({
    String? name,
    String? catalogItemId,
    String? warehouseId,
    String? manufacturer,
    MedicineSearchSource source = MedicineSearchSource.all,
    MedicineSearchSort sort = MedicineSearchSort.byDefault,
    bool includeAlternatives = false,
    int limit = 20,
    int offset = 0,
  }) async {
    sawIncludeAlternatives = includeAlternatives;
    sawCatalogItemId = catalogItemId;
    return MedicineSearchPage(items: items, totalCount: items.length);
  }

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _app(
  _FakeRepo repo, {
  bool alternatives = true,
  String? catalogItemId = 'C1',
}) =>
    ProviderScope(
      overrides: [
        medicineSearchRepositoryProvider.overrideWithValue(repo),
        cartCountProvider.overrideWithValue(0),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: PhPriceSearchPage(
            catalogItemId: catalogItemId,
            includeAlternatives: alternatives,
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    // النتائج طويلة عمودياً — شاشة مرتفعة تمنع تجاوز الحدود في الاختبار.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('القسمان: الدواء نفسه ثم البدائل بالتركيب', (tester) async {
    tester.view.physicalSize = const Size(393, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeRepo([
      _r(name: 'أموكسيل ٥٠٠', kind: MedicineMatchKind.sameMedicine),
      _r(name: 'أموكسيسيلين الفارابي', kind: MedicineMatchKind.sameComposition),
    ]);

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // العلَم وصل الخادم مع معرّف صنف الكتالوج.
    expect(repo.sawIncludeAlternatives, isTrue);
    expect(repo.sawCatalogItemId, 'C1');

    expect(find.text('توفّره في المستودعات'), findsOneWidget);
    expect(find.text('هذا الدواء'), findsOneWidget);
    expect(find.text('بدائل بالتركيب العلمي نفسه'), findsOneWidget);
    expect(find.text('أموكسيل ٥٠٠'), findsOneWidget);
    expect(find.text('أموكسيسيلين الفارابي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('بلا الدواء نفسه: سطرٌ يوضّح أنّ ما يلي بدائل', (tester) async {
    tester.view.physicalSize = const Size(393, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeRepo([
      _r(name: 'أموكسيسيلين الفارابي', kind: MedicineMatchKind.sameComposition),
    ]);

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('هذا الدواء'), findsNothing);
    expect(
      find.textContaining('لا مستودع يخدم مدينتك يعرض هذا الدواء بعينه'),
      findsOneWidget,
    );
    expect(find.text('بدائل بالتركيب العلمي نفسه'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('بحث عادي بلا بدائل: لا قسم مطابقة أصلاً', (tester) async {
    tester.view.physicalSize = const Size(393, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeRepo([
      _r(name: 'أموكسيل ٥٠٠', kind: MedicineMatchKind.sameMedicine),
    ]);

    await tester.pumpWidget(
      _app(repo, alternatives: false, catalogItemId: null),
    );
    await tester.pumpAndSettle();

    expect(repo.sawIncludeAlternatives, isFalse);
    expect(find.text('هذا الدواء'), findsNothing);
    expect(find.text('بدائل بالتركيب العلمي نفسه'), findsNothing);
    // التقسيم بالمصدر يبقى كما كان.
    expect(find.text('تسعير مباشر من المستودعات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
