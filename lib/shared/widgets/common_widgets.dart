// Widget nhỏ dùng nhiều nơi: logo ConAn, avatar tròn của con, chip trạng thái màu, tiêu đề mục, ô tìm kiếm.
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(Icons.shield_moon_rounded, color: scheme.onPrimary, size: size * 0.55),
        ),
        const SizedBox(height: 10),
        Text('ConAn', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: scheme.primary)),
        Text('Con An toàn', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key, required this.name, required this.color, this.radius = 24, this.online});
  final String name;
  final String? color;
  final double radius;
  final bool? online;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.fromHex(color);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: c,
          child: Text(
            name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.8),
          ),
        ),
        if (online != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: online! ? AppColors.success : AppColors.offline,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onChanged, this.hint = 'Tìm kiếm...'});
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: hint, isDense: true),
    );
  }
}

/// Banner thông tin có màu (minh bạch, cảnh báo…).
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text, this.icon = Icons.info_outline, this.color});
  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppSpacing.radius)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
