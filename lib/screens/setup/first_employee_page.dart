import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common.dart';
import 'setup_layout.dart';

/// Step 3 of first-time setup (wireframe 01e): create the first employee, who is
/// signed in when setup is done. Setup cannot be finished without one (D-133).
class FirstEmployeePage extends StatefulWidget {
  /// Called with the trimmed name and the PIN once every field is valid.
  final void Function(String name, String pin) onNext;

  const FirstEmployeePage({super.key, required this.onNext});

  @override
  State<FirstEmployeePage> createState() => _FirstEmployeePageState();
}

class _FirstEmployeePageState extends State<FirstEmployeePage> {
  /// Matches EMPLOYEE_ACCOUNT.name, VARCHAR(100) in the ERD.
  static const _maxNameLength = 100;

  /// Employees sign in with a 6-digit PIN (D-014).
  static const _pinLength = 6;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState!.validate()) {
      widget.onNext(_name.text.trim(), _pin.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinFormatters = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(_pinLength),
    ];

    return SetupLayout(
      step: 3,
      subtitle: 'Create an employee.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NoteBox(
              'Create an employee-specific account to complete setup. '
              'Employees will log in with a personal PIN to manage IMP.'
            ),
            const FieldLabel('Employee name'),
            TextFormField(
              controller: _name,
              autofocus: true,
              inputFormatters: [LengthLimitingTextInputFormatter(_maxNameLength)],
              decoration: const InputDecoration(hintText: 'e.g. John D, djohn, John, etc.'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('6-digit PIN'),
                      TextFormField(
                        controller: _pin,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: pinFormatters,
                        validator: (value) =>
                            (value ?? '').length != _pinLength ? 'Enter $_pinLength digits' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FieldLabel('Confirm PIN'),
                      TextFormField(
                        controller: _confirm,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: pinFormatters,
                        validator: (value) => value != _pin.text ? 'PINs do not match' : null,
                        onFieldSubmitted: (_) => _next(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SetupButtons(onNext: _next),
          ],
        ),
      ),
    );
  }
}
