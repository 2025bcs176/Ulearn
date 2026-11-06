import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peerpass/core/constants/app_dimens.dart';
import 'package:peerpass/core/theme/app_palette.dart';
import 'package:peerpass/core/widgets/app_button.dart';
import 'package:peerpass/features/matching/presentation/providers/matching_providers.dart';

/// What a student wrote when asking for help.
typedef RequestDraft = ({String topic, String? description});

/// The form that turns a tapped tutor into a request a tutor can answer.
///
/// Two fields, because the API takes two and the second one is the difference
/// between a request and a course subscription. `topic` is the specific question
/// -- "eigenvalues", not "MAT 221" -- because a tutor deciding whether to accept
/// needs the first; `description` is optional detail and is not shown again
/// anywhere, so it stays optional rather than becoming a second required box.
///
/// Returns null when the student backs out. A null answer and an empty one mean
/// different things -- "not now" against "they sent a request with no topic" --
/// and collapsing them would create the second request out of a cancelled sheet.
Future<RequestDraft?> showRequestTopicSheet(
  BuildContext context, {
  required String courseUnitId,
  String? initialTopic,
}) {
  return showModalBottomSheet<RequestDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      // A cap rather than the screen width. This app is mobile-first and a
      // bottom sheet on a tablet would otherwise stretch two text fields across
      // a desk, which is a form nobody can read comfortably.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _RequestTopicForm(
          courseUnitId: courseUnitId,
          initialTopic: initialTopic,
        ),
      ),
    ),
  );
}

/// The bounds the API holds a topic to, mirrored so the form can say them.
///
/// Stated in the form rather than left to a 422 for three reasons: the student is
/// told the limit before typing rather than after, the box does not accept a
/// value it will refuse, and the submit button can be disabled rather than enabled
/// and then wrong. These are the API's bounds and not this client's rules -- the
/// API still enforces them, and this only stops the round trip.
const int minTopicLength = 3;
const int maxTopicLength = 200;
const int maxDescriptionLength = 2000;

class _RequestTopicForm extends ConsumerStatefulWidget {
  const _RequestTopicForm({required this.courseUnitId, this.initialTopic});

  /// The unit whose suggestions are offered. The API scopes them to the caller's
  /// faculty, so this is a public id the screen already holds.
  final String courseUnitId;

  /// What the student typed on the home composer, if they came from there.
  ///
  /// Prefilled rather than locked: the composer is a quick way in, and the
  /// student may still want to sharpen the question once they know who they are
  /// asking.
  final String? initialTopic;

  @override
  ConsumerState<_RequestTopicForm> createState() => _RequestTopicFormState();
}

class _RequestTopicFormState extends ConsumerState<_RequestTopicForm> {
  late final TextEditingController _topic = TextEditingController(
    text: widget.initialTopic,
  );
  final TextEditingController _description = TextEditingController();

  /// What is wrong with the topic right now, or null.
  ///
  /// Null rather than a string that is empty-when-fine, so the field error cannot
  /// be rendered by accident on a pristine form.
  String? _topicError;

  @override
  void dispose() {
    _topic.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Whether the form has enough to send.
  bool get _canSubmit {
    final topic = _topic.text.trim();
    return topic.length >= minTopicLength &&
        topic.length <= maxTopicLength &&
        _topicError == null;
  }

  /// Uses a suggestion as the topic.
  ///
  /// Replaces what is in the field rather than appending: a suggestion is an
  /// alternative to typing, and "how do I find eigenvalues, Eigenvalues" is not
  /// a better question than either half of it. The student can still edit the
  /// result before sending.
  void _useSuggestion(String label) {
    _topic.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
    setState(() => _topicError = null);
  }

  void _submit() {
    final topic = _topic.text.trim();
    final error = _validateTopic(topic);
    if (error != null) {
      setState(() => _topicError = error);
      return;
    }
    final description = _description.text.trim();
    Navigator.of(context).pop((
      topic: topic,
      description: description.isEmpty ? null : description,
    ));
  }

  /// The reason a topic cannot be sent, or null when it can.
  String? _validateTopic(String topic) {
    if (topic.isEmpty) return 'Say what you need help with.';
    if (topic.length < minTopicLength) {
      return 'That is too short to be a question.';
    }
    if (topic.length > maxTopicLength) {
      return 'Keep this under $maxTopicLength characters.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Padding(
      // The view inset is what keeps the keyboard from covering the submit
      // button. Without it the student is typing into a form whose only way out
      // is behind the keyboard, which on a phone is a dead end rather than an
      // inconvenience.
      padding: EdgeInsets.only(
        left: AppDimens.screenPadding,
        right: AppDimens.screenPadding,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimens.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // `stretch` so the fields fill the sheet rather than hugging their
          // labels, and so the button row is given the sheet's width to lay out
          // against instead of picking one.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What do you need help with?',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppDimens.xs),
            Text(
              'Your chosen tutor sees this when they decide whether to take '
              'your request. Be specific about the part you are stuck on.',
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppDimens.lg),
            TextField(
              controller: _topic,
              autofocus: true,
              textInputAction: TextInputAction.next,
              maxLength: maxTopicLength,
              decoration: InputDecoration(
                labelText: 'Topic',
                hintText: 'Eigenvalues and diagonalisation',
                errorText: _topicError,
              ),
              onChanged: (_) {
                // Every keystroke rebuilds. `_canSubmit` is read when the button
                // is built, so a form that only rebuilds to clear an error leaves
                // a student who typed something valid looking at a button that
                // stays disabled -- the form refusing to send what it just
                // accepted. The error clears here too, because a form that keeps
                // saying "too short" while the field visibly has more in it is
                // telling the student their edit did not register.
                setState(() => _topicError = null);
              },
            ),
            const SizedBox(height: AppDimens.md),
            _Suggestions(
              courseUnitId: widget.courseUnitId,
              chosen: _topic.text.trim(),
              onPick: _useSuggestion,
            ),
            const SizedBox(height: AppDimens.md),
            TextField(
              controller: _description,
              maxLines: 3,
              maxLength: maxDescriptionLength,
              decoration: const InputDecoration(
                labelText: 'Anything else (optional)',
                hintText: 'Where you have got to, what you have tried',
              ),
            ),
            const SizedBox(height: AppDimens.lg),
            // Stacked, not a row: the primary action is the one within reach of
            // a thumb, and the cancel below it is the quiet way out rather than
            // a second equal choice.
            AppButton(
              // Disabled rather than enabled-and-wrong: the button says the
              // form is not ready yet, which is the truth, rather than
              // answering a tap with an error the student did not cause.
              label: 'Ask this tutor',
              onPressed: _canSubmit ? _submit : null,
            ),
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The unit's suggested questions, offered as chips under the topic field.
///
/// Below the field so the field does not move when the suggestions arrive: the
/// sheet opens with the keyboard up and the student already typing, and a form
/// that reflows under a thumb is how a tap lands on the wrong control. Loading
/// renders nothing for the same reason -- a spinner in this slot would push the
/// description and button down for a request that usually answers before the
/// student finishes their first word.
///
/// A failure is said and does not block: free text is the whole feature, and the
/// chips are an aid. It is not retried automatically, so the student gets a
/// small retry they can press rather than a query firing under the form.
class _Suggestions extends ConsumerWidget {
  const _Suggestions({
    required this.courseUnitId,
    required this.chosen,
    required this.onPick,
  });

  final String courseUnitId;

  /// What is currently in the topic field, so the matching chip reads as chosen.
  final String chosen;

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final topics = ref.watch(courseUnitTopicsProvider(courseUnitId));

    if (topics.hasError) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'Common questions could not be loaded. You can still write '
              'your own.',
              style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ),
          IconButton(
            tooltip: 'Retry suggestions',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(courseUnitTopicsProvider(courseUnitId)),
          ),
        ],
      );
    }

    final suggestions = topics.value;
    if (suggestions == null || suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Common questions in this unit',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppDimens.xxs),
        Text(
          'Tap one to use it as your topic, or write your own above.',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: AppDimens.sm),
        Wrap(
          spacing: AppDimens.sm,
          runSpacing: AppDimens.sm,
          children: [
            for (final topic in suggestions)
              ChoiceChip(
                label: Text(topic.label),
                selected: chosen == topic.label,
                onSelected: (_) => onPick(topic.label),
              ),
          ],
        ),
      ],
    );
  }
}
