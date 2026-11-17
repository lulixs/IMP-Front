import 'package:flutter/material.dart';

import 'main.dart';

/// Debug entry point for working on the dashboard. It runs the normal start-up, which opens the dashboard as the
/// saved employee when this tablet (or browser) has both tokens saved, so sign in once and every later run lands
/// on the dashboard. With no saved tokens it opens setup or sign-in first.
/// Run with: flutter run -d chrome -t lib/dev_dashboard.dart
void main() => runApp(const ImpApp());
