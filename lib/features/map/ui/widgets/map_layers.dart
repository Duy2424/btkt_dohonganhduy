// Lớp bản đồ dùng chung (flutter_map + OpenStreetMap, không cần API key): nền OSM, vòng tròn vùng an toàn, marker con.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../geofences/data/geofences_api.dart';

/// Trung tâm mặc định khi chưa có vị trí (TP.HCM).
const defaultCenter = LatLng(10.7769, 106.7009);

/// Nền bản đồ OpenStreetMap. Một số nhà mạng ở Việt Nam chặn DNS của tile.openstreetmap.org
/// (bản đồ xám) → tự chuyển sang máy chủ OpenStreetMap Đức (cùng dữ liệu OSM, không cần API key).
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      fallbackUrl: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.dohonganhduy.btkt_dohonganhduy',
    );

/// Ghi nguồn dữ liệu bản đồ theo điều khoản của OpenStreetMap.
const mapAttribution = SimpleAttributionWidget(source: Text('OpenStreetMap contributors'));

Color geofenceColor(String type) => switch (type) {
      'home' => AppColors.success,
      'school' => AppColors.info,
      _ => AppColors.seed,
    };

CircleLayer geofenceCircles(List<Geofence> fences) => CircleLayer(
      circles: [
        for (final f in fences.where((f) => f.active))
          CircleMarker(
            point: LatLng(f.lat, f.lng),
            radius: f.radiusM,
            useRadiusInMeter: true,
            color: geofenceColor(f.type).withValues(alpha: 0.15),
            borderColor: geofenceColor(f.type),
            borderStrokeWidth: 2,
          ),
      ],
    );

/// Marker tròn màu avatar + tên con.
Marker childMarker({required LatLng point, required String name, required Color color, VoidCallback? onTap}) => Marker(
      point: point,
      width: 120,
      height: 66,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            Icon(Icons.location_on, color: color, size: 40),
          ],
        ),
      ),
    );
