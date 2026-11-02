import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_colors.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/theme/app_theme.dart';
import 'package:peerpass/core/theme/app_typography.dart';

void main() {
  group('light theme', () {
    final theme = AppTheme.light;

    test('paints the Campus Energy surfaces', () {
      expect(theme.scaffoldBackgroundColor, AppColors.cream);
      expect(theme.colorScheme.surface, AppColors.cream);
      expect(theme.colorScheme.primary, AppColors.indigo);
      expect(theme.colorScheme.secondary, AppColors.amber);
    });

    test('carries the semantic palette as an extension', () {
      final palette = theme.extension<AppPalette>();

      expect(palette, AppPalette.light);
      expect(palette?.card, AppColors.white);
      expect(palette?.onMintTint, AppColors.mintInk);
    });

    test('uses Sora for headings and Inter for body copy', () {
      expect(theme.textTheme.headlineLarge?.fontFamily, 'Sora');
      expect(theme.textTheme.displayMedium?.fontFamily, 'Sora');
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.labelLarge?.fontFamily, 'Inter');
    });

    test('sets the variable-font weight axis, not only FontWeight', () {
      final style = theme.textTheme.headlineLarge;

      expect(style?.fontWeight, FontWeight.w800);
      expect(
        style?.fontVariations?.single.axis,
        'wght',
      );
      expect(style?.fontVariations?.single.value, 800);
    });

    test('gives the primary action the Campus Energy height and radius', () {
      final style = theme.filledButtonTheme.style;
      final shape = style?.shape?.resolve(<WidgetState>{});

      expect(
        style?.minimumSize?.resolve(<WidgetState>{}),
        const Size(double.infinity, AppDimens.buttonHeight),
      );
      expect(
        shape,
        isA<RoundedRectangleBorder>().having(
          (border) => border.borderRadius,
          'borderRadius',
          BorderRadius.circular(AppDimens.radiusButton),
        ),
      );
    });

    test('inputs sit on the soft surface with no resting border', () {
      final border = theme.inputDecorationTheme.border;

      expect(theme.inputDecorationTheme.fillColor, AppColors.soft);
      expect(
        border,
        isA<OutlineInputBorder>().having(
          (value) => value.borderSide,
          'borderSide',
          BorderSide.none,
        ),
      );
    });
  });

  group('dark theme', () {
    final theme = AppTheme.dark;

    test('does not paint a cream page in a dark room', () {
      expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(theme.colorScheme.surface, AppColors.darkBackground);
    });

    test('keeps the brand colours legible', () {
      expect(theme.colorScheme.primary, AppColors.indigoOnDark);
      expect(theme.extension<AppPalette>(), AppPalette.dark);
    });
  });

  group('typography', () {
    test('every style names a bundled family', () {
      final styles = [
        AppTypography.textTheme.displayLarge,
        AppTypography.textTheme.headlineLarge,
        AppTypography.textTheme.titleLarge,
        AppTypography.textTheme.bodyMedium,
        AppTypography.textTheme.labelSmall,
      ];

      for (final style in styles) {
        expect(
          style?.fontFamily,
          anyOf('Inter', 'Sora'),
          reason: '$style',
        );
      }
    });

    test('body copy is never smaller than 12pt', () {
      expect(AppTypography.textTheme.bodySmall!.fontSize, greaterThanOrEqualTo(12));
      expect(AppTypography.textTheme.bodyMedium!.fontSize, greaterThanOrEqualTo(12));
    });
  });
}
