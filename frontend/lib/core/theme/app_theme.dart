import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_colors.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/theme/app_typography.dart';

/// The app's light and dark [ThemeData].
///
/// Built from the Campus Energy tokens rather than from a generated seed. A
/// seed scheme derives hundreds of tones that the app will never use and cannot
/// name; the product has ten colours that each mean something, and the theme's
/// job is to hand those to Material rather than to invent neighbours for them.
///
/// Both themes carry an [AppPalette] extension. Components read semantic colour
/// from it, so the light/dark decision is made once here instead of in every
/// card that needs a tinted background.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final palette = isLight ? AppPalette.light : AppPalette.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      primaryContainer: palette.indigoTint,
      onPrimaryContainer: palette.onIndigoTint,
      secondary: palette.amber,
      onSecondary: AppColors.ink,
      secondaryContainer: palette.amberTint,
      onSecondaryContainer: palette.onAmberTint,
      tertiary: palette.mint,
      onTertiary: isLight ? AppColors.white : AppColors.ink,
      tertiaryContainer: palette.mintTint,
      onTertiaryContainer: palette.onMintTint,
      error: isLight ? AppColors.coralInk : AppColors.coralOnDark,
      onError: isLight ? AppColors.white : AppColors.ink,
      errorContainer: palette.coralTint,
      onErrorContainer: palette.onCoralTint,
      surface: palette.background,
      onSurface: palette.ink,
      onSurfaceVariant: palette.muted,
      surfaceContainerLowest: palette.card,
      surfaceContainerLow: palette.card,
      surfaceContainer: palette.card,
      surfaceContainerHigh: palette.soft,
      surfaceContainerHighest: palette.soft,
      outline: palette.muted,
      outlineVariant: palette.line,
      shadow: palette.shadow,
      scrim: Colors.black,
      inverseSurface: isLight ? AppColors.ink : AppColors.cream,
      onInverseSurface: isLight ? AppColors.cream : AppColors.ink,
      inversePrimary: isLight ? AppColors.indigoOnDark : AppColors.indigo,
    );

    final textTheme = AppTypography.textTheme.apply(
      bodyColor: palette.ink,
      displayColor: palette.ink,
    );

    final buttonTextStyle = textTheme.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: AppTypography.bodyFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: palette.background,
      // Density is a deliberate low-bandwidth choice: the interface is text and
      // icons, so platform-dependent metrics would only add assets.
      visualDensity: VisualDensity.standard,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppDimens.screenPadding,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: IconThemeData(color: palette.ink, size: 24),
        actionsIconTheme: IconThemeData(color: palette.ink, size: 24),
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),

      cardTheme: CardThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: AppDimens.hairline,
        space: AppDimens.hairline,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.soft,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.lg,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.muted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: palette.muted),
        // A per-field error message needs room, so the label is allowed to sit
        // above the field rather than floating inside a fixed box.
        helperMaxLines: 2,
        errorMaxLines: 3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          borderSide: BorderSide(color: palette.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          disabledBackgroundColor: palette.soft,
          disabledForegroundColor: palette.muted,
          elevation: 0,
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
          textStyle: buttonTextStyle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          minimumSize: const Size.fromHeight(AppDimens.buttonHeightSmall),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.xl),
          textStyle: buttonTextStyle,
          side: BorderSide(color: palette.primary, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          minimumSize: const Size(AppDimens.tapTarget, AppDimens.tapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
          textStyle: buttonTextStyle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.card,
        selectedColor: palette.primary,
        disabledColor: palette.soft,
        labelStyle: textTheme.labelLarge?.copyWith(color: palette.ink),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: palette.onPrimary,
        ),
        side: BorderSide(color: palette.line),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.sm,
        ),
        showCheckmark: false,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.card,
        showDragHandle: true,
        dragHandleColor: palette.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusSheet),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: AppDimens.navBarHeight,
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: palette.indigoTint,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? palette.primary : palette.muted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.primary : palette.muted,
          );
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? AppColors.ink : palette.soft,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isLight ? AppColors.cream : palette.ink,
        ),
        actionTextColor: palette.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusButton),
        ),
        insetPadding: const EdgeInsets.all(AppDimens.lg),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.soft,
        circularTrackColor: palette.soft,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        iconColor: palette.muted,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: palette.muted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.primary,
        selectionColor: palette.indigoTint,
        selectionHandleColor: palette.primary,
      ),
    );
  }
}
