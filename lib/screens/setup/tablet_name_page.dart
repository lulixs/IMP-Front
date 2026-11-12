import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../validators.dart';
import '../../widgets/common.dart';
import 'setup_layout.dart';

/// Step 2 of first-time setup (wireframe 01d): name this tablet.
class TabletNamePage extends StatefulWidget {
  /// Called with the trimmed name once it is valid.
  final void Function(String name) onNext;

  const TabletNamePage({super.key, required this.onNext});

  @override
  State<TabletNamePage> createState() => _TabletNamePageState();
}

class _TabletNamePageState extends State<TabletNamePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_formKey.currentState!.validate()) {
      widget.onNext(_name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SetupLayout(
      step: 2,
      subtitle: 'Name this device.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Tablet name'),
            TextFormField(
              controller: _name,
              autofocus: true,
              inputFormatters: [LengthLimitingTextInputFormatter(maxTabletNameLength)],
              decoration: const InputDecoration(hintText: 'e.g. Processing tablet'),
              validator: validateTabletName,
              onFieldSubmitted: (_) => _next(),
            ),
            const SizedBox(height: 20),
            SetupButtons(onNext: _next),
          ],
        ),
      ),
    );
  }
}
