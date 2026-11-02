import 'package:flutter/material.dart';

import '../../validators.dart';
import '../../widgets/common.dart';
import 'login_layout.dart';

/// Screen 1 of sign-in: the Master account signs the tablet in (D-013).
/// Nothing is checked against the server yet, so any valid email and any password work.
class MasterLoginPage extends StatefulWidget {
  final VoidCallback onSignIn;

  const MasterLoginPage({super.key, required this.onSignIn});

  @override
  State<MasterLoginPage> createState() => _MasterLoginPageState();
}

class _MasterLoginPageState extends State<MasterLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    if (_formKey.currentState!.validate()) {
      widget.onSignIn();
    }
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
