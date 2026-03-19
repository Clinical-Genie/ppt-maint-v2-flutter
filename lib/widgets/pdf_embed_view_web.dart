import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class PdfEmbedView extends StatefulWidget {
  const PdfEmbedView({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<PdfEmbedView> createState() => _PdfEmbedViewState();
}

class _PdfEmbedViewState extends State<PdfEmbedView> {
  late String _viewType;
  String? _objectUrl;

  @override
  void initState() {
    super.initState();
    _registerFrame();
  }

  @override
  void didUpdateWidget(covariant PdfEmbedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) {
      _disposeObjectUrl();
      _registerFrame();
    }
  }

  @override
  void dispose() {
    _disposeObjectUrl();
    super.dispose();
  }

  void _registerFrame() {
    final blob = html.Blob(<dynamic>[widget.bytes], 'application/pdf');
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);
    final viewType =
        'pdf-embed-${DateTime.now().microsecondsSinceEpoch}-${widget.bytes.length}';

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      return html.IFrameElement()
        ..src = objectUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    });

    _objectUrl = objectUrl;
    _viewType = viewType;
  }

  void _disposeObjectUrl() {
    final objectUrl = _objectUrl;
    if (objectUrl != null) {
      html.Url.revokeObjectUrl(objectUrl);
      _objectUrl = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
