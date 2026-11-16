import 'package:flutter/material.dart';

import 'api/api_exception.dart';
import 'api/auth_api.dart';
import 'api/token_store.dart';
import 'theme.dart';
import 'widgets/common.dart';

// The app's navigator, reachable without a context. MaterialApp in main.dart is given this key, so code
// outside any widget (start-up, ApiClient's onTokenProblem) can change screens with navigatorKey.currentState
final navigatorKey = GlobalKey<NavigatorState>();

enum Start { firstSetup, tabletSetup, employeeSignIn, dashboard }

// Picks the start screen from what the tablet has saved
Future<Start> decideStart(TokenStore tokens, AuthApi auth) async {
  final device = await tokens.readDeviceToken();

  // new tablet: the server knows whether another tablet already set up the store
  if (device == null) {
    if (await auth.isSetUp()) {
      return Start.tabletSetup;
    } else {
      return Start.firstSetup;
    }
  }

  final session = await tokens.readSessionToken();
  if (session == null) {
    return Start.employeeSignIn;
  } else {
    return Start.dashboard;
  }
}

// Opens page as a fresh start: everything behind it is removed, so Back can't return to an earlier screen
void openFresh(Widget page) {
  navigatorKey.currentState?.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (_) => false);
}

// The first screen the app shows: a spinner while decide runs, then onDecided opens the real start screen.
// Only a new tablet asks the server, so if it can't be reached this shows why, with a Try again button
class StartPage extends StatefulWidget {
  final Future<Start> Function() decide;
  final void Function(Start start) onDecided;

  const StartPage({super.key, required this.decide, required this.onDecided});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  // The reason start-up failed, or null while it is still running
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final start = await widget.decide();
      if (mounted) widget.onDecided(start);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      // A reply in an unexpected shape. Without this the spinner would never stop.
      if (mounted) setState(() => _error = 'The server sent back something IMP could not read.');
    }
  }

  void _retry() {
    setState(() => _error = null);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.ink3),
                      const SizedBox(height: 12),
                      const Text("Couldn't start IMP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.ink2),
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton('Try again', onPressed: _retry),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
