import 'package:flutter/material.dart';
import 'package:peerpass/core/theme/app_colors.dart';
import 'package:peerpass/core/widgets/app_pill.dart';

/// A person's avatar.
///
/// The beta ships generated avatars rather than photos: a student is not asked
/// to upload a picture to be helped, and a gradient with initials still makes
/// two tutors distinguishable at a glance. The image path exists and is used
/// when [imageUrl] is set, so turning photos on later is a server change, not a
/// widget rewrite.
///
/// The gradient is chosen from the name, which means the same person keeps the
/// same colours between screens and sessions without the API having to store a
/// colour.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    this.imageUrl,
    this.size = 44,
    this.isVerified = false,
    this.hasRing = false,
    super.key,
  });

  final String name;

  /// A real photo, when one exists. Falls back to initials if it cannot load.
  final String? imageUrl;

  final double size;

  /// Draws the mint verified tick on the avatar's corner.
  final bool isVerified;

  /// Draws a cream ring, for an avatar sitting on a coloured surface.
  final bool hasRing;

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientFor(name);
    final initials = _initialsOf(name);

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: hasRing
            ? Border.all(color: AppColors.white, width: size * 0.06)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imageUrl == null
          ? _Initials(initials: initials, size: size)
          : Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // A broken photo must not leave a hole where a person should be.
              errorBuilder: (context, error, stack) =>
                  _Initials(initials: initials, size: size),
            ),
    );

    return Semantics(
      image: true,
      label: name,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            if (isVerified)
              Positioned(
                right: 0,
                bottom: 0,
                child: AppVerifiedDot(size: size * 0.32),
              ),
          ],
        ),
      ),
    );
  }

  static String _initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }

  static List<Color> _gradientFor(String name) {
    if (name.isEmpty) return AppColors.avatarGradients.first;
    final seed = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return AppColors.avatarGradients[seed % AppColors.avatarGradients.length];
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: TextStyle(
        color: AppColors.white,
        fontSize: size * 0.36,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}
