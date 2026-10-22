// Đổi mã trạng thái / loại của server thành chữ tiếng Việt hiển thị trên giao diện.
class Labels {
  Labels._();

  static String role(String r) => switch (r) {
        'admin' => 'Quản trị viên',
        'staff' => 'Nhân viên hỗ trợ',
        'parent' => 'Phụ huynh',
        _ => r,
      };

  static String userStatus(String s) => switch (s) {
        'pending' => 'Chờ xác minh',
        'active' => 'Hoạt động',
        'locked' => 'Đã khoá',
        'deleted' => 'Đã xoá',
        _ => s,
      };

  static String ticketStatus(String s) => switch (s) {
        'open' => 'Mới',
        'in_progress' => 'Đang xử lý',
        'resolved' => 'Đã giải quyết',
        'closed' => 'Đã đóng',
        _ => s,
      };

  static String ticketCategory(String c) => switch (c) {
        'account' => 'Tài khoản',
        'device' => 'Thiết bị',
        'bug' => 'Báo lỗi',
        _ => 'Khác',
      };

  static String geofenceType(String t) => switch (t) {
        'home' => 'Nhà',
        'school' => 'Trường',
        _ => 'Khác',
      };

  static String alertType(String t) => switch (t) {
        'left_school_during_class' => 'Rời trường trong giờ học',
        'not_arrived_school' => 'Chưa đến trường',
        'device_offline_school_hours' => 'Mất tín hiệu giờ học',
        'returned_to_school' => 'Quay lại trường',
        'school_dismissed' => 'Tan học',
        'geofence_enter' => 'Vào vùng',
        'geofence_exit' => 'Ra khỏi vùng',
        'sos' => 'SOS',
        'low_battery' => 'Pin yếu',
        'permission_revoked' => 'Quyền bị tắt',
        _ => t,
      };

  static const alertTypes = [
    'left_school_during_class',
    'not_arrived_school',
    'device_offline_school_hours',
    'returned_to_school',
    'geofence_enter',
    'geofence_exit',
    'sos',
    'low_battery',
    'permission_revoked',
  ];
}
