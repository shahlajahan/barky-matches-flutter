import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_booking_detail_page.dart';

enum PetTaxiRideFilter { active, completed, cancelled }

const Set<String> _cancelledPetTaxiStatuses = {
  'cancelled_by_user',
  'cancelled_by_business',
  'refund_pending',
  'refunded',
  // Planning-era request documents may still exist in migrated data.
  'cancelled',
  'timeout',
  'no_driver_found',
};

@visibleForTesting
PetTaxiRideFilter petTaxiRideFilterForStatus(String? value) {
  final status = value?.trim().toLowerCase() ?? '';
  if (status == 'completed' || status == 'rated') {
    return PetTaxiRideFilter.completed;
  }
  if (_cancelledPetTaxiStatuses.contains(status)) {
    return PetTaxiRideFilter.cancelled;
  }
  return PetTaxiRideFilter.active;
}

@visibleForTesting
DateTime? petTaxiRideDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
}

@visibleForTesting
int comparePetTaxiRides(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
) {
  final firstGroup = petTaxiRideFilterForStatus(first['status']?.toString());
  final secondGroup = petTaxiRideFilterForStatus(second['status']?.toString());
  final groupComparison = firstGroup.index.compareTo(secondGroup.index);
  if (groupComparison != 0) return groupComparison;

  final firstDate =
      petTaxiRideDate(first['scheduledAt']) ??
      petTaxiRideDate(first['createdAt']);
  final secondDate =
      petTaxiRideDate(second['scheduledAt']) ??
      petTaxiRideDate(second['createdAt']);
  if (firstDate == null && secondDate == null) return 0;
  if (firstDate == null) return 1;
  if (secondDate == null) return -1;

  if (firstGroup == PetTaxiRideFilter.active) {
    return firstDate.compareTo(secondDate);
  }
  return secondDate.compareTo(firstDate);
}

class PetTaxiMyRidesTab extends StatefulWidget {
  const PetTaxiMyRidesTab({super.key});

  @override
  State<PetTaxiMyRidesTab> createState() => _PetTaxiMyRidesTabState();
}

class _PetTaxiMyRidesTabState extends State<PetTaxiMyRidesTab> {
  PetTaxiRideFilter _filter = PetTaxiRideFilter.active;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _ridesStream;
  String? _streamUserId;

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamFor(String userId) {
    if (_ridesStream == null || _streamUserId != userId) {
      _streamUserId = userId;
      _ridesStream = FirebaseFirestore.instance
          .collection('pet_taxi_bookings')
          .where('userId', isEqualTo: userId)
          .snapshots();
    }
    return _ridesStream!;
  }

  void _retry(String userId) {
    setState(() {
      _streamUserId = null;
      _ridesStream = null;
    });
    _streamFor(userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          return const _SignedOutState();
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _streamFor(user.uid),
          builder: (context, ridesSnapshot) {
            if (ridesSnapshot.hasError) {
              return _RidesErrorState(onRetry: () => _retry(user.uid));
            }
            if (ridesSnapshot.connectionState == ConnectionState.waiting &&
                !ridesSnapshot.hasData) {
              return const _RidesLoadingState();
            }

            final rides = ridesSnapshot.data?.docs.toList() ?? [];
            rides.sort((a, b) => comparePetTaxiRides(a.data(), b.data()));
            return _RidesContent(
              rides: rides,
              filter: _filter,
              onFilterChanged: (value) => setState(() => _filter = value),
            );
          },
        );
      },
    );
  }
}

class _RidesContent extends StatelessWidget {
  const _RidesContent({
    required this.rides,
    required this.filter,
    required this.onFilterChanged,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> rides;
  final PetTaxiRideFilter filter;
  final ValueChanged<PetTaxiRideFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = rides
        .where(
          (ride) =>
              petTaxiRideFilterForStatus(ride.data()['status']?.toString()) ==
              filter,
        )
        .toList();

    return CustomScrollView(
      key: const PageStorageKey('petTaxiMyRidesScroll'),
      slivers: [
        SliverToBoxAdapter(child: _RidesHeader(rideCount: rides.length)),
        SliverToBoxAdapter(
          child: _RideFilters(selected: filter, onSelected: onFilterChanged),
        ),
        if (rides.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _NoRidesState(),
          )
        else if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyFilterState(message: l10n.petTaxiNoRidesInFilter),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final ride = filtered[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RideCard(bookingId: ride.id, data: ride.data()),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RidesHeader extends StatelessWidget {
  const _RidesHeader({required this.rideCount});

  final int rideCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4F9B), Color(0xFF9E1B4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.navigation, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.myRides,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.h2(
                        color: colors.onSurface,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.petTaxiRidesSubtitle,
                      style: AppTheme.body(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (rideCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    rideCount.toString(),
                    style: AppTheme.badge(color: colors.onPrimaryContainer),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RideFilters extends StatelessWidget {
  const _RideFilters({required this.selected, required this.onSelected});

  final PetTaxiRideFilter selected;
  final ValueChanged<PetTaxiRideFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      PetTaxiRideFilter.active: l10n.petTaxiFilterActive,
      PetTaxiRideFilter.completed: l10n.petTaxiFilterCompleted,
      PetTaxiRideFilter.cancelled: l10n.petTaxiFilterCancelled,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SegmentedButton<PetTaxiRideFilter>(
            showSelectedIcon: false,
            segments: PetTaxiRideFilter.values
                .map(
                  (filter) => ButtonSegment(
                    value: filter,
                    label: Text(
                      labels[filter]!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            selected: {selected},
            onSelectionChanged: (values) => onSelected(values.first),
          ),
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.bookingId, required this.data});

  final String bookingId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final status = _normalizedText(data['status'], fallback: 'pending');
    final statusStyle = _statusStyle(context, status);
    final businessName = _normalizedText(
      data['businessName'],
      fallback: l10n.petTaxiProviderFallback,
    );
    final petName = _normalizedText(
      data['petName'],
      fallback: l10n.petFallback,
    );
    final pickup = _normalizedText(
      data['pickupAddress'],
      fallback: l10n.locationNotAvailable,
    );
    final destination = _normalizedText(
      data['dropoffAddress'],
      fallback: l10n.locationNotAvailable,
    );
    final scheduledAt =
        petTaxiRideDate(data['scheduledAt']) ??
        petTaxiRideDate(data['createdAt']);
    final price = _priceText(data, l10n);
    final payment = _paymentText(data, l10n);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PetTaxiBookingDetailPage(bookingId: bookingId),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusStyle.background,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      LucideIcons.car,
                      size: 21,
                      color: statusStyle.foreground,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodyMedium(
                            color: colors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${l10n.petTaxiProviderLabel} • $petName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.caption(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _StatusBadge(
                      label: _statusLabel(status, l10n),
                      style: statusStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RouteLine(
                icon: LucideIcons.mapPin,
                iconColor: colors.primary,
                label: l10n.pickupLabel,
                value: pickup,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 9),
                child: Container(
                  width: 2,
                  height: 14,
                  color: colors.outlineVariant,
                ),
              ),
              _RouteLine(
                icon: LucideIcons.flag,
                iconColor: colors.tertiary,
                label: l10n.petTaxiDestinationLabel,
                value: destination,
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  _Fact(
                    icon: LucideIcons.calendarClock,
                    text: scheduledAt == null
                        ? l10n.petTaxiScheduleUnavailable
                        : _localizedDateTime(context, scheduledAt),
                  ),
                  _Fact(icon: LucideIcons.wallet, text: price),
                  _Fact(icon: LucideIcons.creditCard, text: payment),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.caption(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body(
                  color: colors.onSurface,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.caption(
              color: colors.onSurfaceVariant,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.style});

  final String label;
  final _RideStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTheme.caption(
            color: style.foreground,
            weight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RidesLoadingState extends StatelessWidget {
  const _RidesLoadingState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: l10n.petTaxiRidesLoading,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: List.generate(
                  3,
                  (index) => Container(
                    height: 176,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoRidesState extends StatelessWidget {
  const _NoRidesState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _CenteredState(
      icon: LucideIcons.navigation,
      title: l10n.petTaxiNoRidesTitle,
      message: l10n.petTaxiNoRidesDescription,
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: LucideIcons.listFilter,
      title: message,
      message: AppLocalizations.of(context)!.petTaxiTryAnotherFilter,
    );
  }
}

class _SignedOutState extends StatelessWidget {
  const _SignedOutState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _CenteredState(
      icon: LucideIcons.logIn,
      title: l10n.petTaxiSignInRequiredTitle,
      message: l10n.petTaxiSignInRequiredDescription,
    );
  }
}

class _RidesErrorState extends StatelessWidget {
  const _RidesErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _CenteredState(
      icon: LucideIcons.cloudOff,
      title: l10n.petTaxiRidesLoadErrorTitle,
      message: l10n.petTaxiRidesLoadErrorDescription,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(LucideIcons.refreshCw, size: 18),
        label: Text(l10n.retryButton),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 32, color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTheme.h3(
                  color: colors.onSurface,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTheme.body(color: colors.onSurfaceVariant),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _RideStatusStyle {
  const _RideStatusStyle({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}

_RideStatusStyle _statusStyle(BuildContext context, String status) {
  final brightness = Theme.of(context).brightness;
  final dark = brightness == Brightness.dark;
  Color foreground;
  switch (petTaxiRideFilterForStatus(status)) {
    case PetTaxiRideFilter.completed:
      foreground = dark ? const Color(0xFF69DB9B) : const Color(0xFF146C43);
    case PetTaxiRideFilter.cancelled:
      foreground = dark ? const Color(0xFFFF8A94) : const Color(0xFFB42335);
    case PetTaxiRideFilter.active:
      if (status == 'awaiting_user_payment' || status == 'payment_failed') {
        foreground = dark ? const Color(0xFFFFC66D) : const Color(0xFF9A5B00);
      } else {
        foreground = dark ? const Color(0xFF80BFFF) : const Color(0xFF155E9B);
      }
  }
  return _RideStatusStyle(
    foreground: foreground,
    background: foreground.withValues(alpha: dark ? 0.22 : 0.11),
  );
}

String _statusLabel(String status, AppLocalizations l10n) {
  switch (status) {
    case 'pending':
      return l10n.petTaxiStatusPending;
    case 'awaiting_user_payment':
      return l10n.petTaxiStatusAwaitingPayment;
    case 'confirmed_paid':
      return l10n.petTaxiStatusConfirmedPaid;
    case 'payment_failed':
      return l10n.petTaxiStatusPaymentFailed;
    case 'refund_pending':
      return l10n.petTaxiStatusRefundPending;
    case 'refunded':
      return l10n.petTaxiStatusRefunded;
    case 'driver_on_the_way':
      return l10n.petTaxiStatusDriverOnTheWay;
    case 'arrived':
      return l10n.petTaxiStatusArrived;
    case 'pet_picked_up':
      return l10n.petTaxiStatusPetPickedUp;
    case 'on_trip':
      return l10n.petTaxiStatusOnTrip;
    case 'completed':
      return l10n.petTaxiStatusCompleted;
    case 'cancelled_by_user':
      return l10n.petTaxiStatusCancelledByUser;
    case 'cancelled_by_business':
      return l10n.petTaxiStatusCancelledByProvider;
    default:
      return l10n.petTaxiStatusUnknown;
  }
}

String _paymentText(Map<String, dynamic> data, AppLocalizations l10n) {
  final paymentStatus = _normalizedText(
    data['paymentStatus'],
    fallback: 'unpaid',
  ).toLowerCase();
  switch (paymentStatus) {
    case 'paid':
      return l10n.petTaxiPaymentPaid;
    case 'pending':
      return l10n.petTaxiPaymentPending;
    case 'failed':
      return l10n.petTaxiPaymentFailed;
    case 'refunded':
      return l10n.petTaxiPaymentRefunded;
    default:
      return l10n.petTaxiPaymentUnpaid;
  }
}

String _priceText(Map<String, dynamic> data, AppLocalizations l10n) {
  final currency = _normalizedText(
    data['finalPriceCurrency'] ??
        data['paymentCurrency'] ??
        data['estimateCurrency'],
    fallback: 'TRY',
  );
  final finalPrice = data['finalPrice'] ?? data['paymentAmount'];
  if (finalPrice is num && finalPrice > 0) {
    return '${_compactNumber(finalPrice)} $currency';
  }
  final min = data['estimatedMinPrice'];
  final max = data['estimatedMaxPrice'];
  if (min is num && max is num) {
    return '${_compactNumber(min)}–${_compactNumber(max)} $currency';
  }
  return l10n.petTaxiPriceUnavailable;
}

String _compactNumber(num value) {
  final number = value.toDouble();
  return number == number.roundToDouble()
      ? number.toStringAsFixed(0)
      : number.toStringAsFixed(2);
}

String _normalizedText(dynamic value, {required String fallback}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _localizedDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} • '
      '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
