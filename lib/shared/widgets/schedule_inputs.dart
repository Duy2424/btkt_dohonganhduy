// Ô nhập dùng cho lịch: chọn nhiều ngày trong tuần (T2…CN) và chọn giờ HH:mm.
import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';

class DaysPicker extends StatelessWidget {
  const DaysPicker({super.key, required this.value, required this.onChanged, this.errorText});
  final List<int> value;
  final ValueChanged<List<int>> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(AppDates.dayShort[d]),
                selected: value.contains(d),
                showCheckmark: false,
                onSelected: (on) => onChanged(on ? ([...value, d]..sort()) : value.where((x) => x != d).toList()),
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ),
      ],
    );
  }
}

class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.label, required this.value, required this.onChanged, this.errorText});
  final String label;
  final String value; // HH:mm
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: AppDates.toTimeOfDay(value),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
        if (picked != null) onChanged(AppDates.fromTimeOfDay(picked));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.schedule), errorText: errorText, errorMaxLines: 3),
        child: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
