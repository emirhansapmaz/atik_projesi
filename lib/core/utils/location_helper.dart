import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationHelper {
  // Varsayılan koordinatlar (İstanbul)
  static const double defaultLatitude = 41.0082;
  static const double defaultLongitude = 28.9784;
  static const String defaultAddress = 'İstanbul, Türkiye';

  /// Konum izinlerini kontrol eder ve gerekirse izin ister
  static Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationHelper] Konum servisi kapalı.');
        return false;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationHelper] Konum izni reddedildi.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationHelper] Konum izni kalıcı olarak reddedildi.');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[LocationHelper] İzin kontrolü sırasında hata: $e');
      return false;
    }
  }

  /// Mevcut GPS konumunu ve adres bilgisini getirir (İzin yoksa varsayılan döndürür)
  static Future<LocationResult> getCurrentLocation() async {
    final hasPermission = await handleLocationPermission();

    if (!hasPermission) {
      return const LocationResult(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        address: defaultAddress,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );
    } catch (e) {
      debugPrint('[LocationHelper] Konum alınamadı, varsayılan kullanılıyor: $e');
      return const LocationResult(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        address: defaultAddress,
      );
    }
  }

  /// Koordinatlardan okunabilir "İlçe, İl" biçiminde adres metni türetir
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final district = _firstNonEmpty([
          place.subAdministrativeArea,
          place.locality,
          place.subLocality,
        ]);
        final city = _firstNonEmpty([
          place.administrativeArea,
          place.country,
        ]);

        if (district != null && city != null) {
          return district == city ? city : '$district, $city';
        }
        if (district != null) return district;
        if (city != null) return city;
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          return place.thoroughfare!;
        }
      }
    } catch (e) {
      debugPrint('[LocationHelper] Adres çözümlenemedi: $e');
    }

    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  /// Metinsel adresten enlem/boylam çözümler (Önce yerel yer imi eşleştirme + cihaz geocoder)
  static Future<({double latitude, double longitude})?> getCoordinatesFromAddress(
    String address,
  ) async {
    final normalized = _normalizeTurkish(address);
    if (normalized.isEmpty) return null;

    if (!kIsWeb) {
      try {
        final locations = await Geocoding().locationFromAddress(address);
        if (locations.isNotEmpty) {
          return (
            latitude: locations.first.latitude,
            longitude: locations.first.longitude,
          );
        }
      } catch (e) {
        debugPrint('[LocationHelper] Adresten koordinat çözümlenemedi: $e');
      }
    }

    // Web veya çevrimdışı modda bilinen ilçe/semt koordinatları (en spesifik eşleşme önce)
    for (final entry in _knownTurkishLocations) {
      if (normalized.contains(entry.$1)) {
        return (latitude: entry.$2, longitude: entry.$3);
      }
    }

    return null;
  }

  static const List<(String, double, double)> _knownTurkishLocations = [
    ('sultanahmet', 41.0063, 28.9757),
    ('eminonu', 41.0181, 28.9728),
    ('karakoy', 41.0217, 28.9765),
    ('taksim', 41.0369, 28.9850),
    ('galata', 41.0256, 28.9741),
    ('kadikoy', 40.9903, 29.0290),
    ('moda', 40.9838, 29.0265),
    ('besiktas', 41.0422, 29.0067),
    ('uskudar', 41.0234, 29.0151),
    ('sisli', 41.0605, 28.9872),
    ('fatih', 41.0186, 28.9489),
    ('beyoglu', 41.0370, 28.9769),
    ('bakirkoy', 40.9808, 28.8726),
    ('maltepe', 40.9357, 29.1551),
    ('atasehir', 40.9833, 29.1167),
    ('sariyer', 41.1669, 29.0572),
    ('ankara', 39.9334, 32.8597),
    ('izmir', 38.4237, 27.1428),
    ('bursa', 40.1885, 29.0610),
    ('antalya', 36.8969, 30.7133),
    ('istanbul', 41.0082, 28.9784),
  ];

  static String _normalizeTurkish(String input) {
    return input
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }

  static String? _firstNonEmpty(List<String?> candidates) {
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}

