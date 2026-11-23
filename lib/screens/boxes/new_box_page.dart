import 'package:flutter/material.dart';

import '../../api/api_exception.dart';
import '../../models/box.dart';
import '../../models/building.dart';
import '../../models/category.dart';
import '../../models/new_box.dart';
import '../../theme.dart';
import '../../widgets/box_helpers.dart';
import '../../widgets/common.dart';

/// New Box (wireframe 07): the form for a box that is going into storage.
///
/// Required fields are checked before anything is sent. Tapping a save button with a field missing shows the
/// reason under that field and sends nothing. The box ID and QR code are made by the server when it saves.
class NewBoxPage extends StatefulWidget {
  final List<Category> categories;
  final List<Building> buildings;

  /// Called with the form's values when Save box is tapped. Connect sends them to the server and opens the new box.
  /// If it throws an ApiException, the page shows the message and keeps what the employee typed.
  final Future<void> Function(NewBox box) onSave;

  /// Called when Save and print label is tapped. Connect saves the box the same way, then prints its label
  /// (week 13 plugs printing in) and opens the new box.
  final Future<void> Function(NewBox box) onSaveAndPrint;

  const NewBoxPage({
    super.key,
    required this.categories,
    required this.buildings,
    required this.onSave,
    required this.onSaveAndPrint,
  });

  @override
  State<NewBoxPage> createState() => _NewBoxPageState();
}

class _NewBoxPageState extends State<NewBoxPage> {
  // The form's memory. Null means the employee hasn't chosen yet.
  int? _categoryId;
  int? _buildingId;
  int? _shelfLevel;
  Fullness? _fullness;

  // The day the box went into storage. Starts as today.
  late DateTime _since = _today();

  late final TextEditingController _sinceText = TextEditingController(text: formatDate(_since));
  final TextEditingController _shelfLetter = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  // True once a save button was tapped, which is when missing fields start showing their reason
  bool _submitted = false;

  // True while waiting for the server
  bool _saving = false;

  // Today's date with no time, in the tablet's time zone
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _sinceText.dispose();
    _shelfLetter.dispose();
    _notes.dispose();
    super.dispose();
  }

  // Opens the calendar. Later dates than today can't be picked.
  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _since.isAfter(today) ? today : _since,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _since = DateTime(picked.year, picked.month, picked.day);
      _sinceText.text = formatDate(_since);
    });
  }

  // Checks the required fields, then sends the form through [send]
  Future<void> _submit(Future<void> Function(NewBox box) send) async {
    if (_saving) return;
    final category = _categoryId;
    final building = _buildingId;
    final level = _shelfLevel;
    final fullness = _fullness;
    final letter = _shelfLetter.text;

    setState(() => _submitted = true);
    if (category == null || building == null || level == null || fullness == null || letter.isEmpty) return;

    final notes = _notes.text.trim();
    final request = NewBox(
      categoryId: category,
      buildingId: building,
      shelfLetter: letter,
      shelfLevel: level,
      fullness: fullness,
      notes: notes.isEmpty ? null : notes,
      rackedSince: _since,
    );

    setState(() => _saving = true);
    try {
      await send(request);
    } on ApiException catch (e) {
      // A set code means ApiClient already opened another screen (D-168)
      if (e.code == null) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _form(),
                ),
              ),
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 18),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          IconButton.outlined(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saving ? null : () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New box', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'The box ID and QR code are created when you save',
                style: TextStyle(fontSize: 14, color: AppColors.ink2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category, with the link to add one. The link does nothing yet: week 13 wires it.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            FieldLabel('Category *'),
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                '+ New category',
                style: TextStyle(fontSize: 13, color: AppColors.ink3, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: _categoryId,
          hint: const Text('Choose a category'),
          decoration: InputDecoration(errorText: _submitted && _categoryId == null ? 'Choose a category.' : null),
          items: [
            for (final c in widget.categories)
              DropdownMenuItem(value: c.id, child: Text(c.symbol == null ? c.name : '${c.symbol} ${c.name}')),
          ],
          onChanged: (id) => setState(() => _categoryId = id),
        ),
        const SizedBox(height: 18),

        const FieldLabel('In storage since *'),
        TextField(
          controller: _sinceText,
          readOnly: true,
          onTap: _pickDate,
          decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 20)),
        ),
        const Hint('Defaults to today. Set an earlier date for a box that was already in storage.'),
        const SizedBox(height: 18),

        const FieldLabel('Building *'),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: _buildingId,
          hint: const Text('Choose a building'),
          decoration: InputDecoration(errorText: _submitted && _buildingId == null ? 'Choose a building.' : null),
          items: [
            for (final b in widget.buildings) DropdownMenuItem(value: b.id, child: Text(b.name)),
          ],
          onChanged: (id) => setState(() => _buildingId = id),
        ),
        const SizedBox(height: 18),

        // Shelf letter and shelf level side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Shelf letter *'),
                  TextField(
                    controller: _shelfLetter,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: shelfLetterRules,
                    decoration: InputDecoration(
                      errorText: _submitted && _shelfLetter.text.isEmpty ? 'Enter 1 to 3 letters' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const Hint('One to three uppercase letters, such as A, AB, or ABC'),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Shelf level *'),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    emptySelectionAllowed: true,
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1')),
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 3, label: Text('3')),
                    ],
                    selected: {?_shelfLevel},
                    onSelectionChanged: (picked) => setState(() => _shelfLevel = picked.isEmpty ? null : picked.first),
                  ),
                  _choiceError(_submitted && _shelfLevel == null, 'Choose a level.'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        const FieldLabel('Fullness *'),
        SegmentedButton<Fullness>(
          showSelectedIcon: false,
          emptySelectionAllowed: true,
          segments: const [
            ButtonSegment(value: Fullness.empty, label: Text('Empty')),
            ButtonSegment(value: Fullness.half, label: Text('Half')),
            ButtonSegment(value: Fullness.full, label: Text('Full')),
          ],
          selected: {?_fullness},
          onSelectionChanged: (picked) => setState(() => _fullness = picked.isEmpty ? null : picked.first),
        ),
        _choiceError(_submitted && _fullness == null, 'Choose how full the box is.'),
        const SizedBox(height: 18),

        const FieldLabel('Notes (optional)'),
        TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Anything staff should know about this box…'),
        ),
        const SizedBox(height: 18),

        const NoteBox('New boxes start as Racked. After saving, the box page opens, where every field can be changed.'),
      ],
    );
  }

  // The reason under a button row that nothing is chosen in, in the same red as the text fields' reasons
  Widget _choiceError(bool show, String message) {
    if (!show) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(message, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
    );
  }

  // Cancel, Save box, and Save and print label
  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: const BoxDecoration(
        color: AppColors.soft,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: SecondaryButton('Cancel', onPressed: _saving ? null : () => Navigator.maybePop(context)),
          ),
          const Spacer(),
          SizedBox(
            width: 170,
            child: SecondaryButton(
              _saving ? 'Saving...' : 'Save box',
              onPressed: _saving ? null : () => _submit(widget.onSave),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 240,
            height: 46,
            child: FilledButton.icon(
              onPressed: _saving ? null : () => _submit(widget.onSaveAndPrint),
              icon: const Icon(Icons.print),
              label: const Text('Save and print label'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
