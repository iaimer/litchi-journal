import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/focus_timer.dart';
import '../services/focus_timer_controller.dart';
import '../widgets/habit_icon.dart';

typedef SaveFocusDuration =
    Future<bool> Function(FocusTimerSession session, int minutes);

class FocusTimerScreen extends StatefulWidget {
  final FocusTimerController controller;
  final SaveFocusDuration onSave;
  final VoidCallback? onPositiveFeedback;

  const FocusTimerScreen({
    super.key,
    required this.controller,
    required this.onSave,
    this.onPositiveFeedback,
  });

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final session = widget.controller.session;
        if (session == null) {
          return const Scaffold(body: Center(child: Text('没有正在进行的专注计时')));
        }
        final seconds = widget.controller.elapsedSeconds();
        final color = Color(session.colorArgb);
        return Scaffold(
          appBar: AppBar(title: const Text('专注计时')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HabitIcon(session.icon, size: 22, color: color),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          session.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    label:
                        '${session.displayName}，已专注 ${_formatDuration(seconds)}',
                    value: session.isRunning ? '专注中' : '已暂停',
                    child: SizedBox(
                      width: 292,
                      height: 292,
                      child: CustomPaint(
                        painter: _FocusTimerRingPainter(
                          progress:
                              (seconds % const Duration(hours: 1).inSeconds) /
                              const Duration(hours: 1).inSeconds,
                          color: color,
                          trackColor: Theme.of(context).dividerColor,
                          strokeWidth: 12,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatDuration(seconds),
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                session.isRunning ? '专注中' : '已暂停',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '60 分钟循环',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    session.dailyTargetMinutes == null
                        ? '今天已记录 ${session.currentMinutes} 分钟'
                        : '今天已记录 ${session.currentMinutes} / ${session.dailyTargetMinutes} 分钟',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.controller.isBusy || _saving
                              ? null
                              : session.isRunning
                              ? widget.controller.pause
                              : widget.controller.resume,
                          icon: Icon(
                            session.isRunning ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(session.isRunning ? '暂停' : '继续'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: widget.controller.isBusy || _saving
                              ? null
                              : () => _finish(session),
                          icon: const Icon(Icons.check),
                          label: const Text('完成'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _finish(FocusTimerSession session) async {
    final seconds = widget.controller.elapsedSeconds();
    final minutes = seconds ~/ 60;
    final action = await showModalBottomSheet<_FinishAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('结束这次专注？', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  minutes > 0 ? '本次可保存 $minutes 分钟' : '本次不足 1 分钟，不会写入日记',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, _FinishAction.discard),
                        child: const Text('放弃本次'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: minutes == 0
                            ? null
                            : () => Navigator.pop(
                                sheetContext,
                                _FinishAction.save,
                              ),
                        child: Text(
                          minutes == 0 ? '不足 1 分钟' : '保存 $minutes 分钟',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;

    if (action == _FinishAction.discard) {
      final ok = await widget.controller.discard();
      if (ok && mounted) Navigator.pop(context, false);
      return;
    }

    setState(() => _saving = true);
    final ok = await widget.onSave(session, minutes);
    if (!mounted) return;
    if (!ok) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，计时仍保留')));
      return;
    }
    final cleared = await widget.controller.clearAfterSave();
    if (mounted && !cleared) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存，但本地计时状态清理失败，本次不会重复保存')));
    }
    widget.onPositiveFeedback?.call();
    if (mounted) Navigator.pop(context, true);
  }

  static String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}'
        ':${minutes.toString().padLeft(2, '0')}'
        ':${seconds.toString().padLeft(2, '0')}';
  }
}

enum _FinishAction { save, discard }

class _FocusTimerRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _FocusTimerRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor.withAlpha(70);
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.max(0.015, math.pi * 2 * progress),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FocusTimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
