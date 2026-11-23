import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../models/box.dart';
import '../../models/box_query.dart';
import '../../models/building.dart';
import '../../models/category.dart';
import '../../session.dart';
import '../../widgets/app_shell.dart';
import 'open_box.dart';
import 'boxes_page.dart';
import 'new_box_screen.dart';

/// The Boxes list connected to the server (IMP-Back docs/api/boxes.md).
///
/// - On start it loads the category and building lists, then `GET /api/boxes`.
/// - Each time BoxesPage reports a new search or filter, it sends `GET /api/boxes` again. A slow answer to an
///   older search is thrown away, so it can't replace the rows for the newest one.
/// - A row opens the Box page with openBox. The + button opens New Box, and the new box's page opens when it is saved.
///   The list reloads when the Box page closes, since the box may have changed.
class BoxesScreen extends StatefulWidget {
  final ApiClient api;

  /// The current sign-in, passed on to the AppShell.
  final Session session;

  /// True when the Search button opened this page: the search field is ready to type in.
  final bool focusSearch;

  const BoxesScreen({super.key, required this.api, required this.session, this.focusSearch = false});

  @override
  State<BoxesScreen> createState() => _BoxesScreenState();
}

class _BoxesScreenState extends State<BoxesScreen> {
  static const _screen = 'Boxes';

  List<Category> _categories = const [];
  List<Building> _buildings = const [];
  bool _listsLoaded = false;

  List<Box>? _boxes;
  bool _loading = true;
  String? _error;

  // The search and filters of the latest request
  BoxQuery _query = const BoxQuery();

  // Counts requests, so only the newest answer is used
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Loads the two lists, then the boxes. The lists go first and on their own, so a sign-in problem is caught once.
  Future<void> _start() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lists = await Future.wait([
        widget.api.get('/api/categories', screen: _screen),
        widget.api.get('/api/buildings', screen: _screen),
      ]);
      final categories = [
        for (final c in (lists[0] as Map<String, dynamic>)['categories'] as List) Category.fromJson(c),
      ];
      final buildings = [
        for (final b in (lists[1] as Map<String, dynamic>)['buildings'] as List) Building.fromJson(b),
      ];
      if (!mounted || id != _requestId) return;
      setState(() {
        _categories = categories;
        _buildings = buildings;
        _listsLoaded = true;
      });
    } on ApiException catch (e) {
      _failed(id, e.code == null ? e.message : null);
      return;
    } catch (e) {
      debugPrint('Boxes lists failed: $e');
      _failed(id, 'The boxes could not be read.');
      return;
    }
    await _loadBoxes(_query);
  }

  /// Sends `GET /api/boxes` for [query]. Only the newest request's answer is used.
  Future<void> _loadBoxes(BoxQuery query) async {
    final id = ++_requestId;
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    try {
      final json = await widget.api.get(query.path, screen: _screen) as Map<String, dynamic>;
      final boxes = [for (final b in json['boxes'] as List) Box.fromJson(b as Map<String, dynamic>)];
      if (!mounted || id != _requestId) return;
      setState(() {
        _boxes = boxes;
        _loading = false;
      });
    } on ApiException catch (e) {
      _failed(id, e.code == null ? e.message : null);
    } catch (e) {
      // A reply in a shape the models can't read. Without this the loading bar would never stop.
      debugPrint('Boxes load failed: $e');
      _failed(id, 'The boxes could not be read.');
    }
  }

  // A set code means ApiClient already opened another screen (D-168), so there is no sentence to show
  void _failed(int id, String? message) {
    if (!mounted || id != _requestId) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  // "Try again": start over if the lists never loaded, otherwise just ask for the boxes again
  void _retry() {
    if (_listsLoaded) {
      _loadBoxes(_query);
    } else {
      _start();
    }
  }

  Future<void> _open(Box box) async {
    await openBox(context, box.id);
    if (mounted) _loadBoxes(_query);
  }

  Future<void> _newBox() async {
    if (!_listsLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The category and building lists are not loaded yet.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final newId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => NewBoxScreen(
          api: widget.api,
          categories: _categories,
          buildings: _buildings,
          // Labels are built in week 13. Plug printing in here, where New Box is opened.
          onPrint: (box) => messenger.showSnackBar(
            const SnackBar(content: Text('Printing labels is not built yet.')),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (newId == null) return; // Cancelled
    await openBox(context, newId);
    if (mounted) _loadBoxes(_query);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      session: widget.session,
      active: Section.boxes,
      child: BoxesPage(
      focusSearch: widget.focusSearch,
      categories: _categories,
      boxes: _boxes,
      loading: _loading,
      error: _error,
      onQueryChanged: _loadBoxes,
      onOpenBox: _open,
      onNewBox: _newBox,
      onRetry: _retry,
      ),
    );
  }
}
