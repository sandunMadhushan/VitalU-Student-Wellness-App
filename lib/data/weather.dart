import 'dart:convert';

import 'package:http/http.dart' as http;

/// The current temperature and roughly where it was measured.
class WeatherNow {
  const WeatherNow(this.tempC, this.place, {this.approximate = false});
  final double tempC;
  final String? place;

  /// True when the student's location could not be found and the campus
  /// area (Kandy) was used instead.
  final bool approximate;
}

/// Best-effort current temperature for hydration suggestions.
///
/// Resolves the student's approximate location from their IP address (no
/// location permission needed), trying two free services, and falls back to
/// the Peradeniya/Kandy campus area. The temperature itself comes from
/// Open-Meteo. All services are free and need no API key. Any failure just
/// means no weather card, never a blocked water tracker.
class Weather {
  Weather._();
  static WeatherNow? _cached;
  static DateTime? _cachedAt;

  /// Peradeniya campus, used when the location lookups fail.
  static const _fallback = (7.2546, 80.5966, 'Kandy area');

  static Future<double?> currentTempC() async => (await current())?.tempC;

  static Future<WeatherNow?> current({bool force = false}) async {
    if (!force && _cached != null && _cachedAt != null && DateTime.now().difference(_cachedAt!) < const Duration(minutes: 30)) {
      return _cached;
    }
    final loc = await _locate();
    final (lat, lon, place) = loc ?? _fallback;
    try {
      final wx = await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m')).timeout(const Duration(seconds: 8));
      if (wx.statusCode != 200) return _cached;
      final w = jsonDecode(wx.body) as Map<String, dynamic>;
      final t = (w['current'] as Map?)?['temperature_2m'] as num?;
      if (t == null) return _cached;
      _cached = WeatherNow(t.toDouble(), place, approximate: loc == null);
      _cachedAt = DateTime.now();
      return _cached;
    } catch (_) {
      return _cached;
    }
  }

  static Future<(double, double, String?)?> _locate() async {
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
}
