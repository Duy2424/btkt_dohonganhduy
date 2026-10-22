// 4 trạng thái chuẩn của mọi màn danh sách: đang tải (skeleton), rỗng, lỗi (nút Thử lại), có dữ liệu.
// AsyncListView gói cả 4 trạng thái + kéo để làm mới (pull-to-refresh).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';

class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key, this.itemCount = 5, this.itemHeight = 76});
  final int itemCount;
  final double itemHeight;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_ctrl),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.page,
        itemCount: widget.itemCount,
        separatorBuilder: (_, _) => AppSpacing.gapSm,
        itemBuilder: (_, _) => Container(
          height: widget.itemHeight,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppSpacing.radius)),
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined, this.action});
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: scheme.outline),
            AppSpacing.gapMd,
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (action != null) ...[AppSpacing.gapMd, action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = ApiException.from(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(e.isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 64, color: Theme.of(context).colorScheme.error),
            AppSpacing.gapMd,
            Text(e.message, textAlign: TextAlign.center),
            AppSpacing.gapMd,
            FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

/// Danh sách có đủ 4 trạng thái + pull-to-refresh.
class AsyncListView<T> extends StatelessWidget {
  const AsyncListView({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.itemBuilder,
    required this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
  });

  final AsyncValue<List<T>> value;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;
  final Widget? header;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      loading: () => const LoadingSkeleton(),
      error: (e, _) => ErrorView(error: e, onRetry: onRefresh),
      data: (items) => RefreshIndicator(
        onRefresh: onRefresh,
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ?header,
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.55,
                    child: EmptyView(message: emptyMessage, icon: emptyIcon, action: emptyAction),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: padding,
                itemCount: items.length + (header == null ? 0 : 1),
                separatorBuilder: (_, _) => AppSpacing.gapSm,
                itemBuilder: (context, i) {
                  if (header != null) {
                    if (i == 0) return header!;
                    return itemBuilder(context, items[i - 1]);
                  }
                  return itemBuilder(context, items[i]);
                },
              ),
      ),
    );
  }
}
