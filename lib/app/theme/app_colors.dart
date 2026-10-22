// Bảng màu của ConAn: tông xanh ngọc, đỏ / vàng / xanh dương cho cảnh báo.
// Màn hình không hardcode màu: luôn lấy từ đây hoặc Theme.of(context).colorScheme.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const seed = Color(0xFF0D9488); // teal 600
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF0284C7);
  static const success = Color(0xFF16A34A);
  static const offline = Color(0xFF94A3B8);

  /// Màu avatar để phụ huynh chọn cho từng con.
  static const avatarChoices = <Color>[
    Color(0xFF14B8A6),
    Color(0xFF0EA5E9),
    Color(0xFF6366F1),
    Color(0xFFA855F7),
    Color(0xFFEC4899),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF22C55E),
  ];

  /// "#14B8A6" → Color
  static Color fromHex(String? hex, {Color fallback = seed}) {
    if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return fallback;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  static String toHex(Color c) {
    final argb = c.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Màu theo mức cảnh báo của server: info / warning / danger.
  static Color forLevel(String level) => switch (level) {
        'danger' => danger,
        'warning' => warning,
        _ => info,
      };
}
