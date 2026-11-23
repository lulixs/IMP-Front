import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../models/box.dart';
import '../../models/building.dart';
import '../../models/category.dart';
import '../../models/new_box.dart';
import '../../theme.dart';
import 'new_box_page.dart';

/// New Box connected to the server (IMP-Back docs/api/boxes.md).
///
/// Save box and Save and print label both send `POST /api/boxes`. When the server has made the box, this screen
/// closes with the new box's number as its result, and whoever opened it (BoxesScreen) opens the box with openBox.
/// Save and print label calls [onPrint] with the new box first. Cancel and Back close it with no result.
///
/// If the server says no (a date in the future, a category deleted while the form was open), the page shows the
/// server's sentence and keeps what the employee typed. A loading wheel covers the page while it waits.
class NewBoxScreen extends StatefulWidget {
  final ApiClient api;
  final List<Category> categories;
  final List<Building> buildings;

  /// Called with the saved box when Save and print label is tapped, before the new box opens.
  /// Labels are built in week 13. Plug printing in where this screen is opened.
  final void Function(Box box) onPrint;

  const NewBoxScreen({
    super.key,
    required this.api,
    required this.categories,
    required this.buildings,
    required this.onPrint,
  });

  @override
  State<NewBoxScreen> createState() => _NewBoxScreenState();
}

class _NewBoxScreenState extends State<NewBoxScreen> {
  static const _screen = 'New box';

  // True while waiting for the server, which shows the loading wheel
  bool _waiting = false;

  /// Sends the form. Throws an ApiException when it fails, so NewBoxPage shows the sentence and keeps the form.
  Future<void> _create(NewBox request, {required bool print}) async {
    setState(() => _waiting = true);
    final Box box;
    try {
      final json = await widget.api.post('/api/boxes', screen: _screen, body: request.toJson());
      try {
        box = Box.fromJson(json as Map<String, dynamic>);
      } catch (e) {
        // The server answered 201, so the box exists. Saying so keeps the employee from adding it a second time.
        debugPrint('New box reply could not be read: $e');
        throw ApiException(
          'The box was saved, but its details could not be read. Check the Boxes list before saving again.',
          screen: _screen,
        );
      }
    } finally {
      if (mounted) setState(() => _waiting = false);
    }

    if (print) widget.onPrint(box);
    if (mounted) Navigator.of(context).pop(box.id);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NewBoxPage(
          categories: widget.categories,
          buildings: widget.buildings,
          onSave: (box) => _create(box, print: false),
          onSaveAndPrint: (box) => _create(box, print: true),
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
