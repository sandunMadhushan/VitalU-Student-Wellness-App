import 'dart:convert';

import 'package:http/http.dart' as http;

/// Best-effort current temperature for hydration suggestions.
///
/// Resolves the student's approximate location from their IP address (no
/// location permission needed) via ipapi.co, then reads the current
/// temperature for that spot from Open-Meteo. Both services are free and
/// require no API key. Any failure (offline, rate limited, blocked) just
/// means no heat-based suggestion is shown — never blocks the water tracker.
class Weather {
  Weather._();
  static double? _cachedTempC;
  static DateTime? _cachedAt;

  static Future<double?> currentTempC() async {
    if (_cachedTempC != null && _cachedAt != null && DateTime.now().difference(_cachedAt!) < const Duration(hours: 1)) {
      return _cachedTempC;
    }
    try {
      final geo = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 6));
      if (geo.statusCode != 200) return null;
      final g = jsonDecode(geo.body) as Map<String, dynamic>;
      final lat = g['latitude'] as num?;
      final lon = g['longitude'] as num?;
      if (lat == null || lon == null) return null;
      final wx = await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m')).timeout(const Duration(seconds: 6));
      if (wx.statusCode != 200) return null;
      final w = jsonDecode(wx.body) as Map<String, dynamic>;
      final t = (w['current'] as Map?)?['temperature_2m'] as num?;
      if (t == null) return null;
      _cachedTempC = t.toDouble();
      _cachedAt = DateTime.now();
      return _cachedTempC;
    } catch (_) {
      return null;
    }
  }
}
