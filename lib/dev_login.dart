import 'package:flutter/material.dart';

import 'main.dart';

/// Debug entry point that skips first-time setup and opens the Master sign-in (signing a tablet back in).
/// Run with: flutter run -d chrome -t lib/dev_login.dart
void main() => runApp(const ImpApp(start: StartScreen.login));
