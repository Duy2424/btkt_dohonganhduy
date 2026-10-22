// Model hồ sơ con + vị trí cuối + tóm tắt thiết bị + "đang ở đâu" (đọc từ /api/children).
DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
double? toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

class GeoPoint {
  const GeoPoint({required this.lat, required this.lng, this.accuracy, this.battery, this.at});
  final double lat;
  final double lng;
  final double? accuracy;
  final int? battery;
  final DateTime? at;

  static GeoPoint? fromJson(dynamic j) {
    if (j is! Map || j['lat'] == null) return null;
    return GeoPoint(
      lat: toDouble(j['lat'])!,
      lng: toDouble(j['lng'])!,
      accuracy: toDouble(j['accuracy']),
      battery: (j['battery'] as num?)?.toInt(),
      at: parseDate(j['at'] ?? j['recordedAt']),
    );
  }
}

class DeviceSummary {
  const DeviceSummary({required this.id, required this.name, this.model = '', this.batteryLevel, this.lastSeenAt, this.online = false});
  final String id;
  final String name;
  final String model;
  final int? batteryLevel;
  final DateTime? lastSeenAt;
  final bool online;

  static DeviceSummary? fromJson(dynamic j) {
    if (j is! Map || j['id'] == null) return null;
    return DeviceSummary(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      model: (j['model'] ?? '') as String,
      batteryLevel: (j['batteryLevel'] as num?)?.toInt(),
      lastSeenAt: parseDate(j['lastSeenAt']),
      online: (j['online'] ?? false) as bool,
    );
  }
}

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    this.birthYear,
    this.schoolName = '',
    this.avatarColor = '#14B8A6',
    this.lastLocation,
    this.device,
    this.placeType = 'unknown',
    this.placeName = 'Chưa có vị trí',
    this.latestAlertTitle,
    this.latestAlertLevel,
    this.latestAlertAt,
    this.schoolOffDates = const [],
  });

  final String id;
  final String name;
  final int? birthYear;
  final String schoolName;
  final String avatarColor;
  final GeoPoint? lastLocation;
  final DeviceSummary? device;
  final String placeType; // home | school | other | outside | unknown
  final String placeName;
  final String? latestAlertTitle;
  final String? latestAlertLevel;
  final DateTime? latestAlertAt;
  final List<String> schoolOffDates;

  factory ChildProfile.fromJson(Map<String, dynamic> j) {
    final place = j['place'] as Map? ?? const {};
    final alert = j['latestAlert'] as Map?;
    return ChildProfile(
      id: j['id'] as String,
      name: (j['name'] ?? '') as String,
      birthYear: (j['birthYear'] as num?)?.toInt(),
      schoolName: (j['schoolName'] ?? '') as String,
      avatarColor: (j['avatarColor'] ?? '#14B8A6') as String,
      lastLocation: GeoPoint.fromJson(j['lastLocation']),
      device: DeviceSummary.fromJson(j['device']),
      placeType: (place['type'] ?? 'unknown') as String,
      placeName: (place['name'] ?? 'Chưa có vị trí') as String,
      latestAlertTitle: alert?['title'] as String?,
      latestAlertLevel: alert?['level'] as String?,
      latestAlertAt: parseDate(alert?['createdAt']),
      schoolOffDates: ((j['schoolOffDates'] as List?) ?? const []).cast<String>(),
    );
  }

  /// Cập nhật vị trí + pin từ socket "location:new" mà không cần tải lại cả danh sách.
  ChildProfile withLive(GeoPoint? loc, DeviceSummary? dev) => ChildProfile(
        id: id,
        name: name,
        birthYear: birthYear,
        schoolName: schoolName,
        avatarColor: avatarColor,
        lastLocation: loc ?? lastLocation,
        device: dev ?? device,
        placeType: placeType,
        placeName: placeName,
        latestAlertTitle: latestAlertTitle,
        latestAlertLevel: latestAlertLevel,
        latestAlertAt: latestAlertAt,
        schoolOffDates: schoolOffDates,
      );
}
