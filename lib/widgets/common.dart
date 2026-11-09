import 'package:flutter/material.dart';

import '../theme.dart';

/// The IMP logo square at the top of the setup and sign-in screens.
class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text('IMP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
    );
  }
}

/// Bold label above a text field.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

/// Small gray italic note under a text field.
class Hint extends StatelessWidget {
  final String text;
  const Hint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.ink3),
      ),
    );
  }
}

/// Gray box with an explanation at the top of a form.
class NoteBox extends StatelessWidget {
  final String text;
  const NoteBox(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        border: Border.all(color: const Color(0xFFA9A9A9), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45)),
    );
  }
}

/// Bordered box with an error icon and a bold message, shown at the top of a form when
/// something goes wrong, like a wrong password or PIN.
class ErrorBox extends StatelessWidget {
  final String message;
  const ErrorBox(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

/// Black pill button, like "Next" on the setup screens. Full width unless [expand] is false.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  const PrimaryButton(this.label, {super.key, this.onPressed, this.expand = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 46,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Outlined pill button, like "Back" on the setup screens. Full width unless [expand] is false.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  const SecondaryButton(this.label, {super.key, this.onPressed, this.expand = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : null,
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.ink, width: 1.5),
          textStyle: const TextStyle(fontSize: 15),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Gray circle with the first letter of a name, shown next to an employee's name.
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE3E3E3),
        border: Border.all(color: const Color(0xFFB9B9B9)),
      ),
      child: Text(
        name.isEmpty ? '' : name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: const Color(0xFF7A7A7A)),
      ),
    );
  }
}

/// Popup that asks the user to confirm something, with Cancel and a black confirm button.
/// Returns true only if the confirm button was tapped. Cancel, tapping outside, and the
/// back button all return false.
Future<bool> showConfirmPopup(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x6B1E1E1E),
    builder: (context) => Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SecondaryButton('Cancel', expand: false, onPressed: () => Navigator.of(context).pop(false)),
                  const SizedBox(width: 10),
                  PrimaryButton(confirmLabel, expand: false, onPressed: () => Navigator.of(context).pop(true)),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
