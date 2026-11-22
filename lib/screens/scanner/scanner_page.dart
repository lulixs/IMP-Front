import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/box.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../boxes/open_box.dart';

/// The box number in a box label's QR code, or null if the code isn't an IMP label.
/// A label holds `IMP-` and the box number, like `IMP-6789` (D-107).
int? boxIdFromCode(String code) {
  final match = RegExp(r'^IMP-(\d{1,9})$').firstMatch(code.trim());
  return match == null ? null : int.parse(match.group(1)!);
}

/// Builds the camera view. It calls onCode with the text of each QR code it reads. Tests pass a fake camera.
typedef CameraBuilder = Widget Function(BuildContext context, void Function(String code) onCode);

/// QR scanner (US-10, wireframes 05a to 05c). It reads a box label and opens the box with openBox, which swaps
/// this screen for the Box page, so Back from the Box page returns to where Scan was tapped.
///
/// - A code that isn't `IMP-` and a number, or a box the server doesn't have, shows "No box matches this code" (05b).
///   A code that isn't a label never reaches the server.
/// - A soft-deleted box shows who deleted it and when (05c).
/// - A failed load (no connection, for example) shows the server's sentence.
///
/// Every sheet has Back and Scan again.
class ScannerPage extends StatefulWidget {
  /// Null uses the tablet's camera. Tests give a fake one.
  final CameraBuilder? camera;

  const ScannerPage({super.key, this.camera});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

/// What the bottom of the screen shows: the instructions while scanning, or a sheet after a scan that didn't open.
sealed class _Sheet {
  const _Sheet();
}

class _NoMatch extends _Sheet {
  const _NoMatch();
}

class _Deleted extends _Sheet {
  final Box box;
  const _Deleted(this.box);
}

class _Failed extends _Sheet {
  final String message;
  const _Failed(this.message);
}

class _ScannerPageState extends State<ScannerPage> {
  // The sheet on show, or null while scanning
  _Sheet? _sheet;

  // True from a good scan until openBox answers. The camera keeps reading the same label many times a
  // second, so every read in between is ignored.
  bool _opening = false;

  // The debug-only "Type a code" field. Kept for the life of the screen, since the popup still shows it while closing.
  final _typed = TextEditingController(text: 'IMP-');

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _onCode(String code) async {
    if (_opening || _sheet != null) return;
    final id = boxIdFromCode(code);
    if (id == null) {
      setState(() => _sheet = const _NoMatch());
      return;
    }

    _opening = true;
    final result = await openBox(context, id, replace: true, showProblems: false);
    // After BoxOpened this screen is gone. After a sign-in problem too.
    if (!mounted) return;
    setState(() {
      _opening = false;
      _sheet = switch (result) {
        BoxWasDeleted(:final box) => _Deleted(box),
        BoxNotFound() => const _NoMatch(),
        BoxLoadFailed(:final message) => message == null ? null : _Failed(message),
        BoxOpened() => null,
      };
    });
  }

  void _scanAgain() => setState(() => _sheet = null);

  /// Debug builds only: type a code instead of scanning one, for the emulator and Chrome without a label.
  Future<void> _typeCode() async {
    final code = await showDialog<String>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (context) => AlertDialog(
        title: const Text('Type a code (debug only)'),
        content: TextField(
          controller: _typed,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          SecondaryButton('Cancel', expand: false, onPressed: () => Navigator.of(context).pop()),
          PrimaryButton('Scan', expand: false, onPressed: () => Navigator.of(context).pop(_typed.text)),
        ],
      ),
    );
    if (code != null && mounted) await _onCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final CameraBuilder camera = widget.camera ?? (_, onCode) => _Camera(onCode: onCode);
    final sheet = _sheet;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: camera(context, _onCode)),
          const IgnorePointer(
            child: Center(child: SizedBox(width: 300, height: 300, child: CustomPaint(painter: _ViewfinderPainter()))),
          ),
          Positioned(left: 0, right: 0, top: 0, child: _topBar(context)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: sheet == null ? _instructions() : _ResultSheet(sheet: sheet, onScanAgain: _scanAgain),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      color: _barColor,
      padding: EdgeInsets.fromLTRB(22, MediaQuery.paddingOf(context).top + 20, 22, 20),
      child: Row(
        children: [
          IconButton.outlined(
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
            style: IconButton.styleFrom(side: const BorderSide(color: Colors.white, width: 2)),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Scan a box', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
          ),
          if (kDebugMode)
            TextButton(
              onPressed: _typeCode,
              child: const Text('Type a code', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _instructions() {
    return Container(
      color: _barColor,
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
      child: const SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Point the camera at a box label',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'The box page opens as soon as the code is read',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFE2E2E2), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dark see-through bars at the top and bottom, over the camera
const _barColor = Color(0xD1222222);

/// The sheet after a scan that didn't open a box (05b, 05c, or a failed load), with Back and Scan again.
class _ResultSheet extends StatelessWidget {
  final _Sheet sheet;
  final VoidCallback onScanAgain;

  const _ResultSheet({required this.sheet, required this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (sheet) {
      _NoMatch() => (
          'No box matches this code',
          'This QR code is not an IMP box label, or the box was permanently deleted. Check the label and try again.',
        ),
      _Deleted(:final box) => (
          'Box #${box.id} was deleted',
          '${box.deletedBy?.name ?? 'Someone'} deleted this box on ${_date(box.deletedAt!)}. It is hidden until '
              'the Master account restores it from Deleted Items.',
        ),
      _Failed(message: final sentence) => ("Couldn't open the box", sentence),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 26),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.ink, width: 2)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, size: 26, color: AppColors.ink),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontSize: 14.5, height: 1.5)),
            const SizedBox(height: 16),
            Row(
              children: [
                SecondaryButton('Back', expand: false, onPressed: () => Navigator.maybePop(context)),
                const SizedBox(width: 10),
                PrimaryButton('Scan again', expand: false, onPressed: onScanAgain),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A date as MM/DD/YY in the tablet's time zone, like the Box page.
String _date(DateTime d) {
  final local = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.month)}/${two(local.day)}/${two(local.year % 100)}';
}

/// The tablet's camera, reading QR codes only. Asks for camera access the first time.
class _Camera extends StatefulWidget {
  final void Function(String code) onCode;

  const _Camera({required this.onCode});

  @override
  State<_Camera> createState() => _CameraState();
}

class _CameraState extends State<_Camera> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final code = barcode.rawValue;
          if (code != null) {
            widget.onCode(code);
            return;
          }
        }
      },
      errorBuilder: (context, error) => _CameraProblem(
        error.errorCode == MobileScannerErrorCode.permissionDenied
            ? 'IMP needs the camera to scan labels. Allow camera access in the tablet settings, then try again.'
            : 'The camera could not start. Close this screen and try again.',
      ),
    );
  }
}

/// Shown in place of the camera when it can't start.
class _CameraProblem extends StatelessWidget {
  final String message;

  const _CameraProblem(this.message);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.panel,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined, size: 40, color: AppColors.ink3),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.ink2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The four corners in the middle of the screen that show where to hold the label.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 60.0;
    canvas.drawPath(Path()..moveTo(0, l)..lineTo(0, 0)..lineTo(l, 0), paint);
    canvas.drawPath(Path()..moveTo(s.width - l, 0)..lineTo(s.width, 0)..lineTo(s.width, l), paint);
    canvas.drawPath(Path()..moveTo(0, s.height - l)..lineTo(0, s.height)..lineTo(l, s.height), paint);
    canvas.drawPath(Path()..moveTo(s.width - l, s.height)..lineTo(s.width, s.height)..lineTo(s.width, s.height - l), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
