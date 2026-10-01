/// Web build of [DeviceUsage]: browsers have no OS-level screen-time API to
/// read, so this always reports "not supported" rather than attempting it.
class DeviceUsage {
  DeviceUsage._();

  static bool get supported => false;

  static Future<int?> readTodayMinutes() async => null;
}
