import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_exception.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

import '../../models/box.dart';
import '../../models/box_changes.dart';
import '../../models/building.dart';
import '../../models/category.dart';

// Box Screen
class BoxPage extends StatefulWidget {
  final Box box;
  final List<Category> categories;
  final List<Building> buildings;

  /// Called with the form's values when Save changes is tapped. Connect sends them to the server.
  /// If it throws an ApiException, the page shows the message and keeps the employee's edits.
  final Future<void> Function(BoxChanges changes) onSave;

  /// Called after the employee confirms Delete box. Connect deletes the box and leaves the page.
  final Future<void> Function() onDelete;

  /// Called when Print label is tapped. Labels are built in week 13, and plugged in where openBox opens this page.
  final VoidCallback onPrint;

  const BoxPage({
    super.key,
    required this.box,
    required this.categories,
    required this.buildings,
    required this.onSave,
    required this.onDelete,
    required this.onPrint,
  });

  @override
  State<BoxPage> createState() {
    return _BoxPageState();
  }
}

class _BoxPageState extends State<BoxPage> {
  // The form's memory: what each field shows right now. They start as the box's values,
  // and change as the employee edits. Nothing is sent anywhere until Save (bullet 4).
  late int _buildingId;
  late int _categoryId;
  late int _shelfLevel;
  late Fullness _fullness;
  late bool _isRacked;
  late final TextEditingController _shelfLetter;
  late final TextEditingController _notes;

  // resets storage timer on rack reset
  bool _resetRackedSince = false;

  // true while waiting for save button
  bool _saving = false;

  // True once the employee chose to leave, so the unsaved changes popup doesn't stop them
  bool _leaving = false;

  // latest values become loaded or saved
  late BoxChanges _baseline;

  @override
  void initState() {
    super.initState();
    _shelfLetter = TextEditingController();
    _notes = TextEditingController();
    _loadFrom(widget.box);
  }

  // When Connect hands the page a new box (after a save, or a reload), start the form over from it.
  @override
  void didUpdateWidget(BoxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.box != oldWidget.box) {
      _loadFrom(widget.box);
    }
  }

  // Copies a box's values into the form, and remembers them as the starting point.
  void _loadFrom(Box box) {
    _buildingId = box.building.id;
    _categoryId = box.category.id;
    _shelfLevel = box.shelfLevel;
    _fullness = box.fullness;
    _isRacked = box.isRacked;
    _shelfLetter.text = box.shelfLetter;
    _notes.text = box.notes ?? '';
    _resetRackedSince = false;
    _baseline = _current();
  }

  // The form's values right now, in the shape onSave takes. Blank notes become null.
  BoxChanges _current() {
    final notes = _notes.text.trim();
    return BoxChanges(
      categoryId: _categoryId,
      buildingId: _buildingId,
      shelfLetter: _shelfLetter.text,
      shelfLevel: _shelfLevel,
      fullness: _fullness,
      notes: notes.isEmpty ? null : notes,
      isRacked: _isRacked,
      resetRackedSince: _resetRackedSince,
      lastUpdatedAt: widget.box.lastUpdatedAt,
    );
  }

  // Did the employee change anything since the box was loaded or saved?
  bool get _hasChanges {
    final now = _current();
    final was = _baseline;
    return now.categoryId != was.categoryId ||
        now.buildingId != was.buildingId ||
        now.shelfLetter != was.shelfLetter ||
        now.shelfLevel != was.shelfLevel ||
        now.fullness != was.fullness ||
        now.notes != was.notes ||
        now.isRacked != was.isRacked;
  }

  // Save changes is black only when something changed, the shelf letter isn't blank, and no save is running.
  bool get _canSave => _hasChanges && _shelfLetter.text.isNotEmpty && !_saving;

  // Sends the form through onSave. Returns true if it worked.
  Future<bool> _save() async {
    if (!_canSave) return false;
    final changes = _current();
    setState(() => _saving = true);
    try {
      await widget.onSave(changes);
      if (!mounted) return true;
      setState(() {
        _baseline = changes;
        _resetRackedSince = false;
      });
      return true;
    } on ApiException catch (e) {
      // A set code means ApiClient already opened another screen (D-168)
      if (e.code == null) _showMessage(e.message);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Delete box: ask first (06e), then hand it to onDelete.
  Future<void> _delete() async {
    final confirmed = await showConfirmPopup(
      context,
      title: 'Delete Box #${widget.box.id}?',
      message: 'The box is hidden from search, the dashboard, and alerts. Only the Master account '
          'can restore it or delete it permanently from Deleted Items.',
      confirmLabel: 'Delete box',
    );
    if (!confirmed) return;
    try {
      await widget.onDelete();
    } on ApiException catch (e) {
      if (e.code == null) _showMessage(e.message);
    }
  }

  // Unrack box: only changes the form. Save changes sends it.
  void _unrack() {
    setState(() {
      _isRacked = false;
      _resetRackedSince = false;
    });
  }

  // Re-rack box: where is it going (06c), then reset the storage timer or not (06f).
  // Cancel on the first popup changes nothing. Save changes sends the result.
  Future<void> _rerack() async {
    final location = await showDialog<_Location>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (context) => _RerackPopup(
        boxId: widget.box.id,
        buildings: widget.buildings,
        start: (buildingId: _buildingId, shelfLetter: _shelfLetter.text, shelfLevel: _shelfLevel),
      ),
    );
    if (location == null || !mounted) return;

    final reset = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlay,
      barrierDismissible: false,
      builder: (context) => _TimerPopup(box: widget.box),
    );
    if (reset == null || !mounted) return;

    setState(() {
      _buildingId = location.buildingId;
      _shelfLetter.text = location.shelfLetter;
      _shelfLevel = location.shelfLevel;
      _isRacked = true;
      _resetRackedSince = reset;
    });
  }

  // Leaving with unsaved changes (06d): Discard, Keep editing, or Save.
  Future<void> _confirmLeave() async {
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (context) => _PopupFrame(
        title: 'Save changes to Box #${widget.box.id}?',
        content: const [
          Text('You changed this box but did not save. If you leave now, the changes are lost.', style: _popupText),
        ],
        actions: [
          SecondaryButton('Discard', expand: false, onPressed: () => Navigator.of(context).pop(_LeaveChoice.discard)),
          SecondaryButton('Keep editing', expand: false, onPressed: () => Navigator.of(context).pop()),
          PrimaryButton('Save', expand: false, onPressed: () => Navigator.of(context).pop(_LeaveChoice.save)),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == _LeaveChoice.save && !await _save()) return;
    if (!mounted) return;
    setState(() => _leaving = true);
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Runs once, when the page closes: text controllers must be thrown away by hand.
  @override
  void dispose() {
    _shelfLetter.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope catches the back arrow and the tablet's back button while there are unsaved changes.
    return PopScope(
      canPop: !_hasChanges || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: _page(context),
    );
  }

  // The page itself: header, cards, record, and the bottom bar.
  Widget _page(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                // back button
                IconButton.outlined(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 16),

                // title and subtitle stack
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // box title and number
                    Text(
                      'Box #${widget.box.id}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [

                        // box name
                        Text('${widget.box.category.name} · '),

                        // box for labeling: racked or unracked
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isRacked ? AppColors.ink : AppColors.panel,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isRacked ? 'Racked' : 'Unracked',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _isRacked ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ),

                        // shows only while something is changed and not saved
                        if (_hasChanges) ...[
                          const SizedBox(width: 8),
                          const _OutlineTag('Unsaved changes'),
                        ],
                      ],
                    ),
                  ],
                ),
                const Spacer(),

                // print button
                OutlinedButton.icon(
                  onPressed: widget.onPrint,
                  icon: const Icon(Icons.print),
                  label: const Text('Print label'),
                ),
              ],
            ),
          ),
          // Everything under the header scrolls, so it fits on a small tablet too
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: Location | Category
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _locationCard()),
                        const SizedBox(width: 16),
                        Expanded(child: _categoryCard()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Row 2: Fullness | Rack status
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _fullnessCard()),
                        const SizedBox(width: 16),
                        Expanded(child: _rackCard()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Row 3: Notes, full width
                  _CardBox(
                    label: 'Notes',
                    children: [
                      TextField(
                        controller: _notes,
                        onChanged: (_) => setState(() {}),
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(hintText: 'No notes'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _record(),
                ],
              ),
            ),
          ),

          // Bottom bar: Delete box, and Save changes (gray until something changes)
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
            decoration: const BoxDecoration(
              color: AppColors.soft,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                SizedBox(width: 170, child: SecondaryButton('Delete box', onPressed: _saving ? null : _delete)),
                const SizedBox(width: 16),
                Expanded(
                  child: PrimaryButton(_saving ? 'Saving...' : 'Save changes', onPressed: _canSave ? _save : null),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Location card: building dropdown, shelf letter, shelf level
  Widget _locationCard() {
    return _CardBox(
      label: 'Location',
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('building-$_buildingId'),
          isExpanded: true,
          initialValue: _buildingId,
          items: [
            for (final b in widget.buildings) DropdownMenuItem(value: b.id, child: Text(b.name)),
          ],
          onChanged: (id) => setState(() => _buildingId = id!),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Shelf letter'),
                  TextField(
                    controller: _shelfLetter,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: _shelfLetterRules,
                    decoration: InputDecoration(errorText: _shelfLetter.text.isEmpty ? 'Enter 1 to 3 letters' : null),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Shelf level'),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1')),
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 3, label: Text('3')),
                    ],
                    selected: {_shelfLevel},
                    onSelectionChanged: (picked) => setState(() => _shelfLevel = picked.first),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Category card: category dropdown, days stored, and the "stored too long" tag
  Widget _categoryCard() {
    final box = widget.box;
    return _CardBox(
      label: 'Category',
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('category-$_categoryId'),
          isExpanded: true,
          initialValue: _categoryId,
          items: [
            for (final c in widget.categories)
              DropdownMenuItem(value: c.id, child: Text(c.symbol == null ? c.name : '${c.symbol} ${c.name}')),
          ],
          onChanged: (id) => setState(() => _categoryId = id!),
        ),
        const SizedBox(height: 14),
        const _Label('Days stored'),
        // Wrap, not Row: on a narrow tablet the tag moves under the number instead of running off the card
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${box.daysStored}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700)),
            if (box.storedTooLong) const _Tag('Stored too long'),
          ],
        ),
        Hint('In storage since ${_date(box.rackedSince)}. Re-racking can reset it.'),
      ],
    );
  }

  // Fullness card: Empty | Half | Full
  Widget _fullnessCard() {
    return _CardBox(
      label: 'Fullness',
      children: [
        SegmentedButton<Fullness>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: Fullness.empty, label: Text('Empty')),
            ButtonSegment(value: Fullness.half, label: Text('Half')),
            ButtonSegment(value: Fullness.full, label: Text('Full')),
          ],
          selected: {_fullness},
          onSelectionChanged: (picked) => setState(() => _fullness = picked.first),
        ),
      ],
    );
  }

  // Rack status card: Racked or Unracked, and the button that flips it.
  // Unrack only changes the form. Re-rack asks where the box is going first.
  Widget _rackCard() {
    return _CardBox(
      label: 'Rack status',
      children: [
        Text(_isRacked ? 'Racked' : 'Unracked', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        if (!_isRacked) const Hint('Not counted on the dashboard or in alerts'),
        const SizedBox(height: 12),
        SecondaryButton(
          _isRacked ? 'Unrack box' : 'Re-rack box',
          onPressed: _isRacked ? _unrack : _rerack,
        ),
      ],
    );
  }

  // Record: who created the box and who last edited it (read only)
  Widget _record() {
    final box = widget.box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Record', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Divider(height: 2, thickness: 2, color: AppColors.ink),
        _RecordRow('Created ${_date(box.createdAt)} by ${box.createdBy.name}'),
        if (box.lastUpdatedAt != null && box.lastUpdatedBy != null)
          _RecordRow('Last edited ${_date(box.lastUpdatedAt!)} by ${box.lastUpdatedBy!.name}', shaded: true),
      ],
    );
  }
}

/// A date as MM/DD/YY in the tablet's time zone, like the wireframes (01/14/26).
String _date(DateTime d) {
  final local = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.month)}/${two(local.day)}/${two(local.year % 100)}';
}

/// One rounded card on the Box page: a gray label on top, then its contents.
class _CardBox extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _CardBox({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_Label(label), ...children],
      ),
    );
  }
}

/// The small gray words above a field, like "Shelf letter".
class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
    );
  }
}

/// A small dark tag, like "Stored too long".
class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
    );
  }
}

/// One line in the Record section. Every other line is shaded, like the wireframe.
class _RecordRow extends StatelessWidget {
  final String text;
  final bool shaded;

  const _RecordRow(this.text, {this.shaded = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: shaded ? AppColors.panel : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}

/// The shelf letter's typing rules, used on the page and in the re-rack popup:
/// letters only, at most 3, turned into capitals.
final _shelfLetterRules = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
  LengthLimitingTextInputFormatter(3),
  _UpperCase(),
];

/// A building and shelf, the answer from the re-rack popup.
typedef _Location = ({int buildingId, String shelfLetter, int shelfLevel});

/// The three answers in the unsaved changes popup. Keep editing is no answer (null).
enum _LeaveChoice { discard, save }

const _popupText = TextStyle(fontSize: 14, height: 1.5);
const _popupNote = TextStyle(fontSize: 14, height: 1.5, fontStyle: FontStyle.italic);

/// The look of every popup on this page, the same as showConfirmPopup in common.dart:
/// dark border, rounded corners, a title, the contents, then the buttons on the right.
class _PopupFrame extends StatelessWidget {
  final String title;
  final List<Widget> content;
  final List<Widget> actions;

  const _PopupFrame({required this.title, required this.content, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.ink, width: 2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ...content,
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Re-rack popup (06c): where the box is going, filled in from its last location.
class _RerackPopup extends StatefulWidget {
  final int boxId;
  final List<Building> buildings;
  final _Location start;

  const _RerackPopup({required this.boxId, required this.buildings, required this.start});

  @override
  State<_RerackPopup> createState() => _RerackPopupState();
}

class _RerackPopupState extends State<_RerackPopup> {
  late int _buildingId = widget.start.buildingId;
  late int _shelfLevel = widget.start.shelfLevel;
  late final _shelfLetter = TextEditingController(text: widget.start.shelfLetter);

  @override
  void dispose() {
    _shelfLetter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PopupFrame(
      title: 'Re-rack Box #${widget.boxId}',
      content: [
        const Text('Confirm where the box is going. These are filled in from its last location.', style: _popupText),
        const SizedBox(height: 16),
        const FieldLabel('Building'),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: _buildingId,
          items: [
            for (final b in widget.buildings) DropdownMenuItem(value: b.id, child: Text(b.name)),
          ],
          onChanged: (id) => setState(() => _buildingId = id!),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Shelf letter'),
                  TextField(
                    controller: _shelfLetter,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: _shelfLetterRules,
                    decoration: InputDecoration(errorText: _shelfLetter.text.isEmpty ? 'Enter 1 to 3 letters' : null),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Shelf level'),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1')),
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 3, label: Text('3')),
                    ],
                    selected: {_shelfLevel},
                    onSelectionChanged: (picked) => setState(() => _shelfLevel = picked.first),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Next, you choose whether to reset the storage timer. The change is kept when you tap '
          'Save changes on the box page.',
          style: _popupNote,
        ),
      ],
      actions: [
        SecondaryButton('Cancel', expand: false, onPressed: () => Navigator.of(context).pop()),
        PrimaryButton(
          'Next',
          expand: false,
          onPressed: _shelfLetter.text.isEmpty
              ? null
              : () => Navigator.of(context).pop<_Location>(
                    (buildingId: _buildingId, shelfLetter: _shelfLetter.text, shelfLevel: _shelfLevel),
                  ),
        ),
      ],
    );
  }
}

/// Storage timer popup (06f), right after re-racking: true resets it to today, false keeps the date.
class _TimerPopup extends StatelessWidget {
  final Box box;

  const _TimerPopup({required this.box});

  @override
  Widget build(BuildContext context) {
    final since = _date(box.rackedSince);
    final days = box.daysStored == 1 ? '1 day' : '${box.daysStored} days';
    return _PopupFrame(
      title: 'Reset the storage timer?',
      content: [
        Text(
          'The storage timer for Box #${box.id} started on $since, $days ago. Reset it if the box is going '
          'back into storage as new. Keep the date if the box was only out for a short time.',
          style: _popupText,
        ),
        const SizedBox(height: 14),
        const Text(
          'Storage time and alerts count from this date. The change is kept when you tap Save changes '
          'on the box page.',
          style: _popupNote,
        ),
      ],
      actions: [
        SecondaryButton('Keep $since', expand: false, onPressed: () => Navigator.of(context).pop(false)),
        PrimaryButton('Reset to today', expand: false, onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
  }
}

/// A small outlined tag, like "Unsaved changes" in the header.
class _OutlineTag extends StatelessWidget {
  final String text;

  const _OutlineTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.field),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
    );
  }
}

/// Turns typed shelf letters into capitals as they are typed.
class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}