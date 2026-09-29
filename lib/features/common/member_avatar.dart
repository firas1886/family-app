import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../core/models.dart';
import '../../core/text.dart';

/// A member's Google photo, or their first letter on their colour.
/// With [progress] (0–1) a ring in their colour shows how much is done.
class MemberAvatar extends ConsumerWidget {
  const MemberAvatar({super.key, required this.member, this.size = 40, this.progress});

  final Member member;
  final double size;
  final double? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(memberColorsProvider)[member.uid] ?? member.color ?? 0;
    final color = personColor(index, Theme.of(context).brightness);
    final url = member.photoUrl;
    final hasPhoto = url != null && url.isNotEmpty;

    // The letter stays underneath the photo, so it shows while the photo
    // loads and if it can't be loaded (offline).
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: color.fill,
      foregroundImage: hasPhoto ? NetworkImage(url) : null,
      onForegroundImageError: hasPhoto ? (_, _) {} : null,
      child: Text(
        tileLetter(member.name),
        style: TextStyle(
          color: color.onFill,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );

    final value = progress;
    if (value == null) return SizedBox.square(dimension: size, child: avatar);

    const ring = 3.0;
    const gap = 2.0;
    final outer = size + 2 * (ring + gap);
    return SizedBox.square(
      dimension: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: outer,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: ring,
              color: color.fill,
              backgroundColor: color.tint,
            ),
          ),
          avatar,
        ],
      ),
    );
  }
}
