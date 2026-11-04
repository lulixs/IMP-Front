import 'package:flutter/material.dart';

import 'main.dart';

/// Debug entry point that skips first-time setup and opens the dashboard.
/// Run with: flutter run -d chrome -t lib/dev_dashboard.dart
void main() => runApp(const ImpApp(start: StartScreen.dashboard));
