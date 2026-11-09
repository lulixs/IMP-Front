import 'package:flutter/material.dart';

import '../../validators.dart';
import '../../widgets/common.dart';
import 'login_layout.dart';

/// Screen 1 of sign-in: the Master account signs the tablet in (D-013).
/// The page only checks the fields are filled in. Whether the email and password are right is up to [onSignIn].
class MasterLoginPage extends StatefulWidget {
  /// Called with the entered email (trimmed) and password once the fields are valid.
  /// Returns null if sign-in worked, or the message to show in an error box if it failed.
  final String? Function(String email, String password) onSignIn;

  const MasterLoginPage({super.key, required this.onSignIn});

  @override
  State<MasterLoginPage> createState() => _MasterLoginPageState();
}

class _MasterLoginPageState extends State<MasterLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Message from the last failed sign-in, or null if there is nothing to show.
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    if (!_formKey.currentState!.validate()) return;
    final error = widget.onSignIn(_email.text.trim(), _password.text);
    if (mounted) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    return LoginLayout(
      title: 'Sign in',
      subtitle: 'Sign in with the master account to use IMP on this tablet.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ErrorBox(_error!),
            const FieldLabel('Email'),
            TextFormField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'e.g. manager@example.org'),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Password'),
            TextFormField(
              controller: _password,
              obscureText: true,
              validator: (value) => (value ?? '').isEmpty ? 'Enter a password' : null,
              onFieldSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: 20),
            PrimaryButton('Sign in', onPressed: _signIn),
          ],
        ),
      ),
    );
  }
}
