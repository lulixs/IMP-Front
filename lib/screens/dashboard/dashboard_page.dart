import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../models/dashboard.dart';
import '../../session.dart';
import '../../theme.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/common.dart';
import 'dashboard_view.dart';

// Dashboard Screen
class DashboardPage extends StatefulWidget {
  final ApiClient? api;

  /// The current sign-in, passed on to the AppShell.
  final Session session;

  const DashboardPage({super.key, this.api, required this.session});

  // Creates State object that holds the page's changing widgets
  @override
  State<DashboardPage> createState() {
    return _DashboardPageState();
  }
}

// Holds ApiClient and current request for DashbaordData
class _DashboardPageState extends State<DashboardPage> {
  late final ApiClient
  _activeApi; // api that is being used throughout the whole process
  late Future<DashboardData> _dashboard;

  // Neither ApiClient nor _dashboard has an intial value, it promises it will when init runs
  // ApiClient created and _dashboard awaits the data
  @override
  void initState() {
    super.initState();
    _activeApi = widget.api ?? ApiClient();
    _dashboard = _load();
  }

  // Fetches the DashbaordData using GET method for Map
  // Uses fromJson to tranlate Map into DashboardData
  Future<DashboardData> _load() async {
    final json = await _activeApi.get('/api/dashboard', screen: 'Dashboard');
    return DashboardData.fromJson(json as Map<String, dynamic>);
  }

  // Starts a new request and redraws the page
  void _retry() {
    setState(() {
      _dashboard = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      session: widget.session,
      active: Section.dashboard,
      child: FutureBuilder<DashboardData>(
        future: _dashboard,
        builder: (context, snapshot) {
          // Waiting for the server (spinning circle)
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          // Something went wrong, prints error
          if (snapshot.hasError) {
            final error = snapshot.error;
            debugPrint('Dashboard load failed: $error');
            final message = error is ApiException
                ? error.message
                : 'The dashboard data could not be read.';
            return _LoadError(message: message, onRetry: _retry);
          }
          // data arrives, as promised (! promises snapshot.data)
          return DashboardView(data: snapshot.data!);
        },
      ),
    );
  }
}

// Shown when dashboard can't load: what went wrong and try again button
class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: AppColors.ink3,
              ),
              const SizedBox(height: 12),
              const Text(
                "Couldn't load the dashboard",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppColors.ink2),
              ),
              // Try again button, when pressed runs _retry
              const SizedBox(height: 18),
              PrimaryButton('Try again', onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
