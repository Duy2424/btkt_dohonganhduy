// Chức năng nâng cao "QR ghép máy", phía phụ huynh: tạo mã ghép (32 byte, 10 phút, dùng 1 lần), hiện QR
// kèm đồng hồ đếm ngược và nút "Tạo mã mới". Socket báo "device:paired" thì chuyển sang màn ghép thành công.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../children/data/children_api.dart';

class PairingQrScreen extends ConsumerStatefulWidget {
  const PairingQrScreen({super.key, required this.childId});
  final String childId;

  @override
  ConsumerState<PairingQrScreen> createState() => _PairingQrScreenState();
}

class _PairingQrScreenState extends ConsumerState<PairingQrScreen> {
  PairingCode? _code;
  Object? _error;
  Timer? _ticker;
  Duration _left = Duration.zero;
  StreamSubscription<Map<String, dynamic>>? _sub;
  Map<String, dynamic>? _paired;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(realtimeProvider.notifier).devicePaired.listen((e) {
      if (e['childId'] == widget.childId && mounted) {
        _ticker?.cancel();
        setState(() => _paired = e);
      }
    });
    _generate();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _error = null;
      _code = null;
    });
    try {
      final code = await ref.read(childrenApiProvider).createPairingCode(widget.childId);
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final left = code.expiresAt.difference(DateTime.now());
        if (mounted) setState(() => _left = left.isNegative ? Duration.zero : left);
      });
      setState(() {
        _code = code;
        _left = code.expiresAt.difference(DateTime.now());
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _code != null && _left == Duration.zero;
    final mm = _left.inMinutes.toString().padLeft(2, '0');
    final ss = (_left.inSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('Ghép điện thoại của con')),
      body: _paired != null
          ? _Success(name: '${_paired!['childName']}', model: '${_paired!['model'] ?? ''}')
          : _error != null
              ? ErrorView(error: _error!, onRetry: _generate)
              : _code == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        Center(
                          child: Opacity(
                            opacity: expired ? 0.2 : 1,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radius)),
                              child: QrImageView(data: _code!.qrPayload, size: 240),
                            ),
                          ),
                        ),
                        AppSpacing.gapMd,
                        Text(
                          expired ? 'Mã đã hết hạn' : 'Mã hết hạn sau $mm:$ss',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: expired ? AppColors.danger : null),
                        ),
                        AppSpacing.gapLg,
                        AppButton(label: 'Tạo mã mới', icon: Icons.refresh, outlined: !expired, onPressed: _generate),
                      ],
                    ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.name, required this.model});
  final String name;
  final String model;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 72)),
            Text('Ghép thành công!', style: Theme.of(context).textTheme.headlineSmall),
            AppSpacing.gapSm,
            Text('Điện thoại $model của $name đã được ghép.\nBạn sẽ thấy vị trí của con trên bản đồ.', textAlign: TextAlign.center),
            AppSpacing.gapLg,
            AppButton(label: 'Xong', onPressed: () => context.pop()),
          ],
        ),
      ),
    );
  }
}
