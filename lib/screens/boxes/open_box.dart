import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../api/api_scope.dart';
import '../../models/box.dart';
import '../../models/building.dart';
import '../../models/category.dart';
import '../../theme.dart';
import 'box_screen.dart';

/// How openBox went. Callers that care (the scanner) switch on it. Others can ignore it.
sealed class OpenBoxResult {
  const OpenBoxResult();
}

/// The Box page opened, and the employee has since left it. A list can reload now, since the box may have changed.
class BoxOpened extends OpenBoxResult {
  const BoxOpened();
}

/// The box was soft-deleted, so the Box page didn't open. The box has deletedAt and deletedBy for wireframe 05c.
class BoxWasDeleted extends OpenBoxResult {
  final Box box;
  const BoxWasDeleted(this.box);
}

/// No box has this number (404). The scanner shows wireframe 05b.
class BoxNotFound extends OpenBoxResult {
  final String message;
  const BoxNotFound(this.message);
}

/// The box couldn't be loaded, for example with no connection. message is the sentence to show, or null when
/// ApiClient already handled it (a sign-in problem that opened another screen), so nothing should be shown.
class BoxLoadFailed extends OpenBoxResult {
  final String? message;
  const BoxLoadFailed(this.message);
}

/// The one way to open a box, used by the Boxes list, the scanner, and New Box.
///
/// It shows a loading wheel over the current screen while it loads `GET /api/boxes/{id}`, then the category and
/// building lists for the dropdowns, and opens the Box page connected to the server. A box with `deletedAt` set
/// doesn't open the page (D-173).
///
/// The returned Future completes once the Box page has closed (BoxOpened), or straight away when the page
/// didn't open. When [showProblems] is true, a deleted box, a missing box, or a failed load shows its sentence
/// at the bottom of the screen. The scanner sets it to false and shows wireframes 05b and 05c itself.
///
/// [replace] swaps the calling screen for the Box page, so Back from the Box page skips it. The scanner uses it.
///
/// Needs an ApiScope above [context]. ImpApp adds one.
Future<OpenBoxResult> openBox(
  BuildContext context,
  int id, {
  bool replace = false,
  bool showProblems = true,
}) async {
  final api = ApiScope.of(context);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);

  // The loading wheel is a popup that can't be closed by tapping outside it or with the back button.
  // Keeping the route lets it be removed exactly, even if something else opened on top meanwhile.
  final wheel = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.overlay,
    builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
  );
  navigator.push(wheel);

  final Object loaded;
  try {
    loaded = await _load(api, id);
  } finally {
    // A sign-in problem opens another screen and removes everything, the wheel included
    if (wheel.isActive) navigator.removeRoute(wheel);
  }

  if (loaded is! _Loaded) {
    final problem = loaded as OpenBoxResult;
    if (showProblems) _show(messenger, problem);
    return problem;
  }

  // The screen that asked was closed while loading (for example by a sign-in problem), so there is nowhere to open
  if (!context.mounted) return const BoxLoadFailed(null);

  final _Loaded ready = loaded;
  final page = MaterialPageRoute<void>(
    builder: (_) => BoxScreen(
      api: api,
      box: ready.box,
      categories: ready.categories,
      buildings: ready.buildings,
      // Labels are built in week 13. Plug printing in here, where the Box page is opened.
      onPrint: () => messenger?.showSnackBar(const SnackBar(content: Text('Printing labels is not built yet.'))),
    ),
  );
  if (replace) {
    await navigator.pushReplacement(page);
  } else {
    await navigator.push(page);
  }
  return const BoxOpened();
}

/// Everything the Box page needs, once it has loaded.
class _Loaded {
  final Box box;
  final List<Category> categories;
  final List<Building> buildings;

  const _Loaded(this.box, this.categories, this.buildings);
}

/// Loads the box, then the two lists for its dropdowns. Returns a _Loaded, or the OpenBoxResult that explains why not.
Future<Object> _load(ApiClient api, int id) async {
  const screen = 'Box page';
  try {
    final box = Box.fromJson(await api.get('/api/boxes/$id', screen: screen) as Map<String, dynamic>);
    if (box.deletedAt != null) return BoxWasDeleted(box);

    // The box is first on its own, so a sign-in problem is caught once, not by three requests at the same time
    final lists = await Future.wait([
      api.get('/api/categories', screen: screen),
      api.get('/api/buildings', screen: screen),
    ]);
    final categories = [
      for (final c in (lists[0] as Map<String, dynamic>)['categories'] as List) Category.fromJson(c),
    ];
    final buildings = [
      for (final b in (lists[1] as Map<String, dynamic>)['buildings'] as List) Building.fromJson(b),
    ];
    return _Loaded(box, categories, buildings);
  } on ApiException catch (e) {
    if (e.code != null) return const BoxLoadFailed(null);
    if (e.statusCode == 404) return BoxNotFound(e.message);
    return BoxLoadFailed(e.message);
  } catch (e) {
    // A reply in a shape the models can't read. Without this the wheel would never close.
    debugPrint('Box $id load failed: $e');
    return const BoxLoadFailed('The box could not be read.');
  }
}

/// Shows why the Box page didn't open, at the bottom of the screen.
void _show(ScaffoldMessengerState? messenger, OpenBoxResult problem) {
  final message = switch (problem) {
    BoxWasDeleted(:final box) => 'Box #${box.id} was deleted.',
    BoxNotFound(:final message) => message,
    BoxLoadFailed(:final message) => message,
    BoxOpened() => null,
  };
  if (message != null) messenger?.showSnackBar(SnackBar(content: Text(message)));
}
