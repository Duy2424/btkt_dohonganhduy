// Bọc controller async: lỗi ném ra được chuyển sang errorHandler thay vì làm treo request.
export const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// Trả response thành công theo chuẩn { success: true, data, message? }.
export function ok(res, data, message, status = 200) {
  const body = { success: true, data };
  if (message) body.message = message;
  return res.status(status).json(body);
}
