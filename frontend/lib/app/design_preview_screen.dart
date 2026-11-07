import 'package:flutter/material.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_colors.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_avatar.dart';
import 'package:peerpass/core/widgets/app_button.dart';
import 'package:peerpass/core/widgets/app_card.dart';
import 'package:peerpass/core/widgets/app_pill.dart';
import 'package:peerpass/core/widgets/app_skeleton.dart';
import 'package:peerpass/core/widgets/empty_view.dart';
import 'package:peerpass/core/widgets/section_header.dart';

/// A debug-only catalogue of the design system.
///
/// Exists so that a colour, a type size, or a component's states can be checked
/// on a real handset without navigating the product to find one. It is not
/// registered in release builds: a route that only developers can use still
/// ships its strings and its layout otherwise.
class DesignPreviewScreen extends StatelessWidget {
  const DesignPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Design preview')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
          vertical: AppDimens.lg,
        ),
        children: [
          const SectionHeader(
            title: 'Colour',
            subtitle: 'Brand, surfaces, and the tints built from them.',
          ),
          const SizedBox(height: AppDimens.md),
          const _SwatchRow(
            swatches: [
              ('Indigo', AppColors.indigo, AppColors.white),
              ('Amber', AppColors.amber, AppColors.ink),
              ('Coral', AppColors.coral, AppColors.white),
              ('Mint', AppColors.mint, AppColors.white),
            ],
          ),
          const SizedBox(height: AppDimens.sm),
          const _SwatchRow(
            swatches: [
              ('Ink', AppColors.ink, AppColors.white),
              ('Muted', AppColors.muted, AppColors.white),
              ('Line', AppColors.line, AppColors.ink),
              ('Soft', AppColors.soft, AppColors.ink),
            ],
          ),
          const SizedBox(height: AppDimens.xxl),
          const SectionHeader(title: 'Type'),
          const SizedBox(height: AppDimens.md),
          Text('Display 30', style: theme.textTheme.displayMedium),
          Text('Headline 24', style: theme.textTheme.headlineLarge),
          Text('Section 17', style: theme.textTheme.headlineSmall),
          Text('Title 15', style: theme.textTheme.titleMedium),
          Text('Body 14 — the sentence a student actually reads.',
              style: theme.textTheme.bodyMedium),
          Text('Small 12 — evidence and metadata.',
              style: theme.textTheme.bodySmall),
          Text('LABEL 11', style: theme.textTheme.labelMedium),
          const SizedBox(height: AppDimens.xxl),
          const SectionHeader(title: 'Buttons'),
          const SizedBox(height: AppDimens.md),
          AppButton(label: 'Find me a tutor', onPressed: () {}),
          const SizedBox(height: AppDimens.sm),
          AppButton(
            label: 'I am here',
            variant: AppButtonVariant.accent,
            onPressed: () {},
          ),
          const SizedBox(height: AppDimens.sm),
          AppButton(
            label: 'Join call',
            variant: AppButtonVariant.outline,
            onPressed: () {},
          ),
          const SizedBox(height: AppDimens.sm),
          AppButton(
            label: 'Not this one',
            variant: AppButtonVariant.ghost,
            onPressed: () {},
          ),
          const SizedBox(height: AppDimens.sm),
          AppButton(
            label: 'Sending',
            isLoading: true,
            onPressed: () {},
          ),
          const SizedBox(height: AppDimens.sm),
          const AppButton(label: 'Disabled', onPressed: null),
          const SizedBox(height: AppDimens.xxl),
          const SectionHeader(title: 'Pills and avatars'),
          const SizedBox(height: AppDimens.md),
          const Wrap(
            spacing: AppDimens.sm,
            runSpacing: AppDimens.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppPill('Verified', tone: AppPillTone.success),
              AppPill('Rising tutor', tone: AppPillTone.warning),
              AppPill('Live', tone: AppPillTone.danger),
              AppPill('MAT 221', tone: AppPillTone.info),
              AppPill('Year 3'),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          const Wrap(
            spacing: AppDimens.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppAvatar(name: 'Sarah K.', isVerified: true),
              AppAvatar(name: 'Brian O.', size: 56),
              AppAvatar(name: 'Amina N.', size: 32),
            ],
          ),
          const SizedBox(height: AppDimens.xxl),
          const SectionHeader(title: 'Cards and states'),
          const SizedBox(height: AppDimens.md),
          AppCard(
            onTap: () {},
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('A tappable card', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppDimens.xs),
                Text(
                  'White surface, 24pt radius, one soft shadow.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.md),
          AppCard(
            tint: AppPalette.of(context).coralTint,
            child: Text(
              'A tinted card carries a state, not decoration.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppDimens.md),
          const AppSkeleton(height: 72),
          const SizedBox(height: AppDimens.md),
          const AppSkeleton.line(width: 220),
          const SizedBox(height: AppDimens.xxl),
          const EmptyView(
            title: 'No sessions yet',
            message: 'Ask for help and your first session will appear here.',
            icon: Icons.event_available_outlined,
          ),
        ],
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({required this.swatches});

  final List<(String, Color, Color)> swatches;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (label, background, foreground) in swatches)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppDimens.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusMd,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
