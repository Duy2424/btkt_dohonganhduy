// Danh sách vùng an toàn của 1 con (CRUD): xem trên bản đồ thu nhỏ, bật/tắt nhanh, sửa, xoá
// (server từ chối xoá vùng trường đang gắn thời khoá biểu và báo lý do).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../map/ui/widgets/map_layers.dart';
import '../../data/geofences_api.dart';

class GeofenceListScreen extends ConsumerWidget {
  const GeofenceListScreen({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(geofencesProvider(childId));
    final fences = async.value ?? const <Geofence>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Vùng an toàn')),
      body: AsyncListView<Geofence>(
        value: async,
        onRefresh: () => ref.refresh(geofencesProvider(childId).future),
        emptyMessage: 'Chưa có vùng an toàn.\nThêm "Nhà" và "Trường" để nhận báo khi con đến / rời.',
        emptyIcon: Icons.radar,
        header: fences.isEmpty
            ? null
            : SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                  child: FlutterMap(
                    options: MapOptions(initialCenter: LatLng(fences.first.lat, fences.first.lng), initialZoom: 14),
                    children: [osmTileLayer(), geofenceCircles(fences)],
                  ),
                ),
              ),
        itemBuilder: (context, f) => Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: geofenceColor(f.type).withValues(alpha: 0.2),
              child: Icon(f.type == 'home' ? Icons.home : f.type == 'school' ? Icons.school : Icons.place, color: geofenceColor(f.type)),
            ),
            title: Text(f.name),
            subtitle: Text('${Labels.geofenceType(f.type)} · bán kính ${f.radiusM.round()} m'
                '${f.notifyEnter || f.notifyExit ? ' · báo ${[if (f.notifyEnter) 'vào', if (f.notifyExit) 'ra'].join('/')}' : ''}'),
            onTap: () => context.push('/parent/children/$childId/geofences/form', extra: f),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Switch(value: f.active, onChanged: (v) => _toggle(context, ref, f, v)),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, f)),
            ]),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/parent/children/$childId/geofences/form'),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Thêm vùng'),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, Geofence f, bool active) async {
    try {
      await ref.read(geofencesApiProvider).update(f.id, {'active': active});
      ref.invalidate(geofencesProvider(childId));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Geofence f) async {
    final ok = await confirmDialog(context, title: 'Xoá vùng "${f.name}"?', message: 'Sẽ không còn báo khi con vào/ra vùng này.');
    if (!ok) return;
    try {
      await ref.read(geofencesApiProvider).delete(f.id);
      ref.invalidate(geofencesProvider(childId));
      if (context.mounted) showSuccess(context, 'Đã xoá vùng an toàn');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
