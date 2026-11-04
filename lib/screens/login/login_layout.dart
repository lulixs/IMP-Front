import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';

/// The frame shared by the sign-in screens: logo, title, subtitle, and a white
/// card for the screen's form. Matches the setup screens without the step list.
class LoginLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const LoginLayout({super.key, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.panel,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            child: Column(
              children: [
                const Logo(),
                const SizedBox(height: 26),
                Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.ink2),
                ),
                const SizedBox(height: 26),
                Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
