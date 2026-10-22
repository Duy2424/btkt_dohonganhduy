// Thêm / sửa lịch khoá máy: tên, ngày trong tuần, giờ bắt đầu–kết thúc (cho phép qua nửa đêm, vd 21:30–06:30),
// app được phép (lấy từ máy con gửi lên, hoặc nhập tên gói thủ công). Gọi điện, tin nhắn, báo thức luôn được phép.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/schedule_inputs.dart';
import '../../data/lock_schedules_api.dart';

class LockScheduleFormScreen extends ConsumerStatefulWidget {
  const LockScheduleFormScreen({super.key, required this.childId, this.schedule});
  final String childId;
  final LockSchedule? schedule;

  @override
  ConsumerState<LockScheduleFormScreen> createState() => _LockScheduleFormScreenState();
}

class _LockScheduleFormScreenState extends ConsumerState<LockScheduleFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.schedule?.name ?? 'Giờ ngủ');
  final _manual = TextEditingController();
  late List<int> _days = widget.schedule?.daysOfWeek ?? [1, 2, 3, 4, 5, 6, 7];
  late String _start = widget.schedule?.startTime ?? '21:30';
  late String _end = widget.schedule?.endTime ?? '06:30';
  late final Set<String> _allowed = {...?widget.schedule?.allowedPackages};
  late bool _enabled = widget.schedule?.enabled ?? true;
  bool _saving = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _name.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    if (_days.isEmpty) errors['daysOfWeek'] = 'Chọn ít nhất 1 ngày trong tuần';
    if (_start == _end) errors['endTime'] = 'Giờ bắt đầu và kết thúc không được trùng nhau';
    setState(() => _errors = errors);
    if (!_form.currentState!.validate() || errors.isNotEmpty) return;

    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'daysOfWeek': _days,
      'startTime': _start,
      'endTime': _end,
      'allowedPackages': _allowed.toList(),
      'enabled': _enabled,
    };
    try {
      final api = ref.read(lockSchedulesApiProvider);
      if (widget.schedule == null) {
        await api.create({...body, 'childId': widget.childId});
      } else {
        await api.update(widget.schedule!.id, body);
      }
      ref.invalidate(lockSchedulesProvider(widget.childId));
      if (!mounted) return;
      showSuccess(context, 'Đã lưu lịch khoá');
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

  void _addManual() {
    final pkg = _manual.text.trim();
    final err = Validators.packageName(pkg);
    if (err != null) return showError(context, err);
    setState(() => _allowed.add(pkg));
    _manual.clear();
  }

  @override
  Widget build(BuildContext context) {
    final apps = ref.watch(childAppsProvider(widget.childId));
    final overnight = _start.compareTo(_end) > 0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.schedule == null ? 'Thêm lịch khoá' : 'Sửa lịch khoá')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            AppTextField(controller: _name, label: 'Tên lịch', icon: Icons.label_outline,
                validator: (v) => Validators.maxLength(v, 40, 'tên lịch'), serverError: _errors['name']),
            const SectionHeader('Áp dụng các ngày'),
            DaysPicker(value: _days, onChanged: (d) => setState(() => _days = d), errorText: _errors['daysOfWeek']),
            AppSpacing.gapMd,
            Row(children: [
              Expanded(child: TimeField(label: 'Bắt đầu', value: _start, onChanged: (v) => setState(() => _start = v))),
              AppSpacing.gapMd,
              Expanded(child: TimeField(label: 'Kết thúc', value: _end, onChanged: (v) => setState(() => _end = v), errorText: _errors['endTime'])),
            ]),
            if (overnight) const Padding(padding: EdgeInsets.only(top: 8), child: Text('🌙 Lịch qua nửa đêm: kết thúc vào sáng hôm sau')),
            SwitchListTile(title: const Text('Bật lịch này'), value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
            const SectionHeader('App được phép trong giờ khoá'),
            apps.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(ApiException.from(e).message),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Máy con chưa gửi danh sách app — nhập tên gói thủ công bên dưới.'),
                    )
                  : Column(children: [
                      for (final a in list)
                        CheckboxListTile(
                          dense: true,
                          title: Text(a.label),
                          subtitle: Text(a.packageName),
                          value: _allowed.contains(a.packageName),
                          onChanged: (v) => setState(() => v! ? _allowed.add(a.packageName) : _allowed.remove(a.packageName)),
                        ),
                    ]),
            ),
            Row(children: [
              Expanded(child: TextField(controller: _manual, decoration: const InputDecoration(labelText: 'Tên gói (vd com.android.chrome)'))),
              IconButton.filledTonal(onPressed: _addManual, icon: const Icon(Icons.add)),
            ]),
            Wrap(spacing: 6, children: [
              for (final p in _allowed) InputChip(label: Text(p), onDeleted: () => setState(() => _allowed.remove(p))),
            ]),
            AppSpacing.gapLg,
            AppButton(label: 'Lưu', icon: Icons.save_outlined, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
