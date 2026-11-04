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

/// Full-width black pill button, like "Next" on the setup screens.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PrimaryButton(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
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

/// Full-width outlined pill button, like "Back" on the setup screens.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const SecondaryButton(this.label, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
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
