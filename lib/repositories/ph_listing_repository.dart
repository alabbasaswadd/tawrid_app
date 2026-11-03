import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';

final phListingRepositoryProvider = Provider<PhListingRepository>(
  (ref) => PhListingRepository(
    ref.watch(apiClientProvider),
    ref.watch(pharmacySessionProvider).value,
  ),
);

class PhListingRepository {
  PhListingRepository(this._api, this._session);
  final ApiClient _api;
  final SessionState? _session;

  String get _myId {
    final s = _session;
    if (s is SessionAuthenticated) return s.tenantId ?? '';
    return '';
  }

  // ── إعلانات عامة (التصفح) ────────────────────────────────────────────────

  Future<List<PhListingSummary>> getListings({
    String? governorate,
    String? city,
    PhListingReason? reason,
    String? search,
    int limit = 30,
    int offset = 0,
  }) async {
    final raw = await _api.get(ApiEndpoints.phPublicListings, queryParameters: {
      'limit': limit,
      'offset': offset,
      'governorate': governorate,
      'city': city,
      if (reason != null) 'reason': reason.code,
      if (search != null && search.isNotEmpty) 'q': search,
    });
    return ApiClient.itemsOf(raw)
        .map((e) => PhListingSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PhListingSummary> getListing(String id) async {
    final data = await _api.get(ApiEndpoints.phListingById(id)) as Map<String, dynamic>;
    return PhListingSummary.fromJson(data);
  }

  // ── إعلاناتي ──────────────────────────────────────────────────────────────

  Future<List<PhListingSummary>> getMyListings() async {
    final raw = await _api.get(ApiEndpoints.phMyListings);
    return ApiClient.itemsOf(raw)
        .map((e) => PhListingSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PhListingSummary> createListing(CreatePhListingRequest req) async {
    final data = await _api.post(
      ApiEndpoints.phPublicListings,
      data: req.toJson(),
    ) as Map<String, dynamic>;
    return PhListingSummary.fromJson(data);
  }

  Future<void> markSold(String id) => _api.post(ApiEndpoints.phListingSold(id));

  Future<void> cancelListing(String id) =>
      _api.post(ApiEndpoints.phListingCancel(id));

  // ── حجوزات الإعلان ────────────────────────────────────────────────────────

  Future<List<PhListingBooking>> getBookings(String listingId) async {
    final raw = await _api.get(ApiEndpoints.phListingBookings(listingId));
    return ApiClient.itemsOf(raw)
        .map((e) => PhListingBooking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// الصيدلي 2 يحجز الإعلان ويرسل أول رسالة.
  Future<PhListingBooking> bookListing(String listingId, String message) async {
    final data = await _api.post(
      ApiEndpoints.phListingBookings(listingId),
      data: {'initialMessage': message},
    ) as Map<String, dynamic>;
    return PhListingBooking.fromJson(data);
  }

  Future<void> acceptBooking(String listingId, String bookingId) =>
      _api.post(ApiEndpoints.phListingBookingAccept(listingId, bookingId));

  Future<void> rejectBooking(String listingId, String bookingId) =>
      _api.post(ApiEndpoints.phListingBookingReject(listingId, bookingId));

  // ── محادثة الحجز ──────────────────────────────────────────────────────────

  Future<List<PhListingMessage>> getMessages(
    String listingId,
    String bookingId,
  ) async {
    final raw =
        await _api.get(ApiEndpoints.phListingMessages(listingId, bookingId));
    final myId = _myId;
    return ApiClient.itemsOf(raw)
        .map((e) =>
            PhListingMessage.fromJson(e as Map<String, dynamic>, myId))
        .toList();
  }

  Future<PhListingMessage> sendMessage(
    String listingId,
    String bookingId,
    String content,
  ) async {
    final data = await _api.post(
      ApiEndpoints.phListingMessages(listingId, bookingId),
      data: {'content': content},
    ) as Map<String, dynamic>;
    return PhListingMessage.fromJson(data, _myId);
  }
}
