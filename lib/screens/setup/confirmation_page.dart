import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';
import 'first_setup_data.dart';
import 'setup_layout.dart';

/// Step 4 of first-time setup: shows everything entered in steps 1 to 3 and asks
/// for confirmation. The password and PIN are hidden until their eye is tapped.
class ConfirmationPage extends StatefulWidget {
  final FirstSetupData data;
  final Future<String?> Function() onConfirm;

  const ConfirmationPage({super.key, required this.data, required this.onConfirm});

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  String? _error;
  bool _busy = false;
  
  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);

    String? error;
    try {
      error = await widget.onConfirm();
    } finally {
      // Runs even if onConfirm throws, so the buttons never stay disabled.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SetupLayout(
      step: 4,
      subtitle: 'Confirm your details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NoteBox('Review and confirm setup below.'),
          if (_error != null) ErrorBox(_error!),
          const _SectionTitle('Master account'),
          _SummaryRow(label: 'Email', value: widget.data.masterEmail),
          _SummaryRow(label: 'Password', value: widget.data.masterPassword, secret: true),
          const Divider(height: 24, color: AppColors.line),
          const _SectionTitle('Tablet'),
          _SummaryRow(label: 'Tablet name', value: widget.data.tabletName),
          const Divider(height: 24, color: AppColors.line),
          const _SectionTitle('First employee'),
          _SummaryRow(label: 'Employee name', value: widget.data.employeeName),
          _SummaryRow(label: 'PIN', value: widget.data.employeePin, secret: true),
          const SizedBox(height: 20),
          SetupButtons(nextLabel: 'Confirm', onNext: _busy ? null : _confirm),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

/// One label and value. A secret value shows as dots with an eye button to reveal it.
class _SummaryRow extends StatefulWidget {
  final String label;
  final String value;
  final bool secret;

  const _SummaryRow({required this.label, required this.value, this.secret = false});

  @override
  State<_SummaryRow> createState() => _SummaryRowState();
}

class _SummaryRowState extends State<_SummaryRow> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final hidden = widget.secret && !_shown;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(widget.label, style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
          ),
          Expanded(
            child: Text(hidden ? '•' * widget.value.length : widget.value, style: const TextStyle(fontSize: 15)),
          ),
          if (widget.secret)
            IconButton(
              tooltip: _shown ? 'Hide' : 'Show',
              visualDensity: VisualDensity.compact,
              icon: Icon(_shown ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              onPressed: () => setState(() => _shown = !_shown),
            ),
        ],
      ),
    );
  }
}
