import 'dart:convert';

import 'package:flutter/material.dart';
import 'dashboard_view.dart';
import '../../models/dashboard.dart';
import '../../widgets/app_shell.dart';
import 'sample_dashboard.dart';



/// The dashboard screen. For now it shows the sample from sample_dashboard.dart.
/// Edwin's Card 4 replaces the sample with the response from GET /api/dashboard.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DashboardData sample = DashboardData.fromJson(jsonDecode(sampleDashboardJson) as Map<String, dynamic>);

    return AppShell(
      active: Section.dashboard,
      child: DashboardView(data: sample, isSample: true),
    );
  }
}
