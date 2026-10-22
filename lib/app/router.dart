// Điều hướng go_router + redirect theo role (yêu cầu 3): chưa đăng nhập → /login; admin → /admin;
// nhân viên → /staff; phụ huynh → /parent; máy con → /child. Vào nhầm khu của role khác → đẩy về trang của mình.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/local_prefs.dart';
import '../features/admin/ui/screens/admin_shell.dart';
import '../features/admin/ui/screens/user_form_screen.dart';
import '../features/auth/data/models/app_user.dart';
import '../features/auth/state/session_controller.dart';
import '../features/auth/ui/screens/account_screen.dart';
import '../features/auth/ui/screens/forgot_password_screen.dart';
import '../features/auth/ui/screens/login_screen.dart';
import '../features/auth/ui/screens/otp_screen.dart';
import '../features/auth/ui/screens/register_screen.dart';
import '../features/child_mode/ui/screens/child_home_screen.dart';
import '../features/child_mode/ui/screens/pair_scan_screen.dart';
import '../features/child_mode/ui/screens/permission_check_screen.dart';
import '../features/children/ui/screens/child_detail_screen.dart';
import '../features/children/ui/screens/child_form_screen.dart';
import '../features/devices/ui/screens/device_list_screen.dart';
import '../features/devices/ui/screens/pairing_qr_screen.dart';
import '../features/face_login/ui/screens/face_enroll_screen.dart';
import '../features/face_login/ui/screens/face_login_screen.dart';
import '../features/geofences/ui/screens/geofence_form_screen.dart';
import '../features/geofences/ui/screens/geofence_list_screen.dart';
import '../features/lock_schedules/ui/screens/lock_schedule_form_screen.dart';
import '../features/onboarding/ui/screens/onboarding_screen.dart';
import '../features/alerts/ui/screens/alerts_screen.dart';
import '../features/parent/ui/screens/about_screen.dart';
import '../features/parent/ui/screens/parent_shell.dart';
import '../features/school_schedule/ui/screens/school_session_form_screen.dart';
import '../features/staff/ui/screens/staff_shell.dart';
import '../features/tickets/ui/screens/ticket_detail_screen.dart';
import '../features/tickets/ui/screens/ticket_form_screen.dart';
import '../features/tickets/ui/screens/ticket_list_screen.dart';

const _publicPaths = {'/login', '/register', '/otp', '/forgot-password', '/face-login'};

/// Quy tắc điều hướng, viết thành hàm thuần để dễ test và dễ giải thích.
String? redirectFor(SessionState s, String path) {
  if (!s.ready) return path == '/splash' ? null : '/splash';
  if (s.mode == null) return path == '/onboarding' ? null : '/onboarding';

  if (s.mode == AppMode.child) {
    if (!s.childPaired) return path == '/child/pair' ? null : '/child/pair';
    return (path.startsWith('/child') && path != '/child/pair') ? null : '/child';
  }

  if (!s.loggedIn) return _publicPaths.contains(path) ? null : '/login';
  final home = s.user!.homePath;
  if (_publicPaths.contains(path) || path == '/splash' || path == '/onboarding' || path.startsWith('/child')) return home;
  for (final area in ['/admin', '/staff', '/parent']) {
    if (path.startsWith(area) && area != home) return home;
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String id(GoRouterState s, [String key = 'id']) => s.pathParameters[key]!;

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(ref.read(sessionProvider), state.uri.path),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/otp', builder: (_, s) => OtpScreen(args: s.extra! as OtpArgs)),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: '/face-login', builder: (_, _) => const FaceLoginScreen()),
      // Dùng chung cho mọi role đã đăng nhập
      GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      GoRoute(path: '/face-setup', builder: (_, _) => const FaceEnrollScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      GoRoute(path: '/tickets/:id', builder: (_, s) => TicketDetailScreen(ticketId: id(s))),
      GoRoute(path: '/admin', builder: (_, _) => const AdminShell(), routes: [
        GoRoute(path: 'users/new', builder: (_, _) => const UserFormScreen()),
        GoRoute(path: 'users/edit', builder: (_, s) => UserFormScreen(user: s.extra as AppUser?)),
      ]),
      GoRoute(path: '/staff', builder: (_, _) => const StaffShell()),
      GoRoute(path: '/parent', builder: (_, _) => const ParentShell(), routes: [
        GoRoute(path: 'alerts', builder: (_, _) => const AlertsScreen()),
        GoRoute(path: 'devices', builder: (_, _) => const DeviceListScreen()),
        GoRoute(path: 'tickets', builder: (_, _) => const TicketListScreen()),
        GoRoute(path: 'tickets/new', builder: (_, _) => const TicketFormScreen()),
        GoRoute(path: 'children/new', builder: (_, _) => const ChildFormScreen()),
        GoRoute(path: 'children/:id', builder: (_, s) => ChildDetailScreen(childId: id(s)), routes: [
          GoRoute(path: 'edit', builder: (_, s) => ChildFormScreen(childId: id(s))),
          GoRoute(path: 'pair', builder: (_, s) => PairingQrScreen(childId: id(s))),
          GoRoute(path: 'geofences', builder: (_, s) => GeofenceListScreen(childId: id(s))),
          GoRoute(path: 'geofences/form', builder: (_, s) => GeofenceFormScreen(childId: id(s), geofence: s.extra as dynamic)),
          GoRoute(path: 'sessions/form', builder: (_, s) => SchoolSessionFormScreen(childId: id(s), session: s.extra as dynamic)),
          GoRoute(path: 'locks/form', builder: (_, s) => LockScheduleFormScreen(childId: id(s), schedule: s.extra as dynamic)),
        ]),
      ]),
      GoRoute(path: '/child', builder: (_, _) => const ChildHomeScreen(), routes: [
        GoRoute(path: 'pair', builder: (_, _) => const PairScanScreen()),
        GoRoute(path: 'permissions', builder: (_, _) => const PermissionCheckScreen()),
      ]),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
