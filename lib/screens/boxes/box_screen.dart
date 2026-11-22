import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../models/box.dart';
import '../../models/box_changes.dart';
import '../../models/building.dart';
import '../../models/category.dart';
import '../../theme.dart';
import 'box_page.dart';

/// The Box page connected to the server (IMP-Back docs/api/boxes.md). openBox opens it. It holds the latest copy
/// of the box, and hands BoxPage what Save changes and Delete box do:
///
/// - Save changes sends `PUT /api/boxes/{id}` with every field and the `lastUpdatedAt` the page loaded (D-174).
///   On 409 it reloads the box, so the page shows what the other tablet saved, and the page shows the server's
///   sentence. On 404 it goes back to the screen that opened the box.
/// - Delete box sends `DELETE /api/boxes/{id}`, then goes back.
///
/// A loading wheel covers the page while it waits for the server.
class BoxScreen extends StatefulWidget {
  final ApiClient api;
  final Box box;
  final List<Category> categories;
  final List<Building> buildings;
  final VoidCallback onPrint;

  const BoxScreen({
    super.key,
    required this.api,
    required this.box,
    required this.categories,
    required this.buildings,
    required this.onPrint,
  });

  @override
  State<BoxScreen> createState() => _BoxScreenState();
}

class _BoxScreenState extends State<BoxScreen> {
  static const _screen = 'Box page';

  // The box as the server last sent it. BoxPage starts its form over whenever this changes.
  late Box _box = widget.box;

  // True while waiting for the server, which shows the loading wheel
  bool _waiting = false;

  String get _path => '/api/boxes/${_box.id}';

  /// Save changes. Throws the ApiException again after handling it, so BoxPage shows the server's sentence
  /// and doesn't count the save as done.
  Future<void> _save(BoxChanges changes) async {
    setState(() => _waiting = true);
    try {
      final json = await widget.api.put(_path, screen: _screen, body: changes.toJson());
      if (mounted) setState(() => _box = Box.fromJson(json as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.code == null && e.statusCode == 409) {
        // Someone else saved this box since it loaded. Show what they saved, so the employee can make the change again
        await _reload();
      } else if (e.code == null && e.statusCode == 404) {
        // The box was deleted, or never existed
        _leave();
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _waiting = false);
    }
  }

  /// Delete box, after BoxPage's popup. Throws the ApiException again so BoxPage shows the sentence.
  Future<void> _delete() async {
    setState(() => _waiting = true);
    try {
      await widget.api.delete(_path, screen: _screen);
      _leave();
    } on ApiException catch (e) {
      // Another tablet deleted it first: it is gone either way
      if (e.code == null && e.statusCode == 404) _leave();
      rethrow;
    } finally {
      if (mounted) setState(() => _waiting = false);
    }
  }

  /// Loads the box again after a 409. If that fails, the page keeps the copy it has, and the next save gets
  /// 409 again. If the box was deleted meanwhile, the page closes.
  Future<void> _reload() async {
    try {
      final fresh = Box.fromJson(await widget.api.get(_path, screen: _screen) as Map<String, dynamic>);
      if (!mounted) return;
      if (fresh.deletedAt != null) {
        _leave();
      } else {
        setState(() => _box = fresh);
      }
    } on ApiException catch (e) {
      if (e.code == null && e.statusCode == 404) _leave();
    }
  }

  /// Goes back to the screen that opened the box. Navigator.pop doesn't ask about unsaved changes, which is right
  /// here: the box is gone or the change was refused.
  void _leave() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BoxPage(
          box: _box,
          categories: widget.categories,
          buildings: widget.buildings,
          onSave: _save,
          onDelete: _delete,
          onPrint: widget.onPrint,
        ),
        // The loading wheel, which also stops taps until the server answers
        if (_waiting) ...[
          const ModalBarrier(dismissible: false, color: AppColors.overlay),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}
