// Tên các event Socket.IO server gửi cho máy phụ huynh. Khai báo một chỗ, app Flutter dùng đúng các tên này.
export const EVENTS = Object.freeze({
  LOCATION_NEW: 'location:new',
  ALERT_NEW: 'alert:new',
  DEVICE_PAIRED: 'device:paired',
  DEVICE_STATUS: 'device:status',
});

export const parentRoom = (parentId) => `parent:${parentId}`;
