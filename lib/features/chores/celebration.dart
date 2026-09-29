import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _burstEmoji = ['🎉', '⭐', '✨', '🌟', '💫', '🎊'];

/// A short emoji burst over the screen and a light vibration; a bigger burst
/// and a stronger vibration when [big]. With "remove animations" on in the
/// phone's settings there is no burst, only the vibration.
void celebrate(BuildContext context, {bool big = false}) {
  unawaited(big ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact());
  if (MediaQuery.disableAnimationsOf(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Burst(
      count: big ? 24 : 8,
      big: big,
      onDone: () {
        entry.remove();
        entry.dispose();
      },
    ),
  );
  overlay.insert(entry);
}

class _Burst extends StatefulWidget {
  const _Burst({required this.count, required this.big, required this.onDone});

  final int count;
  final bool big;
  final VoidCallback onDone;

  @override
  State<_Burst> createState() => _BurstState();
}

/// Driven by an AnimationController, not a Timer: tearing the screen down
/// disposes it, so nothing is left pending.
class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reach = widget.big ? 0.9 : 0.55;
    return Positioned.fill(
      key: const Key('celebration'),
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Material(
            type: MaterialType.transparency,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_controller.value);
                return Stack(
                  children: [
                    for (var i = 0; i < widget.count; i++)
                      Align(
                        alignment: Alignment(
                          math.cos(2 * math.pi * i / widget.count) * reach * t,
                          -0.1 + math.sin(2 * math.pi * i / widget.count) * reach * t,
                        ),
                        child: Opacity(
                          opacity: 1 - _controller.value,
                          child: Text(
                            _burstEmoji[i % _burstEmoji.length],
                            style: TextStyle(fontSize: widget.big ? 34 : 28),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
