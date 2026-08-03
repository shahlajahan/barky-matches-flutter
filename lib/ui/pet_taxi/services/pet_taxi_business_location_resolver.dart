import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:barky_matches_fixed/utils/business_sector.dart';

class PetTaxiResolvedBusinessLocation {
  final Map<String, dynamic> location;
  final bool shouldBackfillCurrentLocation;
  final String sourceLabel;
  final String? migrationReason;

  const PetTaxiResolvedBusinessLocation({
    required this.location,
    required this.shouldBackfillCurrentLocation,
    required this.sourceLabel,
    this.migrationReason,
  });

  bool get hasCoordinates =>
      (location['lat'] as num?) != null && (location['lng'] as num?) != null;
}

class PetTaxiBusinessLocationResolver {
  PetTaxiBusinessLocationResolver._();

  static final Set<String> _pendingMigrationDocIds = <String>{};

  static PetTaxiResolvedBusinessLocation resolve(
    Map<String, dynamic> businessData,
  ) {
    if (!BusinessSector.hasCanonicalSector(
      businessData,
      BusinessSector.petTaxi,
    )) {
      return const PetTaxiResolvedBusinessLocation(
        location: <String, dynamic>{},
        shouldBackfillCurrentLocation: false,
        sourceLabel: 'not_pet_taxi',
      );
    }

    final sectorData = _map(businessData['publicSectorData']);
    final taxi = _map(
      sectorData['pet_taxi'] ?? sectorData['petTaxi'] ?? sectorData['taxi'],
    );
    final contact = _map(businessData['contact']);
    final currentLocation = _map(taxi['currentLocation']);
    final contactLocation = _map(contact['location']);

    final currentHasCoordinates = _hasCoordinates(currentLocation);
    final contactHasCoordinates = _hasCoordinates(contactLocation);
    final currentLocationSource = currentLocation['source']?.toString().trim();
    final hasRuntimeTimestamp = currentLocation['updatedAt'] != null;

    final currentLooksRuntime =
        currentHasCoordinates &&
        (currentLocationSource == 'gps_runtime' || hasRuntimeTimestamp);

    final currentLooksSeededAddress =
        currentHasCoordinates &&
        (currentLocationSource == 'registered_address_seed' ||
            currentLocationSource == 'migrated_from_contact_location');

    if (currentLooksRuntime || currentLooksSeededAddress) {
      return PetTaxiResolvedBusinessLocation(
        location: currentLocation,
        shouldBackfillCurrentLocation: false,
        sourceLabel: 'currentLocation',
      );
    }

    if (contactHasCoordinates) {
      return PetTaxiResolvedBusinessLocation(
        location: contactLocation,
        shouldBackfillCurrentLocation: true,
        sourceLabel: currentHasCoordinates
            ? 'contact.location (repairing currentLocation)'
            : 'contact.location',
        migrationReason: currentHasCoordinates
            ? 'legacy_current_location_without_runtime_timestamp'
            : 'missing_current_location',
      );
    }

    if (currentHasCoordinates) {
      return PetTaxiResolvedBusinessLocation(
        location: currentLocation,
        shouldBackfillCurrentLocation: false,
        sourceLabel: 'currentLocation (legacy fallback)',
      );
    }

    return const PetTaxiResolvedBusinessLocation(
      location: <String, dynamic>{},
      shouldBackfillCurrentLocation: false,
      sourceLabel: 'missing',
    );
  }

  static void scheduleMigrationIfNeeded({
    required String businessId,
    required Map<String, dynamic> businessData,
  }) {
    final resolved = resolve(businessData);
    if (!resolved.shouldBackfillCurrentLocation || !resolved.hasCoordinates) {
      return;
    }

    if (_pendingMigrationDocIds.contains(businessId)) {
      return;
    }

    _pendingMigrationDocIds.add(businessId);
    unawaited(
      _requestBackendMigration(
        businessId: businessId,
        migrationReason: resolved.migrationReason,
      ),
    );
  }

  static Future<void> _requestBackendMigration({
    required String businessId,
    required String? migrationReason,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('repairPetTaxiBusinessLocation');

      await callable.call({
        'businessId': businessId,
        'reason': migrationReason,
      });
    } catch (_) {
      // Best-effort migration. The UI already uses the resolved fallback
      // location in-memory, so a failed repair request should not break maps.
    } finally {
      _pendingMigrationDocIds.remove(businessId);
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  static bool _hasCoordinates(Map<String, dynamic> value) {
    final lat = (value['lat'] as num?)?.toDouble();
    final lng = (value['lng'] as num?)?.toDouble();
    return lat != null && lng != null;
  }
}
