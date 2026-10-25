import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawrid_app/app/theme/app_colors.dart';
import 'package:tawrid_app/app/theme/app_spacing.dart';
import 'package:tawrid_app/app/theme/app_tokens_ext.dart';
import 'package:tawrid_app/core/network/api_exception.dart';
import 'package:tawrid_app/models/enums.dart';
import 'package:tawrid_app/models/tender_models.dart';
import 'package:tawrid_app/repositories/tender_repository.dart';
import 'package:tawrid_app/shared/ui/ui.dart';
import 'package:tawrid_app/shared/utils/relative_time.dart';
import 'package:tawrid_app/shared/widgets/app_states.dart';

Color _offerStatusColor(TenderOfferStatus s) => switch (s) {
      TenderOfferStatus.submitted => TawridColors.statusPending,
      TenderOfferStatus.accepted => TawridColors.success,
      TenderOfferStatus.rejected => TawridColors.error,
    };

class WhTendersPage extends ConsumerStatefulWidget {
  const WhTendersPage({super.key});

  @override
  ConsumerState<WhTendersPage> createState() => _WhTendersPageState();
}

class _WhTendersPageState extends ConsumerState<WhTendersPage> {
  List<MyTenderOfferSummary>? _offers;
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
      final list = await ref.read(tenderRepositoryProvider).getMyOffers();
      setState(() {
        _offers = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiException.from(e).message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عروضي على المناقصات'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final offers = _offers ?? [];
    if (offers.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            message:
                'لا توجد عروض مُقدَّمة بعد\nتصفّح "مناقصات مفتوحة" من الصفحة الرئيسية للتقدّم بعرض',
            icon: Icons.gavel_outlined,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        final color = _offerStatusColor(offer.status);
        final expired = offer.tenderExpiresAt.isBefore(DateTime.now());
        final cs = context.colors;
        final tk = context.tokens;

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.tenderTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(left: 5),
                            decoration:
                                BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          Flexible(
                            child: Text(
                              '${_statusLabel(offer.status, offer.isSelectedByPharmacy)} · ${offer.offerType.label} · ${formatSmartTimestamp(offer.createdOn)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall
                                  ?.copyWith(color: tk.hint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        expired
                            ? 'انتهت المناقصة ${formatSmartTimestamp(offer.tenderExpiresAt)}'
                            : 'تنتهي المناقصة ${formatSmartTimestamp(offer.tenderExpiresAt)}',
                        style: context.text.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(TenderOfferStatus status, bool selected) {
    if (selected) return 'تم اختياره فوزاً';
    return status.label;
  }
}
