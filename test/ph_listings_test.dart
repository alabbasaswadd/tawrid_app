// بطاقة الإعلان الجديدة، وصفحة التفاصيل بالتعليقات بدل الحجز.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawrid_app/app/theme/app_theme.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/features/ph_listings/ph_listing_detail_page.dart';
import 'package:tawrid_app/features/ph_listings/widgets/ph_listing_card.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';
import 'package:tawrid_app/repositories/ph_listing_repository.dart';

final _listing = PhListingSummary(
  id: 'L1',
  medicineName: 'أموكسيسيلين ٥٠٠ ملغ',
  manufacturer: 'الفارابي',
  quantity: 20,
  pricePerUnit: 12500,
  expiryDate: DateTime(2027, 3, 1),
  reason: PhListingReason.nearExpiry,
  notes: 'الكمية كاملة فقط',
  governorate: 'إدلب',
  city: 'إدلب',
  pharmacyId: 'OWNER',
  pharmacyName: 'صيدلية العباس',
  status: PhListingStatus.available,
  createdOn: DateTime.now().subtract(const Duration(hours: 3)),
  listingExpiresAt: DateTime.now().add(const Duration(days: 2)),
);

PhListingComment _c(String id, String who, String whoId, String body) =>
    PhListingComment(
      id: id,
      authorType: CommentAuthorType.pharmacy,
      authorId: whoId,
      authorName: who,
      content: body,
      createdOn: DateTime.now().subtract(const Duration(minutes: 20)),
    );

class _FakeRepo implements PhListingRepository {
  List<PhListingComment> comments = [
    _c('c1', 'صيدلية النور', 'VIEWER2', 'هل السعر قابل للتفاوض؟'),
    _c('c2', 'صيدلية العباس', 'OWNER', 'نعم للكمية كاملة.'),
  ];
  String? lastPosted;

  @override
  Future<PhListingSummary> getListing(String id) async => _listing;

  @override
  Future<List<PhListingComment>> getComments(String listingId) async =>
      comments;

  @override
  Future<PhListingComment> addComment(
    String listingId,
    String content, {
    String? parentId,
  }) async {
    lastPosted = content;
    return _c('c3', 'صيدلية الأمل', 'ME', content);
  }

  @override
  Future<void> deleteComment(String listingId, String commentId) async {}

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Session extends PharmacySessionNotifier {
  _Session(this.tenant);
  final String tenant;
  @override
  Future<SessionState> build() async =>
      SessionAuthenticated(token: 't', tenantId: tenant);
}

Widget _app(Widget home, String tenant, _FakeRepo repo) => ProviderScope(
      overrides: [
        phListingRepositoryProvider.overrideWithValue(repo),
        pharmacySessionProvider.overrideWith(() => _Session(tenant)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        home: Directionality(textDirection: TextDirection.rtl, child: home),
      ),
    );

void main() {
  testWidgets('بطاقة الإعلان: السعر بارز والإجمالي محسوب', (tester) async {
    tester.view.physicalSize = const Size(393, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: PhListingCard(listing: _listing, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('سعر الوحدة'), findsOneWidget);
    expect(find.text('12,500 ل.س'), findsOneWidget);
    expect(find.text('20 وحدة'), findsOneWidget);
    expect(find.text('الإجمالي 250,000 ل.س'), findsOneWidget);
    expect(find.text('صيدلية العباس'), findsOneWidget);
    expect(find.text('إدلب، إدلب'), findsOneWidget);
    // لا أثر للحجز.
    expect(find.textContaining('حجز'), findsNothing);
    expect(find.text('التفاصيل والتعليقات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('التفاصيل: التعليقات باسم الصيدلية + النشر', (tester) async {
    tester.view.physicalSize = const Size(393, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeRepo();
    await tester.pumpWidget(
      _app(const PhListingDetailPage(listingId: 'L1'), 'ME', repo),
    );
    await tester.pumpAndSettle();

    // قسم التعليقات بعددها، وأسماء الصيدليات ظاهرة.
    expect(find.text('التعليقات (2)'), findsOneWidget);
    expect(find.text('صيدلية النور'), findsOneWidget);
    expect(find.text('هل السعر قابل للتفاوض؟'), findsOneWidget);
    expect(find.text('نعم للكمية كاملة.'), findsOneWidget);
    // تعليق صاحب الإعلان مُميَّز.
    expect(find.text('صاحب الإعلان'), findsOneWidget);

    // لا حجز ولا محادثة.
    expect(find.textContaining('احجز'), findsNothing);
    expect(find.textContaining('طلبات الحجز'), findsNothing);

    // انشر تعليقاً.
    await tester.enterText(find.byType(TextField), 'هل تقبل نصف الكمية؟');
    await tester.pumpAndSettle();
    await tester.tap(find.text('نشر التعليق'));
    await tester.pumpAndSettle();

    expect(repo.lastPosted, 'هل تقبل نصف الكمية؟');
    expect(find.text('التعليقات (3)'), findsOneWidget);
    expect(find.text('صيدلية الأمل (أنت)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
