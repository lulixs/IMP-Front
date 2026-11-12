import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../validators.dart';
import '../../widgets/common.dart';
import 'login_layout.dart';

/// The three places the Master sign-in screen is used. The layout changes a little for each.
enum MasterLoginMode {
  /// Turning Master mode on from the sidebar (D-094). Has a Cancel button.
  masterToggle,

  /// Signing in again on a tablet that is already set up (D-013). An employee signs in next.
  signIn,

  /// Adding a new tablet. Also asks for the tablet's name, above the email.
  newTablet,
}

/// The Master account signs in here. The page only checks the fields are filled in.
/// Whether the email and password are right is up to [onSignIn].
class MasterLoginPage extends StatefulWidget {
  /// Which of the three places this screen is being used. Decides the title, subtitle, and
  /// button label, and whether the tablet name field and Cancel button are shown.
  final MasterLoginMode mode;

  /// Called once the fields are valid, with the email (trimmed), the password, and the tablet
  /// name (trimmed). The tablet name is null unless [mode] is [MasterLoginMode.newTablet].
  /// Completes with null if sign-in worked, or the message to show in an error box if it failed.
  /// It will ask the server, so the Sign In and Cancel buttons are disabled until it completes.
  final Future<String?> Function(String email, String password, String? tabletName) onSignIn;

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

  /// True while waiting for [MasterLoginPage.onSignIn], so it can't be sent again.
  bool _busy = false;

  bool get _askTabletName => widget.mode == MasterLoginMode.newTablet;

  String get _title => switch (widget.mode) {
        MasterLoginMode.masterToggle => 'Activate Master Mode',
        MasterLoginMode.signIn => 'Sign In',
        MasterLoginMode.newTablet => 'Tablet Setup',
      };

  String get _subtitle => switch (widget.mode) {
        MasterLoginMode.masterToggle => 'Sign in with the Master account to unlock Master-only pages.',
        MasterLoginMode.signIn => 'Sign in with the Master account to use IMP on this tablet.',
        MasterLoginMode.newTablet => 'Sign in with the Master account to add this tablet.',
      };

  String get _buttonLabel => _askTabletName ? 'Set up Tablet' : 'Sign In';

  @override
  void dispose() {
    _tabletName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final tabletName = _askTabletName ? _tabletName.text.trim() : null;
    String? error;
    try {
      error = await widget.onSignIn(_email.text.trim(), _password.text, tabletName);
    } finally {
      // Runs even if onSignIn throws, so the buttons never stay disabled.
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
    // While waiting, the back button can't leave either, for the same reason Cancel is disabled.
    return PopScope(
      canPop: !_busy,
      child: LoginLayout(
        title: _title,
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
              PrimaryButton(_buttonLabel, onPressed: _busy ? null : _signIn),
              // Turning Master mode on can be abandoned. The other two modes have nowhere to go back to.
              if (widget.mode == MasterLoginMode.masterToggle) ...[
                const SizedBox(height: 12),
                SecondaryButton('Cancel', onPressed: _busy ? null : () => Navigator.of(context).pop()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
