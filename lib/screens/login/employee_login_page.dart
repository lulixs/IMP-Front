import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';
import 'login_layout.dart';
import 'stub_employees.dart';

/// Screen 2 of sign-in: pick a name, then enter a 6-digit PIN on the keypad (D-014).
/// The 6th digit signs in. Whether the PIN is right is up to [onSignIn].
class EmployeeLoginPage extends StatefulWidget {
  /// Called with the chosen employee's name and the PIN once all 6 digits are entered.
  /// Completes with null if sign-in worked, or the message to show in an error box if it failed.
  /// After a failure the PIN is cleared so it can be entered again. It will ask the server,
  /// so the keypad, the name, and Back are disabled until it completes.
  final Future<String?> Function(String name, String pin) onSignIn;

  /// Whether to show Back, which returns to the Master sign-in screen. Switch user hides it,
  /// since the tablet stays signed in to the Master account and there is nothing to go back to.
  final bool showBack;

  const EmployeeLoginPage({super.key, required this.onSignIn, this.showBack = true});

  @override
  State<EmployeeLoginPage> createState() => _EmployeeLoginPageState();
}

class _EmployeeLoginPageState extends State<EmployeeLoginPage> {
  static const _pinLength = 6;

  String _name = stubEmployees.first;
  String _pin = '';

  /// Message from the last failed sign-in, or null if there is nothing to show.
  String? _error;

  /// True while waiting for [EmployeeLoginPage.onSignIn], so the PIN can't be sent again.
  bool _busy = false;

  Future<void> _press(String key) async {
    if (_busy) return;
    setState(() {
      if (key == _Keypad.delete) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < _pinLength) {
        _pin += key;
      }
    });
    if (_pin.length != _pinLength) return;

    setState(() => _busy = true);
    String? error;
    try {
      error = await widget.onSignIn(_name, _pin);
    } finally {
      // Runs even if onSignIn throws, so the keypad never stays disabled.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
          if (error != null) _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // While waiting, the back button can't leave either, for the same reason Back is disabled.
    return PopScope(
      canPop: !_busy,
      child: LoginLayout(
        title: 'Employee sign-in',
        subtitle: 'Choose your name, then enter your 6-digit PIN.',
        child: _form(context),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ErrorBox(_error!),
        const FieldLabel('Name'),
        DropdownButtonFormField<String>(
          initialValue: _name,
          items: [
            for (final name in stubEmployees) DropdownMenuItem(value: name, child: Text(name)),
          ],
          // Null disables the dropdown while waiting.
          onChanged: _busy
              ? null
              : (name) => setState(() {
                    _name = name!;
                    _pin = '';
                    _error = null;
                  }),
        ),
        const SizedBox(height: 14),
        const FieldLabel('PIN'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _pinLength; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? AppColors.ink : null,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Keypad(onPress: _busy ? null : _press),
        if (widget.showBack) ...[
          const SizedBox(height: 20),
          SecondaryButton('Back', onPressed: _busy ? null : () => Navigator.of(context).pop()),
        ],
      ],
    );
  }
}

/// Digits 1 to 9, then 0 and delete on the bottom row.
class _Keypad extends StatelessWidget {
  static const delete = 'delete';
  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', delete];
  static const _size = 76.0;
  static const _gap = 30.0;

  /// Called with the key that was tapped. Null disables every key and fades the keypad.
  final ValueChanged<String>? onPress;

  const _Keypad({required this.onPress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: onPress == null ? 0.45 : 1,
        child: SizedBox(
          width: _size * 3 + _gap * 2,
          child: Wrap(
            spacing: _gap,
            runSpacing: 14,
            children: [
              for (final key in _keys)
                if (key.isEmpty) const SizedBox(width: _size, height: _size) else _key(key),
            ],
          ),
        ),
      ),
    );
  }

  Widget _key(String key) {
    final press = onPress;
    final isDelete = key == delete;
    return Material(
      color: isDelete ? AppColors.panel : AppColors.card,
      shape: CircleBorder(side: BorderSide(color: isDelete ? AppColors.barBorder : AppColors.ink2, width: 1.5)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: press == null ? null : () => press(key),
        child: SizedBox(
          width: _size,
          height: _size,
          child: Center(
            child: isDelete
                ? const Icon(Icons.backspace_outlined, size: 28, color: AppColors.ink, semanticLabel: 'Delete')
                : Text(key, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
