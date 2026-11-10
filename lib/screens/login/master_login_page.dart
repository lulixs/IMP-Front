import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../validators.dart';
import '../../widgets/common.dart';
import 'login_layout.dart';

/// The three places the Master sign-in screen is used. The layout changes a little for each.
enum MasterLoginMode {
  /// Turning on Master mode from the sidebar (D-094).
  masterToggle,

  /// Signing in again on a tablet that is already set up (D-013). An employee signs in next.
  signIn,

  /// Adding a new tablet. Also asks for the tablet's name, above the email.
  newTablet,
}

/// The Master account signs in here. The page only checks the fields are filled in.
/// Whether the email and password are right is up to [onSignIn].
class MasterLoginPage extends StatefulWidget {
  /// Which of the three places this screen is being used. Decides the subtitle and whether
  /// the tablet name field is shown.
  final MasterLoginMode mode;

  /// Called once the fields are valid, with the email (trimmed), the password, and the tablet
  /// name (trimmed). The tablet name is null unless [mode] is [MasterLoginMode.newTablet].
  /// Returns null if sign-in worked, or the message to show in an error box if it failed.
  final String? Function(String email, String password, String? tabletName) onSignIn;

  const MasterLoginPage({super.key, required this.mode, required this.onSignIn});

  @override
  State<MasterLoginPage> createState() => _MasterLoginPageState();
}

class _MasterLoginPageState extends State<MasterLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _tabletName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Message from the last failed sign-in, or null if there is nothing to show.
  String? _error;

  bool get _askTabletName => widget.mode == MasterLoginMode.newTablet;

  String get _subtitle => switch (widget.mode) {
        MasterLoginMode.masterToggle => 'Sign in with the Master account to unlock Master-only pages.',
        MasterLoginMode.signIn => 'Sign in with the master account to use IMP on this tablet.',
        MasterLoginMode.newTablet =>
          'Sign in with the Master account to add this tablet. The first tablet is set up during first-time setup.',
      };

  @override
  void dispose() {
    _tabletName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    if (!_formKey.currentState!.validate()) return;
    final tabletName = _askTabletName ? _tabletName.text.trim() : null;
    final error = widget.onSignIn(_email.text.trim(), _password.text, tabletName);
    if (mounted) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    return LoginLayout(
      title: 'Sign in',
      subtitle: _subtitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ErrorBox(_error!),
            // Same field as step 2 of first-time setup (TabletNamePage).
            if (_askTabletName) ...[
              const FieldLabel('Tablet name'),
              TextFormField(
                controller: _tabletName,
                autofocus: true,
                inputFormatters: [LengthLimitingTextInputFormatter(maxTabletNameLength)],
                decoration: const InputDecoration(hintText: 'e.g. Processing tablet'),
                validator: validateTabletName,
              ),
              const SizedBox(height: 14),
            ],
            const FieldLabel('Email'),
            TextFormField(
              controller: _email,
              autofocus: !_askTabletName,
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
