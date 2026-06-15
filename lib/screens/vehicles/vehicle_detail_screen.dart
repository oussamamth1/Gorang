import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/app_user.dart';
import '../../core/models/vehicle.dart';
import '../../core/pricing.dart';
import '../../core/models/booking.dart';
import '../../providers/auth_providers.dart';
import '../../providers/booking_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/vehicle_providers.dart';
import '../../router/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/press_scale.dart';
import '../../widgets/vehicle_card.dart';

class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  DateTimeRange? _range;
  bool _submitting = false;
  int _photoIndex = 0;

  Future<void> _pickDates() async {
    final activeBookings =
        ref.read(vehicleBookedRangesProvider(widget.vehicleId)).value ??
            const <Booking>[];

    final blocked = <DateTime>{};
    for (final b in activeBookings) {
      var d = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
      final end = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
      while (!d.isAfter(end)) {
        blocked.add(d);
        d = d.add(const Duration(days: 1));
      }
    }

    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _range,
      selectableDayPredicate: blocked.isEmpty
          ? null
          : (day, rangeStart, rangeEnd) {
              final d = DateTime(day.year, day.month, day.day);
              return !blocked.contains(d);
            },
    );
    if (range != null) setState(() => _range = range);
  }

  Future<void> _requestBooking(Vehicle vehicle) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    if (!user.hasSubmittedKyc) {
      final goToKyc = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Identity check required'),
          content: const Text(
              'Before renting you need to add your ID card and driving licence.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Later')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('Add documents')),
          ],
        ),
      );
      if (goToKyc == true && mounted) context.push(Routes.kyc);
      return;
    }

    // Show rental agreement — user must accept before booking is created.
    final accepted = await _showRentalAgreement(vehicle);
    if (!accepted || !mounted) return;

    setState(() => _submitting = true);
    try {
      final owner = ref.read(userByIdProvider(vehicle.ownerId)).value;
      final id = await ref.read(bookingServiceProvider).requestBooking(
            vehicle: vehicle,
            renter: user,
            owner: owner,
            startDate: _range!.start,
            endDate: _range!.end,
            termsAcceptedAt: DateTime.now(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking request sent to the owner')));
        context.push(Routes.bookingDetailPath(id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not create booking: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Shows the rental agreement bottom sheet.
  /// Returns true only if the user explicitly accepts.
  Future<bool> _showRentalAgreement(Vehicle vehicle) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RentalAgreementSheet(vehicle: vehicle),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAsync = ref.watch(vehicleByIdProvider(widget.vehicleId));
    final user = ref.watch(currentUserProvider).value;

    return vehicleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.cloud_off_rounded, title: 'Could not load this vehicle'),
      ),
      data: (vehicle) {
        if (vehicle == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
                icon: Icons.search_off_rounded, title: 'Vehicle not found'),
          );
        }
        final theme = Theme.of(context);
        final isOwner = user?.uid == vehicle.ownerId;
        final owner = ref.watch(userByIdProvider(vehicle.ownerId)).value;
        final days =
            _range != null ? Pricing.rentalDays(_range!.start, _range!.end) : null;
        final basePrice = days != null
            ? Pricing.basePrice(days: days, pricePerDay: vehicle.pricePerDay)
            : null;
        final dates = DateFormat('d MMM');

        return Scaffold(
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _photoHeader(vehicle),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vehicle.title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _specPill(vehicleTypeIcon(vehicle.type),
                                vehicle.type.label),
                            _specPill(Icons.place_rounded, vehicle.city.label),
                            if (vehicle.street.isNotEmpty)
                              _specPill(Icons.signpost_rounded, vehicle.street),
                            _specPill(
                                Icons.calendar_today_rounded, '${vehicle.year}'),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (vehicle.description != null &&
                            vehicle.description!.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Text(vehicle.description!,
                                style: theme.textTheme.bodyMedium),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _pricingCard(vehicle, theme),
                        if (!isOwner &&
                            owner != null &&
                            owner.showPhone &&
                            owner.phone.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _contactCard(owner, theme),
                        ],
                        if (!isOwner) ...[
                          const SizedBox(height: 14),
                          PressScale(
                            onTap: _pickDates,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: _range == null
                                        ? AppColors.border
                                        : AppColors.primary,
                                    width: 1.4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded,
                                      color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _range == null
                                          ? 'Choose rental dates'
                                          : '${dates.format(_range!.start)} → ${dates.format(_range!.end)} · $days day${days! > 1 ? 's' : ''}',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded,
                                      color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                          if (days != null && basePrice != null) ...[
                            const SizedBox(height: 14),
                            _summaryCard(vehicle, days, basePrice, theme),
                          ],
                        ] else ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.garage_rounded,
                                    color: AppColors.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text('This is your listing.',
                                      style: theme.textTheme.bodyMedium),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PressScale(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 22),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isOwner
              ? null
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4C1D95).withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(days == null ? 'Daily price' : 'Due now',
                                  style: theme.textTheme.bodySmall),
                              Text(
                                days == null
                                    ? '${formatTnd(vehicle.pricePerDay)}/day'
                                    : formatTnd(basePrice!),
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton(
                              onPressed: (_range == null || _submitting)
                                  ? null
                                  : () => _requestBooking(vehicle),
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Text(_range == null
                                      ? 'Pick dates first'
                                      : 'Request booking'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _contactCard(AppUser owner, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              owner.fullName.isNotEmpty ? owner.fullName[0].toUpperCase() : '?',
              style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owner.fullName, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text('+216 ${owner.phone}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: '+216${owner.phone}')),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Call'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoHeader(Vehicle vehicle) {
    final photos = vehicle.photoUrls;
    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF1EBFD), Color(0xFFE2D8F8)],
                ),
              ),
              child: Icon(vehicleTypeIcon(vehicle.type),
                  size: 90, color: AppColors.primary.withValues(alpha: 0.45)),
            )
          else
            PageView(
              onPageChanged: (i) => setState(() => _photoIndex = i),
              children: [for (final url in photos) AppImage(url)],
            ),
          if (photos.length > 1)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < photos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _photoIndex ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _photoIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _specPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _pricingCard(Vehicle vehicle, ThemeData theme) {
    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(value, style: theme.textTheme.titleSmall),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatTnd(vehicle.pricePerDay),
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: AppColors.primary)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/day', style: theme.textTheme.bodySmall),
              ),
            ],
          ),
          const Divider(height: 24),
          row(Icons.route_rounded, 'Included distance',
              '${vehicle.includedKmPerDay} km/day'),
          row(Icons.add_road_rounded, 'Extra kilometre',
              formatTnd(vehicle.extraKmPrice)),
        ],
      ),
    );
  }

  Widget _summaryCard(
      Vehicle vehicle, int days, double basePrice, ThemeData theme) {
    Widget row(String label, String value, {bool bold = false}) {
      final style = (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
          ?.copyWith(color: Colors.white);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label, style: style), Text(value, style: style)],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          row('$days day${days > 1 ? 's' : ''} × ${formatTnd(vehicle.pricePerDay)}',
              formatTnd(basePrice)),
          row('Included distance', '${days * vehicle.includedKmPerDay} km'),
          Divider(height: 20, color: Colors.white.withValues(alpha: 0.3)),
          row('Due now', formatTnd(basePrice), bold: true),
          const SizedBox(height: 8),
          Text(
            'Extra kilometres are billed at return — ${formatTnd(vehicle.extraKmPrice)}/km beyond the allowance.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rental Agreement bottom sheet
// ---------------------------------------------------------------------------

class _RentalAgreementSheet extends StatefulWidget {
  const _RentalAgreementSheet({required this.vehicle});
  final Vehicle vehicle;

  @override
  State<_RentalAgreementSheet> createState() => _RentalAgreementSheetState();
}

class _RentalAgreementSheetState extends State<_RentalAgreementSheet> {
  bool _accepted = false;

  static const _clauses = [
    (
      icon: Icons.assignment_ind_rounded,
      title: 'Identity & licence',
      body:
          'The renter confirms they hold a valid Tunisian or international driving licence appropriate for this vehicle and accepts full legal responsibility for its operation during the rental period.',
    ),
    (
      icon: Icons.car_crash_rounded,
      title: 'Damage liability',
      body:
          'Any damage, loss, or theft of the vehicle occurring during the rental period is the renter\'s sole financial responsibility. The renter agrees to cover all repair or replacement costs beyond normal wear.',
    ),
    (
      icon: Icons.speed_rounded,
      title: 'Extra kilometres',
      body:
          'Kilometres driven beyond the daily allowance are billed at the rate shown on this listing and payable at vehicle return. The odometer will be recorded at pickup and return.',
    ),
    (
      icon: Icons.access_time_rounded,
      title: 'Return on time',
      body:
          'The vehicle must be returned on the agreed end date. Late returns will be charged at the daily rate per additional day and may affect future booking eligibility.',
    ),
    (
      icon: Icons.local_gas_station_rounded,
      title: 'Fuel & condition',
      body:
          'The vehicle must be returned with the same fuel level and in the same condition as at pickup. The owner may charge for refuelling or cleaning if this condition is not met.',
    ),
    (
      icon: Icons.gavel_rounded,
      title: 'Owner\'s rights',
      body:
          'The owner reserves the right to reject any booking request without obligation. Accepted bookings are binding contracts between renter and owner. RentGo acts as a platform only and is not a party to this agreement.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.description_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rental Agreement',
                            style: theme.textTheme.titleLarge),
                        Text(widget.vehicle.title,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                itemCount: _clauses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final c = _clauses[i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(c.icon,
                              size: 20, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title,
                                  style: theme.textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text(c.body,
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _accepted = !_accepted),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _accepted
                                    ? AppColors.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _accepted
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: _accepted
                                  ? const Icon(Icons.check_rounded,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'I have read and I accept all the terms of this rental agreement.',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _accepted
                            ? () => Navigator.pop(context, true)
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        child: const Text('Confirm & Request Booking'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
