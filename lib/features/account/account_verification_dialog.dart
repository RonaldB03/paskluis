import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';

class AccountVerificationDialog extends StatefulWidget {
  final String instructions;
  final Future<void> Function(String code) verify;
  const AccountVerificationDialog({
    super.key,
    required this.instructions,
    required this.verify,
  });
  @override
  State<AccountVerificationDialog> createState() =>
      _AccountVerificationDialogState();
}

class _AccountVerificationDialogState extends State<AccountVerificationDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.verify(_code.text);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() => _error = L10n.current.accountVerificationFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(L10n.current.accountVerificationTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.instructions),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: L10n.current.accountVerificationCode,
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(L10n.current.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(L10n.current.accountVerify),
        ),
      ],
    ),
  );
}

