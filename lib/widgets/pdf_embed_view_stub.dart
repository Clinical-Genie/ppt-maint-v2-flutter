import 'dart:typed_data';

import 'package:flutter/material.dart';

class PdfEmbedView extends StatelessWidget {
  const PdfEmbedView({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Embedded PDF preview is only available on web.'),
    );
  }
}
