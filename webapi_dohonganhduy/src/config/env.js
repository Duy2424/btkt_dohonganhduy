// Đọc và kiểm tra biến môi trường bằng zod lúc khởi động.
// Thiếu hoặc sai biến bắt buộc thì in tên biến ra rồi thoát luôn.
import { z } from 'zod';

const schema = z
  .object({
    NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
    PORT: z.coerce.number().int().positive().default(4000),
    MONGODB_URI: z.string().min(1, 'Thiếu chuỗi kết nối MongoDB'),
    MONGODB_DB_NAME: z.string().min(1, 'Thiếu tên database'),
    JWT_ACCESS_SECRET: z.string().min(16, 'Tối thiểu 16 ký tự'),
    JWT_REFRESH_SECRET: z.string().min(16, 'Tối thiểu 16 ký tự'),
    ACCESS_TOKEN_TTL: z.string().default('15m'),
    JWT_ISSUER: z.string().min(1).default('webapi-dohonganhduy'),
    JWT_AUDIENCE: z.string().min(1).default('conan-app'),
    REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().positive().default(30),
    OTP_PEPPER: z.string().min(8, 'Tối thiểu 8 ký tự'),
    EMAIL_PROVIDER: z.enum(['gmail', 'brevo', 'console']).default('console'),
    GMAIL_USER: z.string().optional(),
    GMAIL_APP_PASSWORD: z.string().optional(),
    BREVO_API_KEY: z.string().optional(),
    MAIL_FROM_EMAIL: z.string().optional(),
    MAIL_FROM_NAME: z.string().default('ConAn'),
    FIREBASE_SERVICE_ACCOUNT_BASE64: z.string().optional(),
    APP_TIMEZONE: z.string().default('Asia/Ho_Chi_Minh'),
    PUBLIC_BASE_URL: z.string().optional(),
  })
  .superRefine((env, ctx) => {
    if (env.NODE_ENV === 'production' && env.EMAIL_PROVIDER === 'console') {
      ctx.addIssue({
        code: 'custom',
        path: ['EMAIL_PROVIDER'],
        message: 'Production không được dùng console — chọn gmail hoặc brevo',
      });
    }
    if (env.EMAIL_PROVIDER === 'gmail' && (!env.GMAIL_USER || !env.GMAIL_APP_PASSWORD)) {
      ctx.addIssue({
        code: 'custom',
        path: ['GMAIL_USER'],
        message: 'EMAIL_PROVIDER=gmail cần GMAIL_USER và GMAIL_APP_PASSWORD',
      });
    }
    if (env.EMAIL_PROVIDER === 'brevo' && (!env.BREVO_API_KEY || !env.MAIL_FROM_EMAIL)) {
      ctx.addIssue({
        code: 'custom',
        path: ['BREVO_API_KEY'],
        message: 'EMAIL_PROVIDER=brevo cần BREVO_API_KEY và MAIL_FROM_EMAIL',
      });
    }
  });

function loadEnv() {
  const result = schema.safeParse(process.env);
  if (!result.success) {
    console.error('❌ Biến môi trường không hợp lệ (xem webapi_dohonganhduy/.env.example):');
    for (const issue of result.error.issues) {
      console.error(`   - ${issue.path.join('.')}: ${issue.message}`);
    }
    process.exit(1);
  }
  return Object.freeze(result.data);
}

export const env = loadEnv();
