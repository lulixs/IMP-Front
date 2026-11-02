import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';
import 'login_layout.dart';
import 'stub_employees.dart';

/// Screen 2 of sign-in: pick a name, then enter a 6-digit PIN on the keypad (D-014).
/// The 6th digit signs in. Nothing is checked yet, so any PIN works.
class EmployeeLoginPage extends StatefulWidget {
  /// Called with the chosen employee's name once all 6 digits are entered.
  final ValueChanged<String> onSignIn;

  const EmployeeLoginPage({super.key, required this.onSignIn});

  @override
  State<EmployeeLoginPage> createState() => _EmployeeLoginPageState();
}

class _EmployeeLoginPageState extends State<EmployeeLoginPage> {
  static const _pinLength = 6;

  String _name = stubEmployees.first;
  String _pin = '';

  void _press(String key) {
    setState(() {
      if (key == _Keypad.delete) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < _pinLength) {
        _pin += key;
      }
    });
    if (_pin.length == _pinLength) widget.onSignIn(_name);
  }

  @override
  Widget build(BuildContext context) {
    return LoginLayout(
      title: 'Employee sign-in',
      subtitle: 'Choose your name, then enter your 6-digit PIN.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Name'),
          DropdownButtonFormField<String>(
            initialValue: _name,
            items: [
              for (final name in stubEmployees) DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (name) => setState(() {
              _name = name!;
              _pin = '';
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
          _Keypad(onPress: _press),
          const SizedBox(height: 20),
          SecondaryButton('Back', onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

/// Digits 1 to 9, then 0 and delete on the bottom row.
class _Keypad extends StatelessWidget {
  static const delete = 'delete';
  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', delete];
  static const _size = 76.0;
  static const _gap = 30.0;

  final ValueChanged<String> onPress;

  const _Keypad({required this.onPress});

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }

  Widget _key(String key) {
    final isDelete = key == delete;
    return Material(
      color: isDelete ? AppColors.panel : AppColors.card,
      shape: CircleBorder(side: BorderSide(color: isDelete ? AppColors.barBorder : AppColors.ink2, width: 1.5)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onPress(key),
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
