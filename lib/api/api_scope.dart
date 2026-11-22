import 'package:flutter/widgets.dart';

import 'api_client.dart';

/// Makes the app's one ApiClient reachable from any screen with ApiScope.of(context), so a shared helper like
/// openBox can call the server without every page passing the client along. ImpApp puts one above every screen.
/// Tests put one above the page they show, with a fake server.
class ApiScope extends InheritedWidget {
  final ApiClient api;

  const ApiScope({super.key, required this.api, required super.child});

  /// The ApiClient above this context. Safe to call from a button's callback, not only from build.
  static ApiClient of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ApiScope>();
    assert(scope != null, 'No ApiScope above this screen. ImpApp adds one, and tests wrap the page in one.');
    return scope!.api;
  }

  @override
  bool updateShouldNotify(ApiScope oldWidget) => api != oldWidget.api;
}
