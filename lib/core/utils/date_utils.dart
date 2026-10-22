// Tiện ích ngày giờ: "cập nhật X phút trước", thứ trong tuần (1 = T2 … 7 = CN), "HH:mm" ↔ phút, khung qua nửa đêm.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppDates {
  AppDates._();

  static const dayShort = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const dayLong = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];

  static String ago(DateTime? time, {DateTime? now}) {
    if (time == null) return 'chưa có dữ liệu';
    final diff = (now ?? DateTime.now()).difference(time.toLocal());
    if (diff.inSeconds < 60) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  static String hm(DateTime? t) => t == null ? '--:--' : DateFormat('HH:mm').format(t.toLocal());
  static String dmy(DateTime? t) => t == null ? '' : DateFormat('dd/MM/yyyy').format(t.toLocal());
  static String dmyHm(DateTime? t) => t == null ? '' : DateFormat('HH:mm dd/MM/yyyy').format(t.toLocal());
  static String ymd(DateTime t) => DateFormat('yyyy-MM-dd').format(t);

  static int toMinutes(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static String fromTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay toTimeOfDay(String hhmm) {
    final m = toMinutes(hhmm);
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  static String days(List<int> days) {
    if (days.length == 7) return 'Hằng ngày';
    if (days.length == 5 && days.every((d) => d <= 5)) return 'T2 – T6';
    return days.map((d) => dayShort[d]).join(', ');
  }

  /// Lịch tuần (có thể qua nửa đêm) có đang hiệu lực lúc `now` (giờ máy, đã là giờ VN trên điện thoại) không.
  static bool isWithinWindow(List<int> days, String start, String end, [DateTime? now]) {
    final t = now ?? DateTime.now();
    final cur = t.hour * 60 + t.minute;
    final s = toMinutes(start);
    final e = toMinutes(end);
    final today = t.weekday; // 1 = Thứ 2 … 7 = CN, trùng quy ước của server
    final yesterday = today == 1 ? 7 : today - 1;
    if (s < e) return days.contains(today) && cur >= s && cur < e;
    if (cur >= s) return days.contains(today);
    if (cur < e) return days.contains(yesterday);
    return false;
  }
}
