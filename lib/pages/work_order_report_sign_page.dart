import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/pages/work_order_report_pages.dart';
import 'package:maintapp/state/login_session_controller.dart';
import 'package:maintapp/widgets/work_order_pdf_viewer.dart';

class WorkOrderReportSignPage extends StatefulWidget {
  const WorkOrderReportSignPage({required this.workOrder, super.key});

  final WorkOrder workOrder;

  @override
  State<WorkOrderReportSignPage> createState() =>
      _WorkOrderReportSignPageState();
}

class _WorkOrderReportSignPageState extends State<WorkOrderReportSignPage> {
  final _staffIdNameController = TextEditingController();
  static const String _legacyStaffFieldKey = 'customer_staff_id_name';

  bool _isLoading = true;
  int _overlaySuspendDepth = 0;

  Map<String, dynamic> _baseDataJson = {};
  String _pdfUrl = '';
  String _pdfError = '';
  Map<String, String> _pdfHeaders = const {};

  bool get _suspendWebPdfPreview => kIsWeb && _overlaySuspendDepth > 0;

  Future<T?> _runWithOverlaySuspended<T>(Future<T?> Function() action) async {
    if (!kIsWeb) {
      return action();
    }
    if (mounted) {
      setState(() {
        _overlaySuspendDepth += 1;
      });
    }
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() {
          _overlaySuspendDepth = (_overlaySuspendDepth - 1).clamp(0, 9999);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSignContext();
  }

  @override
  void dispose() {
    _staffIdNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSignContext() async {
    setState(() {
      _isLoading = true;
      _pdfError = '';
    });
    try {
      final form = await ApiController.getWorkOrderForm(widget.workOrder.id);
      _baseDataJson = Map<String, dynamic>.from(form.dataJson);
      _staffIdNameController.text =
          '${form.raw['signed_name'] ?? form.dataJson['signed_name'] ?? form.dataJson[_legacyStaffFieldKey] ?? ''}'
              .trim();

      final rawPdfUrl = form.pdfUrl.trim();
      _pdfUrl = rawPdfUrl.isEmpty
          ? ''
          : _withPdfRefreshToken(ApiController.resolveServerUrl(rawPdfUrl));
      await LoginSessionController.instance.refreshTokenIfNeeded();
      final token = LoginSessionController.instance.loginInfo.accessToken
          .trim();
      _pdfHeaders = token.isEmpty
          ? const {}
          : {'Authorization': 'Bearer $token'};
      if (_pdfUrl.isEmpty) {
        _pdfError = 'Report PDF is not ready yet.';
      }
    } catch (e) {
      _pdfError = '$e';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _withPdfRefreshToken(String url) {
    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            '_pdf_refresh': DateTime.now().microsecondsSinceEpoch.toString(),
          },
        )
        .toString();
  }

  Future<void> _editReport() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkOrderReportFormPage(workOrder: widget.workOrder),
      ),
    );
    if (updated == true) {
      await _loadSignContext();
    }
  }

  Future<void> _openSignDialog() async {
    final formKey = GlobalKey<FormState>();
    final boundaryKey = GlobalKey();
    final points = <Offset?>[];
    bool submitting = false;

    await _runWithOverlaySuspended(
      () => showDialog<void>(
        context: context,
        barrierDismissible: !submitting,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                if (!formKey.currentState!.validate()) return;
                if (points.whereType<Offset>().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please input signature first.'),
                    ),
                  );
                  return;
                }

                setDialogState(() => submitting = true);
                try {
                  final boundary =
                      boundaryKey.currentContext?.findRenderObject()
                          as RenderRepaintBoundary?;
                  if (boundary == null) {
                    throw Exception('Signature canvas is not ready.');
                  }
                  final image = await boundary.toImage(pixelRatio: 3);
                  final byteData = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  if (byteData == null) {
                    throw Exception('Unable to generate signature image.');
                  }
                  final signatureBytes = byteData.buffer.asUint8List();

                  final result = await ApiController.signWorkOrderForm(
                    widget.workOrder.id,
                    signedName: _staffIdNameController.text.trim(),
                    dataJson: Map<String, dynamic>.from(_baseDataJson),
                    signatureBytes: signatureBytes,
                  );
                  if (!mounted) return;
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.message.trim().isEmpty
                            ? 'Form signed.'
                            : result.message.trim(),
                      ),
                    ),
                  );
                  Navigator.of(this.context).pop(true);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                  if (dialogContext.mounted) {
                    setDialogState(() => submitting = false);
                  }
                }
              }

              return AlertDialog(
                title: const Text('Sign Report'),
                content: SizedBox(
                  width: 520,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Signature',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: GestureDetector(
                              onPanStart: (details) {
                                final box =
                                    boundaryKey.currentContext
                                            ?.findRenderObject()
                                        as RenderBox?;
                                if (box == null) return;
                                final local = box.globalToLocal(
                                  details.globalPosition,
                                );
                                setDialogState(() => points.add(local));
                              },
                              onPanUpdate: (details) {
                                final box =
                                    boundaryKey.currentContext
                                            ?.findRenderObject()
                                        as RenderBox?;
                                if (box == null) return;
                                final local = box.globalToLocal(
                                  details.globalPosition,
                                );
                                setDialogState(() => points.add(local));
                              },
                              onPanEnd: (_) {
                                setDialogState(() => points.add(null));
                              },
                              child: RepaintBoundary(
                                key: boundaryKey,
                                child: CustomPaint(
                                  painter: _SignaturePainter(
                                    List<Offset?>.from(points),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: submitting
                                ? null
                                : () => setDialogState(() => points.clear()),
                            child: const Text('Clear Signature'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _staffIdNameController,
                          decoration: const InputDecoration(
                            labelText: 'Staff ID / Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: submitting ? null : submit,
                    child: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('OK'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPdfPreviewCard() {
    if (_pdfUrl.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _pdfError.isEmpty ? 'PDF is not ready yet.' : _pdfError,
            style: const TextStyle(color: Color(0xFF475569)),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: WorkOrderPdfViewer(
          key: ValueKey(_pdfUrl),
          networkUrl: _pdfUrl,
          contentType: 'application/pdf',
          networkHeaders: _pdfHeaders,
          suspendOnOverlay: _suspendWebPdfPreview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review and Sign'),
        actions: [
          IconButton(
            onPressed: _editReport,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Report',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_pdfError.isNotEmpty && _pdfUrl.isNotEmpty) ...[
                    Text(
                      _pdfError,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(child: _buildPdfPreviewCard()),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton(
            onPressed: _pdfUrl.isEmpty ? null : _openSignDialog,
            child: const Text('Confirmed to Sign'),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
