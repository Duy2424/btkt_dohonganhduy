// Biến môi trường cho test: email in ra console, secret giả, database test riêng.
process.env.NODE_ENV = 'test';
process.env.MONGODB_URI = process.env.MONGODB_URI_TEST || 'mongodb://placeholder';
process.env.MONGODB_DB_NAME = 'ConAnDB_DoHongAnhDuy_test';
process.env.JWT_ACCESS_SECRET = 'test-access-secret-1234567890';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-1234567890';
process.env.OTP_PEPPER = 'test-pepper';
process.env.EMAIL_PROVIDER = 'console';
process.env.APP_TIMEZONE = 'Asia/Ho_Chi_Minh';
