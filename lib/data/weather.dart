import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Where the location behind a reading came from, best first.
enum WeatherSource {
  /// The phone's or browser's own location.
  device,

  /// Estimated from the IP address; on mobile data this is often the
  /// carrier's nearest city rather than where the student is.
  network,

  /// Nothing worked, so the Peradeniya/Kandy campus area was used.
  campus,
}

/// The current temperature and roughly where it was measured.
class WeatherNow {
  const WeatherNow(this.tempC, this.place, {required this.source, required this.at, this.code, this.isDay = true, this.locationBlocked = false});
  final double tempC;
  final String? place;
  final WeatherSource source;
  final DateTime at;

  /// WMO weather code from Open-Meteo, when known.
  final int? code;
  final bool isDay;

  /// True when the student turned location access off, so the reading is
  /// only an estimate until they allow it.
  final bool locationBlocked;

  bool get approximate => source != WeatherSource.device;

  /// Short sky description for the WMO [code].
  String? get condition => switch (code) {
        null => null,
        0 => isDay ? 'Clear sky' : 'Clear night',
        1 || 2 => 'Partly cloudy',
        3 => 'Overcast',
        45 || 48 => 'Foggy',
        51 || 53 || 55 || 56 || 57 => 'Drizzle',
        61 || 63 || 66 || 80 || 81 => 'Rain',
        65 || 67 || 82 => 'Heavy rain',
        95 || 96 || 99 => 'Thunderstorms',
        _ => null,
      };
}

/// Best-effort current temperature for hydration suggestions.
///
/// Uses the device location when the student allows it, otherwise an
/// IP-based estimate, and finally the Peradeniya/Kandy campus area. The
/// temperature comes from Open-Meteo and the place name from BigDataCloud's
/// client-side reverse geocoder; both are free and need no API key. Any
/// failure just means no weather card, never a blocked water tracker.
class Weather {
  Weather._();
  static WeatherNow? _cached;

  /// Peradeniya campus, used when the location lookups fail.
  static const _fallback = (7.2546, 80.5966, 'Kandy area');

  static Future<double?> currentTempC() async => (await current())?.tempC;

  /// The latest reading, cached for 30 minutes unless [force] is set.
  /// [askPermission] lets this call show the location permission prompt.
  static Future<WeatherNow?> current({bool force = false, bool askPermission = false}) async {
    final c = _cached;
    if (!force && c != null && DateTime.now().difference(c.at) < const Duration(minutes: 30)) return c;

    final (device, blocked) = await _deviceLocation(askPermission);
    final loc = device ?? await _networkLocation();
    final source = device != null ? WeatherSource.device : (loc != null ? WeatherSource.network : WeatherSource.campus);
    final (lat, lon, place) = loc ?? _fallback;
    try {
      final wx = await http
          .get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,is_day'))
          .timeout(const Duration(seconds: 8));
      if (wx.statusCode != 200) return _cached;
      final cur = (jsonDecode(wx.body) as Map<String, dynamic>)['current'] as Map?;
      final t = cur?['temperature_2m'] as num?;
      if (t == null) return _cached;
      return _cached = WeatherNow(
        t.toDouble(),
        place ?? (device != null ? await _placeName(lat, lon) : null),
        source: source,
        at: DateTime.now(),
        code: (cur?['weather_code'] as num?)?.toInt(),
        isDay: cur?['is_day'] != 0,
        locationBlocked: blocked,
      );
    } catch (_) {
      return _cached;
    }
  }

  /// The device position, plus whether location access is blocked.
  static Future<((double, double, String?)?, bool)> _deviceLocation(bool ask) async {
    try {
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) return (null, false);
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied && ask) p = await Geolocator.requestPermission();
      if (p == LocationPermission.deniedForever || (p == LocationPermission.denied && ask)) return (null, true);
      if (p == LocationPermission.denied || p == LocationPermission.unableToDetermine) return (null, false);
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 12)));
      } catch (_) {
        if (!kIsWeb) pos = await Geolocator.getLastKnownPosition();
      }
      return (pos == null ? null : (pos.latitude, pos.longitude, null), false);
    } catch (_) {
      return (null, false);
    }
  }

  static Future<(double, double, String?)?> _networkLocation() async {
    const sources = [
      ('https://ipapi.co/json/', 'latitude', 'longitude', 'city'),
      ('https://ipwho.is/', 'latitude', 'longitude', 'city'),
    ];
    for (final (url, latKey, lonKey, cityKey) in sources) {
      try {
        final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        if (r.statusCode != 200) continue;
        final g = jsonDecode(r.body) as Map<String, dynamic>;
        final lat = g[latKey] as num?, lon = g[lonKey] as num?;
        if (lat != null && lon != null) return (lat.toDouble(), lon.toDouble(), g[cityKey] as String?);
      } catch (_) {}
    }
    return null;
  }

  /// Town or city name for a coordinate, or null.
  static Future<String?> _placeName(double lat, double lon) async {
    try {
      final r = await http
          .get(Uri.parse('https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return null;
      final g = jsonDecode(r.body) as Map<String, dynamic>;
      for (final k in ['city', 'locality', 'principalSubdivision']) {
        final v = (g[k] as String?)?.trim();
        if (v != null && v.isNotEmpty) return v;
      }
    } catch (_) {}
    return null;
  }
}
