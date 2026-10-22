// Chức năng nâng cao "QR ghép máy", phía máy con: quét QR trên máy bố mẹ, gửi mã và thông tin máy
// để nhận token thiết bị, rồi sang màn kiểm tra quyền. QR sai định dạng, hết hạn hay đã dùng đều báo rõ.
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../auth/state/session_controller.dart';
import '../../data/child_device_api.dart';

class PairScanScreen extends ConsumerStatefulWidget {
  const PairScanScreen({super.key});

  @override
  ConsumerState<PairScanScreen> createState() => _PairScanScreenState();
}

class _PairScanScreenState extends ConsumerState<PairScanScreen> {
  final _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  /// QR hợp lệ có dạng `{"t":"conan-pair","c":"mã"}`.
  String? _parse(String? raw) {
    try {
      final json = jsonDecode(raw ?? '') as Map<String, dynamic>;
      if (json['t'] == 'conan-pair' && json['c'] is String) return json['c'] as String;
    } catch (_) {}
    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || capture.barcodes.isEmpty) return;
    final code = _parse(capture.barcodes.first.rawValue);
    if (code == null) {
      setState(() => _message = 'Đây không phải mã QR ghép máy ConAn. Hãy quét mã trên màn "Ghép điện thoại của con".');
      return;
    }
    await _pair(code);
  }

  /// Chỉ bản debug: nhập mã ghép bằng tay để test trên 1 máy (không quét được QR trên chính màn hình mình).
  Future<void> _enterCodeManually() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập mã ghép (bản debug)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(hintText: 'Mã trong QR (phần "c")'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Ghép')),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) await _pair(_parse(code) ?? code);
  }

  Future<void> _pair(String code) async {
    setState(() {
      _busy = true;
      _message = 'Đang ghép...';
    });
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final result = await ref.read(childDeviceApiProvider).pair(
            code: code,
            model: '${info.manufacturer} ${info.model}',
            androidVersion: info.version.release,
            appVersion: Env.appVersion,
          );
      await ref.read(sessionProvider.notifier).pairedAsChild(result['deviceToken'] as String);
      if (!mounted) return;
      showSuccess(context, 'Đã ghép với tài khoản của ${result['parentName']}');
      context.go('/child/permissions');
    } catch (e) {
      final err = ApiException.from(e);
      setState(() {
        _message = err.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Ghép với máy bố mẹ'),
        actions: [
          TextButton(
            onPressed: () => ref.read(sessionProvider.notifier).resetMode(),
            child: const Text('Đổi loại máy'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              child: MobileScanner(controller: _scanner, onDetect: _onDetect),
            ),
          ),
          AppSpacing.gapMd,
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(_message!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ),
          if (kDebugMode)
            TextButton.icon(
              onPressed: _busy ? null : _enterCodeManually,
              icon: const Icon(Icons.keyboard),
              label: const Text('Nhập mã thủ công (chỉ bản debug)'),
            ),
        ],
      ),
    );
  }
}
