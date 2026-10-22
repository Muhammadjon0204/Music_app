import 'package:flutter/cupertino.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/domain/library/library_repository.dart';
import 'package:music_app/presentation/common/failure_text.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// One option of an action sheet.
class SheetAction<T> {
  const SheetAction(this.label, this.value, {this.destructive = false});

  final String label;
  final T value;
  final bool destructive;
}

/// Native iOS action sheet. Returns the chosen value, or null on cancel.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required List<SheetAction<T>> actions,
  String? title,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: title == null ? null : Text(title),
      actions: [
        for (final action in actions)
          CupertinoActionSheetAction(
            isDestructiveAction: action.destructive,
            onPressed: () => Navigator.of(sheetContext).pop(action.value),
            child: Text(action.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: const Text(AuraStrings.cancel),
      ),
    ),
  );
}

/// Asks before an irreversible action. True when confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AuraStrings.cancel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<void> showFailure(BuildContext context, AppFailure failure) {
  final (title, message) = failureText(failure);
  return showMessage(context, title: title, message: message);
}

Future<void> showMessage(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Asks for a playlist name. Returns the valid trimmed name, or null.
Future<String?> askPlaylistName(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
}) {
  return showCupertinoDialog<String>(
    context: context,
    builder: (_) => _PlaylistNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initial: initial,
    ),
  );
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initial,
  });

  final String title;
  final String confirmLabel;
  final String initial;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = PlaylistRules.validName(_controller.text);
    if (name == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              controller: _controller,
              autofocus: true,
              placeholder: AuraStrings.playlistName,
              maxLength: PlaylistRules.maxNameLength,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _submit(),
            ),
            if (_showError) ...[
              const SizedBox(height: 8),
              const Text(AuraStrings.playlistNameInvalid),
            ],
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AuraStrings.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
