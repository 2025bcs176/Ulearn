import 'package:flutter/material.dart';
import 'package:peerpass/core/constants/app_dimens.dart';

/// The shape of content that is about to arrive.
enum LoadingViewVariant { list, cards, detail }

/// Placeholder for a screen whose content has not arrived yet.
///
/// The placeholder follows the content shape instead of showing a spinner in the
/// middle of the page. This keeps the surrounding layout stable on slow or
/// metered connections and gives the student a useful cue about what is loading.
class LoadingView extends StatelessWidget {
  const LoadingView({
    this.message,
    this.variant = LoadingViewVariant.list,
    super.key,
  });

  final String? message;
  final LoadingViewVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Semantics(
        label: message ?? 'Loading',
        liveRegion: true,
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimens.xl),
          children: [
            ..._placeholders(),
            if (message case final text?) ...[
              const SizedBox(height: AppDimens.lg),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _placeholders() {
    return switch (variant) {
      LoadingViewVariant.list => [
        for (var index = 0; index < 3; index++) ...[
          const _SkeletonLine(widthFactor: 0.9, height: 56),
          if (index < 2) const SizedBox(height: AppDimens.md),
        ],
      ],
      LoadingViewVariant.cards => [
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            separatorBuilder: (_, _) => const SizedBox(width: AppDimens.md),
            itemBuilder: (_, _) =>
                const SizedBox(width: 200, child: _SkeletonCard()),
          ),
        ),
      ],
      LoadingViewVariant.detail => [
        const _SkeletonLine(widthFactor: 0.55, height: 28),
        const SizedBox(height: AppDimens.lg),
        const _SkeletonLine(widthFactor: 1, height: 96),
        const SizedBox(height: AppDimens.md),
        const _SkeletonLine(widthFactor: 0.8, height: 18),
        const SizedBox(height: AppDimens.sm),
        const _SkeletonLine(widthFactor: 0.65, height: 18),
      ],
    };
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppDimens.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonLine(widthFactor: 0.6, height: 18),
            SizedBox(height: AppDimens.md),
            _SkeletonLine(widthFactor: 0.85, height: 14),
            SizedBox(height: AppDimens.sm),
            _SkeletonLine(widthFactor: 0.7, height: 14),
          ],
        ),
      ),
    );
  }
}
