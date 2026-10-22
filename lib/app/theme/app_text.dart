// Font Be Vietnam Pro (đóng gói trong assets/fonts), hỗ trợ đầy đủ dấu tiếng Việt.
import 'package:flutter/material.dart';

class AppText {
  AppText._();

  static const fontFamily = 'BeVietnamPro';

  static TextTheme textTheme(TextTheme base) => base
      .apply(fontFamily: fontFamily)
      .copyWith(
        headlineSmall: base.headlineSmall?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        titleLarge: base.titleLarge?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        titleMedium: base.titleMedium?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        labelLarge: base.labelLarge?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      );
}
