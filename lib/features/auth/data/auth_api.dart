// Gọi các API xác thực & tài khoản: /api/auth/* và /api/users/me/*.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import 'models/app_user.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

class AuthApi {
  AuthApi(this._api);
  final ApiClient _api;

  Map<String, dynamic> _map(dynamic d) => Map<String, dynamic>.from(d as Map);

  Future<OtpChallenge> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    String phone = '',
  }) async =>
      OtpChallenge.fromJson(_map(await _api.post('/api/auth/register', auth: false, data: {
        'fullName': fullName,
        'username': username,
        'email': email,
        'password': password,
        'phone': phone,
      })));

  Future<AppUser> verifyEmail(String otpSessionId, String code) async {
    final d = _map(await _api.post('/api/auth/verify-email', auth: false, data: {'otpSessionId': otpSessionId, 'code': code}));
    return AppUser.fromJson(_map(d['user']));
  }

  Future<OtpChallenge> resendOtp(String otpSessionId) async =>
      OtpChallenge.fromJson(_map(await _api.post('/api/auth/resend-otp', auth: false, data: {'otpSessionId': otpSessionId})));

  Future<OtpChallenge> resendVerifyEmail(String email) async => OtpChallenge.fromJson(
      _map(await _api.post('/api/auth/resend-otp', auth: false, data: {'email': email, 'purpose': 'verify_email'})));

  Future<OtpChallenge> login(String username, String password, String deviceId, String deviceName) async =>
      OtpChallenge.fromJson(_map(await _api.post('/api/auth/login', auth: false, data: {
        'username': username,
        'password': password,
        'deviceId': deviceId,
        'deviceName': deviceName,
      })));

  Future<AuthResult> verifyLoginOtp(String otpSessionId, String code) async => AuthResult.fromJson(
      _map(await _api.post('/api/auth/login/verify-otp', auth: false, data: {'otpSessionId': otpSessionId, 'code': code})));

  Future<AuthResult> faceLogin(String deviceId, String faceToken) async => AuthResult.fromJson(
      _map(await _api.post('/api/auth/face-login', auth: false, data: {'deviceId': deviceId, 'refreshToken': faceToken})));

  Future<void> logout(String refreshToken) =>
      _api.post('/api/auth/logout', auth: false, data: {'refreshToken': refreshToken});

  Future<OtpChallenge> forgotPassword(String email) async =>
      OtpChallenge.fromJson(_map(await _api.post('/api/auth/forgot-password', auth: false, data: {'email': email})));

  Future<void> resetPassword(String otpSessionId, String code, String newPassword) => _api.post(
        '/api/auth/reset-password',
        auth: false,
        data: {'otpSessionId': otpSessionId, 'code': code, 'newPassword': newPassword},
      );

  Future<AppUser> me() async => AppUser.fromJson(_map(await _api.get('/api/auth/me')));

  Future<AppUser> updateMe({required String fullName, required String phone}) async =>
      AppUser.fromJson(_map(await _api.patch('/api/users/me', data: {'fullName': fullName, 'phone': phone})));

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _api.patch('/api/users/me/password', data: {'currentPassword': currentPassword, 'newPassword': newPassword});

  /// Bật → trả về faceToken (lưu secure storage để đăng nhập bằng khuôn mặt lần sau).
  Future<String?> setFaceLogin({required bool enabled, required String deviceId, String? deviceName, String? password}) async {
    final d = _map(await _api.patch('/api/users/me/face-login', data: {
      'enabled': enabled,
      'deviceId': deviceId,
      'deviceName': ?deviceName,
      'password': ?password,
    }));
    return d['faceToken'] as String?;
  }

  Future<void> setFcmToken(String token) => _api.patch('/api/users/me/fcm-token', data: {'token': token});

  Future<Map<String, dynamic>> health() => _api.raw('/health');
}
