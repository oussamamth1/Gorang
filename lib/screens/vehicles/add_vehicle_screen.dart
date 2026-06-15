import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/vehicle.dart';
import '../../providers/auth_providers.dart';
import '../../providers/service_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/press_scale.dart';
import '../../widgets/vehicle_card.dart';

/// Create a new listing, or edit an existing one when [vehicle] is provided.
class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key, this.vehicle});

  final Vehicle? vehicle;

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _brand = TextEditingController(text: widget.vehicle?.brand);
  late final _model = TextEditingController(text: widget.vehicle?.model);
  late final _year =
      TextEditingController(text: widget.vehicle?.year.toString());
  late final _street = TextEditingController(text: widget.vehicle?.street);
  late final _pricePerDay =
      TextEditingController(text: widget.vehicle?.pricePerDay.toString());
  late final _includedKm = TextEditingController(
      text: widget.vehicle?.includedKmPerDay.toString() ?? '100');
  late final _extraKmPrice =
      TextEditingController(text: widget.vehicle?.extraKmPrice.toString());
  late final _description = TextEditingController(text: widget.vehicle?.description);
  late VehicleType _type = widget.vehicle?.type ?? VehicleType.car;
  late TunisiaCity? _city = widget.vehicle?.city;
  final List<XFile> _photos = [];
  bool _saving = false;

  bool get _isEditing => widget.vehicle != null;

  @override
  void dispose() {
    for (final c in [_brand, _model, _year, _street, _pricePerDay, _includedKm, _extraKmPrice, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  // Small + compressed: photos are stored as base64 inside the Firestore
  // vehicle document (1 MiB cap), so at most 3 photos.
  Future<void> _pickPhotos() async {
    final picked =
        await ImagePicker().pickMultiImage(maxWidth: 900, imageQuality: 50, limit: 3);
    if (picked.isNotEmpty) setState(() => _photos..clear()..addAll(picked.take(3)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_city == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a city')));
      return;
    }
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final vehicle = Vehicle(
        id: widget.vehicle?.id ?? '',
        ownerId: user.uid,
        type: _type,
        brand: _brand.text.trim(),
        model: _model.text.trim(),
        year: int.parse(_year.text.trim()),
        city: _city!,
        street: _street.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        photoUrls: widget.vehicle?.photoUrls ?? const [],
        pricePerDay: double.parse(_pricePerDay.text.trim()),
        includedKmPerDay: int.parse(_includedKm.text.trim()),
        extraKmPrice: double.parse(_extraKmPrice.text.trim()),
        isActive: widget.vehicle?.isActive ?? true,
      );
      final service = ref.read(vehicleServiceProvider);
      if (_isEditing) {
        await service.updateVehicle(vehicle, newPhotos: _photos);
      } else {
        await service.addVehicle(vehicle, _photos);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing ? 'Listing updated!' : 'Vehicle listed!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save vehicle: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _requiredNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return double.tryParse(v.trim()) == null ? 'Enter a number' : null;
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit listing' : 'List a vehicle')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Vehicle type', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final t in VehicleType.values) ...[
                      Expanded(
                        child: PressScale(
                          onTap: () => setState(() => _type = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient:
                                  _type == t ? AppColors.primaryGradient : null,
                              color: _type == t ? null : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: _type == t
                                  ? null
                                  : Border.all(
                                      color: AppColors.border, width: 1.4),
                            ),
                            child: Column(
                              children: [
                                Icon(vehicleTypeIcon(t),
                                    size: 22,
                                    color: _type == t
                                        ? Colors.white
                                        : AppColors.textSecondary),
                                const SizedBox(height: 4),
                                Text(
                                  t.label,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _type == t
                                        ? Colors.white
                                        : AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (t != VehicleType.values.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
                _sectionTitle('Details'),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brand,
                      decoration: const InputDecoration(labelText: 'Brand'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _model,
                      decoration: const InputDecoration(labelText: 'Model'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final y = int.tryParse(v ?? '');
                        return (y == null || y < 1980 || y > DateTime.now().year + 1)
                            ? 'Invalid year'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<TunisiaCity>(
                      value: _city,
                      decoration: const InputDecoration(
                        labelText: 'Governorate',
                        prefixIcon: Icon(Icons.location_city_rounded),
                      ),
                      isExpanded: true,
                      items: TunisiaCity.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _city = v),
                      validator: (_) => _city == null ? 'Required' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _street,
                  decoration: const InputDecoration(
                    labelText: 'Street address',
                    prefixIcon: Icon(Icons.signpost_rounded),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Condition, features, rules (e.g. no smoking)…',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
                _sectionTitle('Pricing'),
                TextFormField(
                  controller: _pricePerDay,
                  decoration: const InputDecoration(
                      labelText: 'Price per day', suffixText: 'TND'),
                  keyboardType: TextInputType.number,
                  validator: _requiredNumber,
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _includedKm,
                      decoration: const InputDecoration(
                          labelText: 'Included km / day', suffixText: 'km'),
                      keyboardType: TextInputType.number,
                      validator: _requiredNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _extraKmPrice,
                      decoration: const InputDecoration(
                          labelText: 'Extra km price', suffixText: 'TND/km'),
                      keyboardType: TextInputType.number,
                      validator: _requiredNumber,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Renters pay the daily price up front. Kilometres beyond the daily '
                  'allowance are billed at the extra-km price when the vehicle returns.',
                  style: theme.textTheme.bodySmall,
                ),
                _sectionTitle('Photos'),
                PressScale(
                  onTap: _pickPhotos,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _photos.isEmpty
                              ? AppColors.border
                              : AppColors.success,
                          width: 1.4),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (_photos.isEmpty
                                    ? AppColors.primary
                                    : AppColors.success)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            _photos.isEmpty
                                ? Icons.add_photo_alternate_rounded
                                : Icons.check_rounded,
                            color: _photos.isEmpty
                                ? AppColors.primary
                                : AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _photos.isEmpty
                                    ? (_isEditing ? 'Replace photos' : 'Add photos')
                                    : '${_photos.length} photo${_photos.length > 1 ? 's' : ''} selected',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                  _isEditing && _photos.isEmpty
                                      ? 'Current photos are kept unless you pick new ones'
                                      : 'Up to 3 photos — the first one is the cover',
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Save changes' : 'Publish listing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
