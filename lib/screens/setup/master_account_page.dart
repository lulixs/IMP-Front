import 'package:flutter/material.dart';

import '../../validators.dart';
import '../../widgets/common.dart';
import 'setup_layout.dart';

/// Step 1 of first-time setup (wireframe 01c): create the store-wide Master account.
class MasterAccountPage extends StatefulWidget {
  /// Called with the email and password once every field is valid.
  final void Function(String email, String password) onNext;

  const MasterAccountPage({super.key, required this.onNext});

  @override
  State<MasterAccountPage> createState() => _MasterAccountPageState();
}

class _MasterAccountPageState extends State<MasterAccountPage> {
  static const _minPasswordLength = 8;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState!.validate()) {
      widget.onNext(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SetupLayout(
      step: 1,
      subtitle: 'Create the master account.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NoteBox(
              'Welcome to IMP! Please set up the store\'s master account below. '
              'The password below will be used for account authentication and privilege elevation.',
            ),
            const FieldLabel('Email'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'e.g. manager@example.org'),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Password'),
            TextFormField(
              controller: _password,
              obscureText: true,
              validator: (value) {
                final password = value ?? '';
                if (password.isEmpty) return 'Enter a password';
                if (password.length < _minPasswordLength) {
                  return 'Use at least $_minPasswordLength characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            const FieldLabel('Confirm password'),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              validator: (value) => value != _password.text ? 'Passwords do not match' : null,
              onFieldSubmitted: (_) => _next(),
            ),
            const SizedBox(height: 20),
            PrimaryButton('Next', onPressed: _next),
          ],
        ),
      ),
    );
  }
}
