import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tawrid_app/app/router/routes.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/core/session/pharmacy_session.dart';
import 'package:tawrid_app/core/session/session_state.dart';
import 'package:tawrid_app/models/ph_listing_models.dart';
import 'package:tawrid_app/repositories/ph_listing_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

// تفاصيل الإعلان — عرضان مختلفان بحسب هوية المستخدم:
//   • المالك: يرى طلبات الحجز + قبول/رفض كل واحدة.
//   • المتصفّح: يرى التفاصيل الكاملة + زر «احجز وتواصل».
class PhListingDetailPage extends ConsumerStatefulWidget {
  const PhListingDetailPage({required this.listingId, super.key});
  final String listingId;

  @override
  ConsumerState<PhListingDetailPage> createState() =>
      _PhListingDetailPageState();
}

class _PhListingDetailPageState extends ConsumerState<PhListingDetailPage> {
  PhListingSummary? _listing;
  List<PhListingBooking> _bookings = const [];
  bool _loading = true;
  String? _error;
  String? _actionError;

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
      final repo = ref.read(phListingRepositoryProvider);
      final listing = await repo.getListing(widget.listingId);
      List<PhListingBooking> bookings = const [];
      if (_isOwner(listing)) {
        bookings = await repo.getBookings(widget.listingId);
      }
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _bookings = bookings;
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

  bool _isOwner(PhListingSummary listing) {
    final session = ref.read(pharmacySessionProvider).value;
    if (session is! SessionAuthenticated) return false;
    return session.tenantId == listing.pharmacyId;
  }

  Future<void> _book() async {
    final msg = await showDialog<String>(
      context: context,
      builder: (_) => const _BookingDialog(),
    );
    if (msg == null || !mounted) return;

    setState(() => _actionError = null);
    try {
      final booking = await ref
          .read(phListingRepositoryProvider)
          .bookListing(widget.listingId, msg);
      if (!mounted) return;
      context.push(TRoutes.phListingChat(widget.listingId, booking.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = ApiException.from(e).message);
    }
  }

  Future<void> _accept(PhListingBooking b) async {
    setState(() => _actionError = null);
    try {
      await ref
          .read(phListingRepositoryProvider)
          .acceptBooking(widget.listingId, b.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = ApiException.from(e).message);
    }
  }

  Future<void> _reject(PhListingBooking b) async {
    setState(() => _actionError = null);
    try {
      await ref
          .read(phListingRepositoryProvider)
          .rejectBooking(widget.listingId, b.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = ApiException.from(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const InnerTopBar(title: 'تفاصيل الإعلان'),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AppDetailSkeleton();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final l = _listing!;
    final isOwner = _isOwner(l);
    final cs = context.colors;
    final tk = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.x3l,
      ),
      children: [
        // ── بطاقة المعلومات الكاملة ────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tk.brandSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Center(
                      child: AppIcon(AppIcons.pill, size: 24,
                          color: cs.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.medicineName, style: context.text.titleLarge),
                        if (l.genericName != null)
                          Text(l.genericName!,
                              style: context.text.bodySmall
                                  ?.copyWith(color: tk.hint)),
                        if (l.manufacturer != null)
                          Text(l.manufacturer!,
                              style: context.text.bodySmall
                                  ?.copyWith(color: tk.hint)),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: l.reason.label,
                    tone: _reasonTone(l.reason),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(icon: AppIcons.package,
                  label: 'الكمية', value: '${l.quantity} وحدة'),
              _InfoRow(
                icon: AppIcons.tag,
                label: 'السعر',
                value: '${l.pricePerUnit.toStringAsFixed(0)} ل.س / الوحدة',
                valueStyle: context.priceBrandStyle,
              ),
              _InfoRow(icon: AppIcons.mapPin,
                  label: 'المنطقة',
                  value: l.city.isEmpty
                      ? l.governorate
                      : '${l.city}، ${l.governorate}'),
              _InfoRow(icon: AppIcons.user,
                  label: 'الصيدلية', value: l.pharmacyName),
              if (l.expiryDate != null)
                _InfoRow(
                  icon: AppIcons.clock,
                  label: 'تاريخ الانتهاء',
                  value:
                      '${l.expiryDate!.day}/${l.expiryDate!.month}/${l.expiryDate!.year}',
                  valueColor: tk.warning,
                ),
              if (l.notes != null && l.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('ملاحظات:',
                    style: context.text.labelMedium
                        ?.copyWith(color: tk.hint)),
                Text(l.notes!,
                    style: context.text.bodySmall
                        ?.copyWith(color: cs.onSurface)),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        if (_actionError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              _actionError!,
              style: context.text.bodySmall?.copyWith(color: tk.danger),
            ),
          ),

        // ── عرض المالك: طلبات الحجز ───────────────────────────────────────
        if (isOwner) ...[
          Text(
            'طلبات الحجز (${_bookings.length})',
            style: context.text.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_bookings.isEmpty)
            Text(
              'لا طلبات حجز بعد.',
              style: context.text.bodySmall?.copyWith(color: tk.hint),
            )
          else
            for (final b in _bookings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _BookingCard(
                  booking: b,
                  listingId: widget.listingId,
                  onAccept: () => _accept(b),
                  onReject: () => _reject(b),
                  onChat: () => context
                      .push(TRoutes.phListingChat(widget.listingId, b.id)),
                ),
              ),
        ],

        // ── عرض المتصفح: زر الحجز ─────────────────────────────────────────
        if (!isOwner && l.status == PhListingStatus.available)
          AppButton(
            label: 'احجز وتواصل مع البائع',
            icon: Icons.send_rounded,
            onPressed: _book,
          ),

        if (!isOwner && l.status == PhListingStatus.booked)
          AppButton(
            label: 'الإعلان محجوز حالياً',
            variant: AppButtonVariant.tonal,
            onPressed: null,
          ),
      ],
    );
  }

  static StatusTone _reasonTone(PhListingReason r) => switch (r) {
        PhListingReason.nearExpiry => StatusTone.warning,
        PhListingReason.slowMoving => StatusTone.neutral,
        PhListingReason.overstocked => StatusTone.info,
        PhListingReason.other => StatusTone.neutral,
      };
}

// ── صف معلومة واحدة داخل AppCard ─────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
    this.valueColor,
  });

  final AppIcons icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          AppIcon(icon, size: 15, color: tk.hint),
          const SizedBox(width: AppSpacing.sm),
          Text('$label: ',
              style: context.text.bodySmall?.copyWith(color: tk.hint)),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  context.text.bodySmall?.copyWith(
                    color: valueColor ?? context.colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── بطاقة طلب الحجز (للمالك) ─────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.listingId,
    required this.onAccept,
    required this.onReject,
    required this.onChat,
  });

  final PhListingBooking booking;
  final String listingId;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;
    final b = booking;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.bookerPharmacyName,
                        style: context.text.titleSmall),
                    if (b.bookerPhone.isNotEmpty)
                      Text(b.bookerPhone,
                          style: context.text.bodySmall
                              ?.copyWith(color: tk.hint)),
                  ],
                ),
              ),
              StatusBadge(
                label: b.status.label,
                tone: _bookingTone(b.status),
              ),
            ],
          ),
          if (b.initialMessage.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: tk.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                b.initialMessage,
                style: context.text.bodySmall
                    ?.copyWith(color: cs.onSurface),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (b.status == PhBookingStatus.pending) ...[
                Expanded(
                  child: AppButton(
                    label: 'قبول',
                    variant: AppButtonVariant.filled,
                    onPressed: onAccept,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'رفض',
                    variant: AppButtonVariant.tonal,
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (b.status != PhBookingStatus.rejected &&
                  b.status != PhBookingStatus.cancelled)
                Expanded(
                  child: AppButton(
                    label: b.unreadMessages > 0
                        ? 'المحادثة (${b.unreadMessages})'
                        : 'المحادثة',
                    variant: AppButtonVariant.tonal,
                    onPressed: onChat,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static StatusTone _bookingTone(PhBookingStatus s) => switch (s) {
        PhBookingStatus.pending => StatusTone.warning,
        PhBookingStatus.accepted => StatusTone.success,
        PhBookingStatus.rejected => StatusTone.danger,
        PhBookingStatus.cancelled => StatusTone.neutral,
      };
}

// ── حوار الحجز: رسالة ابتدائية للبائع ───────────────────────────────────────
class _BookingDialog extends StatefulWidget {
  const _BookingDialog();

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tk = context.tokens;

    return AlertDialog(
      title: const Text('احجز وتواصل'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أرسل رسالة للبائع مع طلب الحجز.',
            style: context.text.bodySmall?.copyWith(color: tk.hint),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'مثال: أنا مهتم بشراء الكمية كاملة، هل السعر قابل للتفاوض؟',
              hintStyle: context.text.bodySmall?.copyWith(color: tk.hint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: cs.outline),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () {
            final msg = _ctrl.text.trim();
            if (msg.isEmpty) return;
            Navigator.pop(context, msg);
          },
          child: Text('إرسال', style: TextStyle(color: cs.primary)),
        ),
      ],
    );
  }
}
