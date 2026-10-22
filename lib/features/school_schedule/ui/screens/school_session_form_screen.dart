// Thêm / sửa buổi học: chọn nhiều thứ, giờ vào/ra, nhãn ("Sáng", "Chiều"), gắn vùng "Trường".
// Server kiểm tra trùng giờ với buổi khác và báo lại.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/schedule_inputs.dart';
import '../../../geofences/data/geofences_api.dart';
import '../../data/school_sessions_api.dart';

class SchoolSessionFormScreen extends ConsumerStatefulWidget {
  const SchoolSessionFormScreen({super.key, required this.childId, this.session});
  final String childId;
  final SchoolSession? session;

  @override
  ConsumerState<SchoolSessionFormScreen> createState() => _SchoolSessionFormScreenState();
}

class _SchoolSessionFormScreenState extends ConsumerState<SchoolSessionFormScreen> {
  late final _label = TextEditingController(text: widget.session?.label ?? 'Sáng');
  late List<int> _days = widget.session?.daysOfWeek ?? [1, 2, 3, 4, 5];
  late String _start = widget.session?.startTime ?? '07:00';
  late String _end = widget.session?.endTime ?? '11:15';
  late String? _fenceId = widget.session?.geofenceId;
  late double _grace = (widget.session?.graceMinutes ?? 15).toDouble();
  late double _tolerance = (widget.session?.outsideToleranceMinutes ?? 5).toDouble();
  late bool _active = widget.session?.active ?? true;
  bool _saving = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    if (_days.isEmpty) errors['daysOfWeek'] = 'Chọn ít nhất 1 ngày trong tuần';
    if (AppDates.toMinutes(_start) >= AppDates.toMinutes(_end)) errors['endTime'] = 'Giờ vào học phải trước giờ tan học';
    if (_fenceId == null) errors['geofenceId'] = 'Hãy chọn vùng trường';
    if ((_label.text.trim()).length > 30) errors['label'] = 'Nhãn tối đa 30 ký tự';
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    final body = {
      'geofenceId': _fenceId,
      'daysOfWeek': _days,
      'startTime': _start,
      'endTime': _end,
      'label': _label.text.trim(),
      'graceMinutes': _grace.round(),
      'outsideToleranceMinutes': _tolerance.round(),
      'active': _active,
    };
    try {
      final api = ref.read(schoolSessionsApiProvider);
      if (widget.session == null) {
        await api.create({...body, 'childId': widget.childId});
      } else {
        await api.update(widget.session!.id, body);
      }
      ref.invalidate(schoolSessionsProvider(widget.childId));
      if (!mounted) return;
      showSuccess(context, 'Đã lưu buổi học');
      context.pop();
    } catch (e) {
      final err = ApiException.from(e);
      if (!mounted) return;
      setState(() => _errors = err.fieldErrors);
      showError(context, err);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fences = (ref.watch(geofencesProvider(widget.childId)).value ?? const <Geofence>[]).where((f) => f.type == 'school').toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.session == null ? 'Thêm buổi học' : 'Sửa buổi học')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppTextField(controller: _label, label: 'Nhãn (vd Sáng, Chiều)', icon: Icons.label_outline, serverError: _errors['label']),
          const SectionHeader('Học vào các ngày'),
          DaysPicker(value: _days, onChanged: (d) => setState(() => _days = d), errorText: _errors['daysOfWeek']),
          AppSpacing.gapMd,
          Row(children: [
            Expanded(child: TimeField(label: 'Giờ vào', value: _start, onChanged: (v) => setState(() => _start = v), errorText: _errors['startTime'])),
            AppSpacing.gapMd,
            Expanded(child: TimeField(label: 'Giờ tan', value: _end, onChanged: (v) => setState(() => _end = v), errorText: _errors['endTime'])),
          ]),
          AppSpacing.gapMd,
          DropdownButtonFormField<String>(
            initialValue: fences.any((f) => f.id == _fenceId) ? _fenceId : null,
            decoration: InputDecoration(labelText: 'Vùng trường', prefixIcon: const Icon(Icons.school_outlined), errorText: _errors['geofenceId']),
            items: [for (final f in fences) DropdownMenuItem(value: f.id, child: Text(f.name))],
            onChanged: (v) => setState(() => _fenceId = v),
          ),
          if (fences.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () => context.push('/parent/children/${widget.childId}/geofences/form'),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Chưa có vùng loại "Trường" — tạo ngay'),
              ),
            ),
          const SectionHeader('Giờ học an toàn'),
          Text('Cho phép đến trễ: ${_grace.round()} phút'),
          Slider(value: _grace, min: 0, max: 60, divisions: 12, onChanged: (v) => setState(() => _grace = v)),
          Text('Báo đỏ khi ở ngoài trường liên tục ≥ ${_tolerance.round()} phút'),
          Slider(value: _tolerance, min: 1, max: 30, divisions: 29, onChanged: (v) => setState(() => _tolerance = v)),
          SwitchListTile(title: const Text('Đang áp dụng'), value: _active, onChanged: (v) => setState(() => _active = v)),
          AppSpacing.gapLg,
          AppButton(label: 'Lưu', icon: Icons.save_outlined, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
