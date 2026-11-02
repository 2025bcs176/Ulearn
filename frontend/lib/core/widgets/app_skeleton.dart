import 'package:flutter/material.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_palette.dart';

/// A quiet placeholder for content that is still loading.
///
/// Skeletons beat a centred spinner on a list because the page keeps its shape:
/// the student sees where the tutor cards are about to appear instead of a
/// blank screen that jumps when the data lands.
///
/// The shimmer is skipped entirely when the platform asks for reduced motion,
/// and the block is drawn at a single static opacity instead.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    required this.height,
    this.width,
    this.radius = AppDimens.radiusMd,
    super.key,
  });

  /// A single line of text.
  const AppSkeleton.line({this.width = double.infinity, super.key})
    : height = 12,
      radius = 6;

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final block = DecoratedBox(
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: SizedBox(width: widget.width, height: widget.height),
    );

    if (reduceMotion) return block;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: block,
    );
  }
}

/// The skeleton for a list of cards, so a loading screen looks like the screen
/// it is becoming.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    this.itemCount = 3,
    this.itemHeight = 132,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppDimens.screenPadding,
    ),
    super.key,
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppDimens.md),
        itemBuilder: (context, index) => AppSkeleton(
          height: itemHeight,
          radius: AppDimens.radiusCard,
        ),
      ),
    );
  }
}
