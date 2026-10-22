// Chức năng nâng cao "Chia sẻ vị trí", phía phụ huynh: bản đồ realtime mọi con (marker màu và tên), vòng tròn
// vùng an toàn, "cập nhật X phút trước", % pin; xem lịch sử theo ngày (polyline); nút "Định vị ngay".
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../children/data/children_api.dart';
import '../../../children/data/models/child_profile.dart';
import '../../../children/state/children_providers.dart';
import '../../../devices/data/devices_api.dart';
import '../../../geofences/data/geofences_api.dart';
import '../widgets/map_layers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  DateTime? _historyDate;
  List<GeoPoint> _history = const [];
  bool _loadingHistory = false;

  void _focus(ChildProfile c) {
    ref.read(selectedChildIdProvider.notifier).select(c.id);
    setState(() {
      _historyDate = null;
      _history = const [];
    });
    if (c.lastLocation != null) _map.move(LatLng(c.lastLocation!.lat, c.lastLocation!.lng), 16);
  }

  Future<void> _pickHistory(ChildProfile c) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 6)), // vị trí lưu 7 ngày
      lastDate: now,
      initialDate: _historyDate ?? now,
      helpText: 'Xem lịch sử di chuyển',
    );
    if (date == null) return;
    setState(() => _loadingHistory = true);
    try {
      final points = await ref.read(childrenApiProvider).history(c.id, AppDates.ymd(date));
      setState(() {
        _historyDate = date;
        _history = points;
      });
      if (points.isNotEmpty) {
        _map.fitCamera(CameraFit.coordinates(
          coordinates: points.map((p) => LatLng(p.lat, p.lng)).toList(),
          padding: const EdgeInsets.all(48),
        ));
      } else if (mounted) {
        showError(context, 'Không có vị trí nào trong ngày ${AppDates.dmy(date)}');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _locateNow(ChildProfile c) async {
    if (c.device == null) return showError(context, '${c.name} chưa ghép điện thoại');
    try {
      await ref.read(devicesApiProvider).locateNow(c.device!.id);
      if (mounted) showSuccess(context, 'Đã gửi yêu cầu định vị tới máy của ${c.name}');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Vị trí realtime của con đang chọn đổi → bản đồ đi theo (trừ khi đang xem lịch sử)
    ref.listen(selectedChildProvider, (prev, next) {
      final loc = next?.lastLocation;
      if (loc == null || _historyDate != null) return;
      final moved = prev?.id == next?.id && (prev?.lastLocation?.lat != loc.lat || prev?.lastLocation?.lng != loc.lng);
      if (!moved) return; // đổi con đã có _focus() lo
      try {
        _map.move(LatLng(loc.lat, loc.lng), _map.camera.zoom);
      } catch (_) {
        // Bản đồ chưa dựng xong (đang tải) → bỏ qua
      }
    });
    final async = ref.watch(childrenProvider);
    final children = async.value ?? const <ChildProfile>[];
    final selected = ref.watch(selectedChildProvider);
    if (async.isLoading && children.isEmpty) return const LoadingSkeleton(itemCount: 1, itemHeight: 400);
    if (async.hasError && children.isEmpty) {
      return ErrorView(error: async.error!, onRetry: () => ref.read(childrenProvider.notifier).refresh());
    }
    if (children.isEmpty) return const EmptyView(message: 'Thêm hồ sơ con và ghép điện thoại để xem bản đồ', icon: Icons.map_outlined);

    final fences = selected == null ? const <Geofence>[] : (ref.watch(geofencesProvider(selected.id)).value ?? const <Geofence>[]);
    final located = children.where((c) => c.lastLocation != null).toList();
    final start = selected?.lastLocation ?? located.firstOrNull?.lastLocation;

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: start == null ? defaultCenter : LatLng(start.lat, start.lng),
            initialZoom: 15,
          ),
          children: [
            osmTileLayer(),
            geofenceCircles(fences),
            if (_history.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points: _history.map((p) => LatLng(p.lat, p.lng)).toList(),
                  strokeWidth: 5,
                  color: AppColors.fromHex(selected?.avatarColor),
                ),
              ]),
            MarkerLayer(markers: [
              for (final c in located)
                childMarker(
                  point: LatLng(c.lastLocation!.lat, c.lastLocation!.lng),
                  name: c.name,
                  color: AppColors.fromHex(c.avatarColor),
                  onTap: () => _focus(c),
                ),
            ]),
            mapAttribution,
          ],
        ),
        Positioned(
          top: AppSpacing.sm,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                for (final c in children)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: ChildAvatar(name: c.name, color: c.avatarColor, radius: 12),
                      label: Text(c.name),
                      selected: selected?.id == c.id,
                      onSelected: (_) => _focus(c),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (selected != null) Positioned(left: AppSpacing.md, right: AppSpacing.md, bottom: AppSpacing.md, child: _infoCard(selected)),
      ],
    );
  }

  Widget _infoCard(ChildProfile c) {
    final d = c.device;
    final battery = d?.batteryLevel ?? c.lastLocation?.battery;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ChildAvatar(name: c.name, color: c.avatarColor, online: d?.online),
              AppSpacing.gapMd,
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${c.name} · ${c.placeName}', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    c.lastLocation == null
                        ? (d == null ? 'Chưa ghép điện thoại' : 'Chưa có vị trí')
                        : 'Cập nhật ${AppDates.ago(c.lastLocation!.at)}${battery != null ? ' · Pin $battery%' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ]),
              ),
            ]),
            if (_historyDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Lịch sử ngày ${AppDates.dmy(_historyDate)}: ${_history.length} điểm',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            AppSpacing.gapSm,
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadingHistory ? null : () => _pickHistory(c),
                  icon: const Icon(Icons.history),
                  label: Text(_loadingHistory ? 'Đang tải...' : 'Lịch sử'),
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _locateNow(c),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Định vị ngay'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
