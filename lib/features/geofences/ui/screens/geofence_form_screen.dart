// Thêm / sửa vùng an toàn: chạm bản đồ để đặt tâm, kéo slider bán kính 50–1000 m, chọn loại (Nhà / Trường / Khác),
// bật/tắt báo khi vào / ra.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../children/state/children_providers.dart';
import '../../../map/ui/widgets/map_layers.dart';
import '../../data/geofences_api.dart';

class GeofenceFormScreen extends ConsumerStatefulWidget {
  const GeofenceFormScreen({super.key, required this.childId, this.geofence});
  final String childId;
  final Geofence? geofence;

  @override
  ConsumerState<GeofenceFormScreen> createState() => _GeofenceFormScreenState();
}

class _GeofenceFormScreenState extends ConsumerState<GeofenceFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.geofence?.name ?? '');
  late String _type = widget.geofence?.type ?? 'home';
  late LatLng? _center = widget.geofence == null ? null : LatLng(widget.geofence!.lat, widget.geofence!.lng);
  late double _radius = widget.geofence?.radiusM ?? 150;
  late bool _enter = widget.geofence?.notifyEnter ?? true;
  late bool _exit = widget.geofence?.notifyExit ?? true;
  bool _saving = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  LatLng get _initialCenter {
    if (_center != null) return _center!;
    final child = (ref.read(childrenProvider).value ?? const []).where((c) => c.id == widget.childId).firstOrNull;
    final loc = child?.lastLocation;
    return loc == null ? defaultCenter : LatLng(loc.lat, loc.lng);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_center == null) return showError(context, 'Hãy chạm vào bản đồ để chọn tâm vùng');
    setState(() {
      _saving = true;
      _nameError = null;
    });
    final body = {
      'name': _name.text.trim(),
      'type': _type,
      'center': {'lat': _center!.latitude, 'lng': _center!.longitude},
      'radiusM': _radius.roundToDouble(),
      'notifyEnter': _enter,
      'notifyExit': _exit,
    };
    try {
      final api = ref.read(geofencesApiProvider);
      if (widget.geofence == null) {
        await api.create({...body, 'childId': widget.childId});
      } else {
        await api.update(widget.geofence!.id, body);
      }
      ref.invalidate(geofencesProvider(widget.childId));
      ref.read(childrenProvider.notifier).refresh();
      if (!mounted) return;
      showSuccess(context, widget.geofence == null ? 'Đã tạo vùng an toàn' : 'Đã cập nhật vùng an toàn');
      context.pop();
    } catch (e) {
      final err = ApiException.from(e);
      if (!mounted) return;
      if (err.fieldErrors['name'] != null) {
        setState(() => _nameError = err.fieldErrors['name']);
      } else {
        showError(context, err);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.geofence == null ? 'Thêm vùng an toàn' : 'Sửa vùng an toàn')),
      body: Form(
        key: _form,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 15,
                    onTap: (_, point) => setState(() => _center = point),
                  ),
                  children: [
                    osmTileLayer(),
                    if (_center != null)
                      CircleLayer(circles: [
                        CircleMarker(
                          point: _center!,
                          radius: _radius,
                          useRadiusInMeter: true,
                          color: geofenceColor(_type).withValues(alpha: 0.2),
                          borderColor: geofenceColor(_type),
                          borderStrokeWidth: 2,
                        ),
                      ]),
                    if (_center != null)
                      MarkerLayer(markers: [
                        Marker(point: _center!, child: Icon(Icons.my_location, color: geofenceColor(_type))),
                      ]),
                  ],
                ),
              ),
            ),
            AppSpacing.gapSm,
            Text(_center == null ? '👆 Chạm vào bản đồ để đặt tâm vùng' : 'Chạm chỗ khác để dời tâm',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            AppSpacing.gapMd,
            AppTextField(
              controller: _name,
              label: 'Tên vùng',
              icon: Icons.label_outline,
              validator: (v) => Validators.maxLength(v, 50, 'tên vùng'),
              serverError: _nameError,
            ),
            AppSpacing.gapMd,
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'home', label: Text('Nhà'), icon: Icon(Icons.home_outlined)),
                ButtonSegment(value: 'school', label: Text('Trường'), icon: Icon(Icons.school_outlined)),
                ButtonSegment(value: 'other', label: Text('Khác'), icon: Icon(Icons.place_outlined)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            AppSpacing.gapMd,
            Text('Bán kính: ${_radius.round()} m', style: Theme.of(context).textTheme.titleSmall),
            Slider(
              value: _radius,
              min: 50,
              max: 1000,
              divisions: 95,
              label: '${_radius.round()} m',
              onChanged: (v) => setState(() => _radius = v),
            ),
            SwitchListTile(title: const Text('Báo khi con vào vùng'), value: _enter, onChanged: (v) => setState(() => _enter = v)),
            SwitchListTile(title: const Text('Báo khi con rời vùng'), value: _exit, onChanged: (v) => setState(() => _exit = v)),
            AppSpacing.gapMd,
            AppButton(label: 'Lưu', icon: Icons.save_outlined, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
