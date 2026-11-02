import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peerpass/app/router.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/error/failures.dart';
import 'package:peerpass/core/models/course_unit.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_button.dart';
import 'package:peerpass/core/widgets/app_card.dart';
import 'package:peerpass/features/matching/presentation/providers/matching_providers.dart';

/// The one thing home is for: saying what you are stuck on.
///
/// This is deliberately not a search form. The student picks the course from
/// their own faculty's catalogue -- a chip, not a catalogue to scan -- types the
/// question in their own words, and presses one button. The question is carried
/// to the results screen and prefilled into the request sheet, so nothing they
/// typed is thrown away between screens.
///
/// Lives in the matching feature, not in home, because it reads the course
/// catalogue and navigates into matching. Home receives it as a widget, the same
/// way it receives the tutor rail, and decides only where it sits.
class AskComposer extends ConsumerStatefulWidget {
  const AskComposer({super.key});

  /// How many course chips fit before the rest are behind "More".
  static const int visibleUnitCount = 4;

  @override
  ConsumerState<AskComposer> createState() => _AskComposerState();
}

class _AskComposerState extends ConsumerState<AskComposer> {
  final TextEditingController _topic = TextEditingController();

  /// The unit the student tapped, or null while they have not chosen one.
  ///
  /// The effective selection falls back to the first unit in the catalogue, so
  /// a student with a normal timetable can type and press without a detour. The
  /// fallback is not written into state: it is a display default, and writing it
  /// would make the first unit look chosen on a catalogue that later changes.
  String? _selectedUnitId;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  void _submit(String? unitId) {
    if (unitId == null) {
      // No catalogue yet. The picker can still load one and explain itself,
      // which is a better answer than a disabled button with no reason.
      unawaited(context.push(AppRoutes.matching));
      return;
    }
    unawaited(
      context.push(
        AppRoutes.matchResultsPath(unitId, topic: _topic.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final catalogue = ref.watch(courseUnitOptionsProvider);
    final units = catalogue.value ?? const [];
    final effectiveUnitId = _selectedUnitId ??
        (units.isEmpty ? null : units.first.publicId);
    CourseUnit? selectedUnit;
    for (final unit in units) {
      if (unit.publicId == effectiveUnitId) {
        selectedUnit = unit;
        break;
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ASK FOR HELP',
            style: theme.textTheme.labelMedium?.copyWith(
              color: palette.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppDimens.sm),
          Text(
            "What's giving you trouble today?",
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: AppDimens.lg),
          if (catalogue.hasError)
            _CatalogueFailure(
              failure: failureFor(catalogue.error!),
              onRetry: () => ref.invalidate(courseUnitOptionsProvider),
            )
          else if (catalogue.isLoading)
            const _ChipPlaceholders()
          else
            _UnitChips(
              units: units,
              selectedUnitId: effectiveUnitId,
              onSelected: (unitId) => setState(() => _selectedUnitId = unitId),
            ),
          if (selectedUnit != null) ...[
            const SizedBox(height: AppDimens.xs),
            Text(
              selectedUnit.name,
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
          const SizedBox(height: AppDimens.lg),
          TextField(
            controller: _topic,
            maxLength: 200,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(effectiveUnitId),
            decoration: InputDecoration(
              hintText: "e.g. eigenvalues before Friday's CAT",
              prefixIcon: Icon(
                Icons.search_rounded,
                color: palette.muted,
                size: 20,
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: AppDimens.md),
          AppButton(
            label: 'Find me a tutor',
            variant: AppButtonVariant.accent,
            onPressed: () => _submit(effectiveUnitId),
          ),
        ],
      ),
    );
  }
}

/// The course chips, or the honest state of a faculty with no catalogue yet.
class _UnitChips extends StatelessWidget {
  const _UnitChips({
    required this.units,
    required this.selectedUnitId,
    required this.onSelected,
  });

  final List<CourseUnit> units;
  final String? selectedUnitId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      // A faculty that has published nothing is a normal state, and the student
      // must not be locked out of asking. The CTA still opens the picker, which
      // says the same thing in more words.
      return Text(
        'Your faculty has not published course units yet. You can still browse '
        'and ask.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final visible = units.take(AskComposer.visibleUnitCount).toList();
    final hiddenCount = units.length - visible.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final unit in visible) ...[
            _CourseChip(
              label: unit.code,
              selected: unit.publicId == selectedUnitId,
              onTap: () => onSelected(unit.publicId),
            ),
            const SizedBox(width: AppDimens.sm),
          ],
          if (hiddenCount > 0)
            _CourseChip(
              label: '+$hiddenCount more',
              selected: false,
              onTap: () => context.push(AppRoutes.matching),
            ),
        ],
      ),
    );
  }
}

class _CourseChip extends StatelessWidget {
  const _CourseChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: palette.card,
      selectedColor: palette.primary,
      side: BorderSide(color: selected ? palette.primary : palette.line),
      shape: const StadiumBorder(),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected ? palette.onPrimary : palette.ink,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.md,
        vertical: AppDimens.sm,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Quiet placeholders while the catalogue arrives.
class _ChipPlaceholders extends StatelessWidget {
  const _ChipPlaceholders();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _ChipPlaceholder(width: 96),
        SizedBox(width: AppDimens.sm),
        _ChipPlaceholder(width: 120),
      ],
    );
  }
}

class _ChipPlaceholder extends StatelessWidget {
  const _ChipPlaceholder({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      width: width,
      height: 36,
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
    );
  }
}

/// The catalogue failed. One line and a retry, not a full failure screen: the
/// rest of home is still true and still useful.
class _CatalogueFailure extends StatelessWidget {
  const _CatalogueFailure({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Row(
      children: [
        Icon(Icons.wifi_off_rounded, size: 18, color: palette.muted),
        const SizedBox(width: AppDimens.sm),
        Expanded(
          child: Text(
            "Couldn't load your courses.",
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
