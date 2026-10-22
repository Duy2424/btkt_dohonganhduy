// Tính khoảng cách haversine giữa 2 toạ độ và kiểm tra "trong / ngoài vùng an toàn" có chống GPS nhảy.
const EARTH_RADIUS_M = 6371000;

const toRad = (deg) => (deg * Math.PI) / 180;

/** Khoảng cách (mét) giữa 2 điểm { lat, lng }. */
export function distanceMeters(a, b) {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
}

/**
 * "Ngoài vùng" = khoảng cách > bán kính + max(accuracy, 30 m) (SPEC mục 5).
 * Cộng thêm sai số để vị trí GPS chập chờn không gây báo động giả.
 */
export function isOutsideFence(point, fence) {
  const margin = Math.max(point.accuracy ?? 0, 30);
  return distanceMeters(point, fence.center) > fence.radiusM + margin;
}

/** "Trong vùng" dùng cho báo vào/ra: khoảng cách ≤ bán kính. */
export function isInsideFence(point, fence) {
  return distanceMeters(point, fence.center) <= fence.radiusM;
}
