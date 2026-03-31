import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pdf_embed_view.dart';

class WorkOrderPdfViewer extends StatefulWidget {
  const WorkOrderPdfViewer({
    super.key,
    required this.networkUrl,
    required this.contentType,
    this.memoryBytes,
    required this.networkHeaders,
    this.suspendOnOverlay = false,
  });

  final String networkUrl;
  final String contentType;
  final Uint8List? memoryBytes;
  final Map<String, String> networkHeaders;
  final bool suspendOnOverlay;

  @override
  State<WorkOrderPdfViewer> createState() => _WorkOrderPdfViewerState();
}

class _WorkOrderPdfViewerState extends State<WorkOrderPdfViewer> {
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final isImage = widget.contentType.toLowerCase().startsWith('image/');
    final hasMemorySource =
        widget.memoryBytes != null && widget.memoryBytes!.isNotEmpty;

    if (kIsWeb && widget.suspendOnOverlay) {
      return _buildSuspendedPlaceholder();
    }

    if (kIsWeb && !isImage) {
      if (hasMemorySource) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.white,
            child: PdfEmbedView(bytes: widget.memoryBytes!),
          ),
        );
      }
      return _WebNetworkPdfViewer(
        networkUrl: widget.networkUrl,
        networkHeaders: widget.networkHeaders,
      );
    }

    return SfTheme(
      data: SfThemeData(
        pdfViewerThemeData: SfPdfViewerThemeData(backgroundColor: Colors.white),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.white,
          child: _errorMessage == null
              ? isImage
                    ? Center(
                        child: InteractiveViewer(
                          child: hasMemorySource
                              ? Image.memory(widget.memoryBytes!)
                              : Image.network(
                                  widget.networkUrl,
                                  headers: widget.networkHeaders,
                                  errorBuilder: (_, __, ___) {
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      if (!mounted) return;
                                      setState(() {
                                        _errorMessage =
                                            'Unable to load attachment.';
                                      });
                                    });
                                    return const SizedBox.shrink();
                                  },
                                ),
                        ),
                      )
                    : (hasMemorySource
                          ? SfPdfViewer.memory(
                              widget.memoryBytes!,
                              onDocumentLoadFailed: (details) {
                                setState(() {
                                  final rawMessage =
                                      '${details.error} ${details.description}'
                                          .trim();
                                  _errorMessage = rawMessage.isEmpty
                                      ? 'Unable to load attachment.'
                                      : rawMessage;
                                });
                              },
                            )
                          : SfPdfViewer.network(
                              widget.networkUrl,
                              headers: widget.networkHeaders,
                              onDocumentLoadFailed: (details) {
                                setState(() {
                                  final rawMessage =
                                      '${details.error} ${details.description}'
                                          .trim();
                                  _errorMessage = rawMessage.isEmpty
                                      ? 'Unable to load attachment.'
                                      : rawMessage;
                                });
                              },
                            ))
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSuspendedPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFF8FAFC),
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Preview paused while dialog is open.',
            style: TextStyle(color: Color(0xFF475569)),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _WebNetworkPdfViewer extends StatefulWidget {
  const _WebNetworkPdfViewer({
    required this.networkUrl,
    required this.networkHeaders,
  });

  final String networkUrl;
  final Map<String, String> networkHeaders;

  @override
  State<_WebNetworkPdfViewer> createState() => _WebNetworkPdfViewerState();
}

class _WebNetworkPdfViewerState extends State<_WebNetworkPdfViewer> {
  Uint8List? _bytes;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _WebNetworkPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.networkUrl != widget.networkUrl ||
        !mapEquals(oldWidget.networkHeaders, widget.networkHeaders)) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _bytes = null;
    });
    try {
      final response = await http.get(
        Uri.parse(widget.networkUrl),
        headers: widget.networkHeaders,
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Unable to load attachment (${response.statusCode}).',
        );
      }
      if (response.bodyBytes.isEmpty) {
        throw Exception('Attachment returned empty data.');
      }
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(response.bodyBytes);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    if (_bytes == null || _bytes!.isEmpty) {
      return const Center(child: Text('Unable to load attachment preview.'));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(color: Colors.white, child: PdfEmbedView(bytes: _bytes!)),
    );
  }
}

class WorkOrderWebAttachmentViewerPage extends StatelessWidget {
  const WorkOrderWebAttachmentViewerPage({
    super.key,
    required this.fileName,
    required this.fileBytes,
    required this.contentType,
    this.description = '',
    this.suspendOnOverlay = false,
  });

  final String fileName;
  final Uint8List fileBytes;
  final String contentType;
  final String description;
  final bool suspendOnOverlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName.isEmpty ? 'View Attachment' : fileName),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (description.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  description.trim(),
                  style: const TextStyle(color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.white,
                  child: WorkOrderInlineAttachmentPreview(
                    bytes: fileBytes,
                    contentType: contentType,
                    suspendOnOverlay: suspendOnOverlay,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkOrderAttachmentViewerPage extends StatefulWidget {
  const WorkOrderAttachmentViewerPage({
    super.key,
    this.pdfBytes,
    this.networkUrl,
    this.networkHeaders,
    required this.fileName,
    required this.contentType,
    this.description = '',
  });

  final Uint8List? pdfBytes;
  final String? networkUrl;
  final Map<String, String>? networkHeaders;
  final String fileName;
  final String contentType;
  final String description;
  bool get hasNetworkSource => networkUrl != null && networkUrl!.isNotEmpty;
  bool get hasMemorySource => pdfBytes != null && pdfBytes!.isNotEmpty;

  @override
  State<WorkOrderAttachmentViewerPage> createState() =>
      _WorkOrderAttachmentViewerPageState();
}

class _WorkOrderAttachmentViewerPageState
    extends State<WorkOrderAttachmentViewerPage> {
  String? _errorMessage;
  bool _openingFallback = false;

  @override
  Widget build(BuildContext context) {
    Widget viewer = const SizedBox.shrink();
    final isImage = widget.contentType.toLowerCase().startsWith('image/');
    if (_errorMessage == null) {
      if (isImage && widget.hasMemorySource) {
        viewer = Center(
          child: InteractiveViewer(child: Image.memory(widget.pdfBytes!)),
        );
      } else if (widget.hasMemorySource && !isImage) {
        viewer = SfPdfViewer.memory(
          widget.pdfBytes!,
          onDocumentLoadFailed: (details) {
            setState(() {
              final rawMessage = '${details.error} ${details.description}'
                  .trim();
              _errorMessage = rawMessage.isEmpty
                  ? 'Unable to load attachment.'
                  : rawMessage;
            });
          },
        );
      } else if (widget.hasNetworkSource && !kIsWeb && !isImage) {
        viewer = SfPdfViewer.network(
          widget.networkUrl!,
          headers: widget.networkHeaders,
          onDocumentLoadFailed: (details) {
            setState(() {
              final rawMessage = '${details.error} ${details.description}'
                  .trim();
              _errorMessage = rawMessage.isEmpty
                  ? 'Unable to load attachment.'
                  : rawMessage;
            });
          },
        );
      } else {
        viewer = const Center(
          child: Text('No attachment source is available.'),
        );
      }
    } else {
      viewer = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SelectableText(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openingFallback ? null : _openWithSystemViewer,
                icon: _openingFallback
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.launch),
                label: const Text('Open file in system viewer'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName.isEmpty ? 'View Attachment' : widget.fileName,
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.description.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  widget.description.trim(),
                  style: const TextStyle(color: Color(0xFF334155)),
                ),
              ),
            ),
          Expanded(
            child: SfTheme(
              data: SfThemeData(
                pdfViewerThemeData: SfPdfViewerThemeData(
                  backgroundColor: Colors.white,
                ),
              ),
              child: Container(color: Colors.white, child: viewer),
            ),
          ),
        ],
      ),
      floatingActionButton: _errorMessage == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
    );
  }

  Future<void> _openWithSystemViewer() async {
    setState(() {
      _openingFallback = true;
    });
    try {
      Uint8List? sourceBytes = widget.pdfBytes;

      if (kIsWeb) {
        if (sourceBytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No file bytes available to open locally.'),
            ),
          );
          return;
        }
        final dataUri = Uri.dataFromBytes(
          sourceBytes,
          mimeType: widget.contentType.isEmpty
              ? 'application/octet-stream'
              : widget.contentType,
        );
        final launched = await launchUrl(
          dataUri,
          mode: LaunchMode.platformDefault,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app found to open file.')),
          );
        }
        return;
      }

      if (widget.pdfBytes == null && widget.hasNetworkSource) {
        final uri = Uri.parse(widget.networkUrl!);
        final response = await http.get(uri, headers: widget.networkHeaders);
        if (response.statusCode != 200) {
          throw Exception(
            'Open attachment failed (${response.statusCode}): ${response.reasonPhrase ?? 'Request error'}',
          );
        }
        sourceBytes = Uint8List.fromList(response.bodyBytes);
      } else if (widget.pdfBytes != null) {
        sourceBytes = widget.pdfBytes;
      }

      if (sourceBytes == null || sourceBytes.isEmpty) {
        throw Exception('No attachment content available.');
      }

      final dataUri = Uri.dataFromBytes(
        sourceBytes,
        mimeType: widget.contentType.isEmpty
            ? 'application/octet-stream'
            : widget.contentType,
      );
      final launched = await launchUrl(
        dataUri,
        mode: LaunchMode.platformDefault,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No app found to open file.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open file locally: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingFallback = false;
        });
      }
    }
  }
}

class WorkOrderInlineAttachmentPreview extends StatelessWidget {
  const WorkOrderInlineAttachmentPreview({
    super.key,
    required this.bytes,
    required this.contentType,
    this.suspendOnOverlay = false,
  });

  final Uint8List bytes;
  final String contentType;
  final bool suspendOnOverlay;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && suspendOnOverlay) {
      return const Center(
        child: Text(
          'Preview paused while dialog is open.',
          style: TextStyle(color: Color(0xFF475569)),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (contentType.toLowerCase().startsWith('image/')) {
      return Center(child: InteractiveViewer(child: Image.memory(bytes)));
    }
    return PdfEmbedView(bytes: bytes);
  }
}
