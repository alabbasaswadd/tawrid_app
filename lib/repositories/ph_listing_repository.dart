import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/core/network/api_client.dart';
import 'package:tawrid_app/core/network/api_endpoints.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';

final phListingRepositoryProvider = Provider<PhListingRepository>(
  (ref) => PhListingRepository(ref.watch(apiClientProvider)),
);

class PhListingRepository {
  PhListingRepository(this._api);
  final ApiClient _api;

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

  // ── تعليقات الإعلان ──────────────────────────────────────────────────────

  Future<List<PhListingComment>> getComments(String listingId) async {
    final raw = await _api.get(ApiEndpoints.phListingComments(listingId));
    return ApiClient.itemsOf(raw)
        .map((e) => PhListingComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PhListingComment> addComment(
    String listingId,
    String content, {
    String? parentId,
  }) async {
    final data = await _api.post(
      ApiEndpoints.phListingComments(listingId),
      data: {
        'content': content,
        'parentId': parentId,
      },
    ) as Map<String, dynamic>;
    return PhListingComment.fromJson(data);
  }

  /// الخادم يسمح للمؤلّف وحده بالحذف — نُخفي الزرّ عن غيره أصلاً.
  Future<void> deleteComment(String listingId, String commentId) =>
      _api.delete(ApiEndpoints.phListingCommentById(listingId, commentId));

  // ── الحجوزات ──────────────────────────────────────────────────────────────

  Future<PhListingBooking> createBooking(String listingId, String initialMessage) async {
    final data = await _api.post(
      ApiEndpoints.phListingBookings(listingId),
      data: {'initialMessage': initialMessage},
    ) as Map<String, dynamic>;
    return PhListingBooking.fromJson(data);
  }

  Future<List<PhListingBooking>> getBookings(String listingId) async {
    final raw = await _api.get(ApiEndpoints.phListingBookings(listingId));
    return ApiClient.itemsOf(raw)
        .map((e) => PhListingBooking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptBooking(String listingId, String bookingId) =>
      _api.post(ApiEndpoints.phListingBookingAccept(listingId, bookingId));

  Future<void> rejectBooking(String listingId, String bookingId) =>
      _api.post(ApiEndpoints.phListingBookingReject(listingId, bookingId));

  Future<List<PhListingMessage>> getMessages(String listingId, String bookingId) async {
    final raw = await _api.get(ApiEndpoints.phListingBookingMessages(listingId, bookingId));
    return ApiClient.itemsOf(raw)
        .map((e) => PhListingMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PhListingMessage> sendMessage(
      String listingId, String bookingId, String content) async {
    final data = await _api.post(
      ApiEndpoints.phListingBookingMessages(listingId, bookingId),
      data: {'content': content},
    ) as Map<String, dynamic>;
    return PhListingMessage.fromJson(data);
  }
}
