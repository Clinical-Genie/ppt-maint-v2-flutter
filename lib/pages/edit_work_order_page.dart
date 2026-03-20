import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/state/login_session_controller.dart';
import 'package:maintapp/widgets/pdf_embed_view.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class EditWorkOrderPage extends StatefulWidget {
  const EditWorkOrderPage({super.key, required this.workOrderId});

  final String workOrderId;

  @override
  State<EditWorkOrderPage> createState() => _EditWorkOrderPageState();
}

class _EditWorkOrderPageState extends State<EditWorkOrderPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _woNoController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _locationCodeController = TextEditingController();
  final TextEditingController _assetNumberController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _deviceBrandController = TextEditingController();
  final TextEditingController _deviceModelController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _haCreatedAtController = TextEditingController();
  final TextEditingController _haOutboundAtController = TextEditingController();
  final TextEditingController _cmBreakdownAtController =
      TextEditingController();
  final TextEditingController _pmDeadlineAtController = TextEditingController();

  WorkOrder _workOrder = WorkOrder();
  String _priority = 'normal';
  bool _isLoading = true;
  bool _isSaving = false;

  bool _showDesktopPdf = false;
  String _desktopPdfUrl = '';
  String _desktopPdfFileName = '';
  Map<String, String> _desktopPdfHeaders = const {};
  Uint8List? _desktopPdfBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _woNoController.dispose();
    _descriptionController.dispose();
    _remarkController.dispose();
    _locationCodeController.dispose();
    _assetNumberController.dispose();
    _serialNumberController.dispose();
    _deviceBrandController.dispose();
    _deviceModelController.dispose();
    _contactNameController.dispose();
    _contactNumberController.dispose();
    _haCreatedAtController.dispose();
    _haOutboundAtController.dispose();
    _cmBreakdownAtController.dispose();
    _pmDeadlineAtController.dispose();
    super.dispose();
  }

  bool _isDesktopSplitLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final workOrder = await ApiController.getWorkOrderById(
        widget.workOrderId,
      );
      if (!mounted) return;
      _applyWorkOrder(workOrder);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyWorkOrder(WorkOrder workOrder) {
    _workOrder = workOrder;
    _woNoController.text = workOrder.woNo;
    _descriptionController.text = workOrder.description;
    _remarkController.text = workOrder.remark;
    _locationCodeController.text = workOrder.locationCode;
    _assetNumberController.text = workOrder.assetNumber;
    _serialNumberController.text = workOrder.serialNumber;
    _deviceBrandController.text = workOrder.deviceBrand;
    _deviceModelController.text = workOrder.deviceModel;
    _contactNameController.text = workOrder.contactName;
    _contactNumberController.text = workOrder.contactNumber;
    _haCreatedAtController.text = workOrder.haCreatedAt;
    _haOutboundAtController.text = workOrder.haOutboundAt;
    _cmBreakdownAtController.text = workOrder.cmBreakdownAt;
    _pmDeadlineAtController.text = workOrder.pmDeadlineAt;
    _priority = workOrder.priority.isEmpty ? 'normal' : workOrder.priority;
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(controller.text) ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return;
    final picked = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    controller.text = picked.toIso8601String().split('.').first;
  }

  Map<String, dynamic> _buildPatchPayload() {
    final payload = <String, dynamic>{};

    void putString(String key, String value, String original) {
      final normalized = value.trim();
      final before = original.trim();
      if (normalized != before) {
        payload[key] = normalized;
      }
    }

    void putNullableString(String key, String value, String original) {
      final normalized = value.trim();
      final before = original.trim();
      final nextValue = normalized.isEmpty ? null : normalized;
      final beforeValue = before.isEmpty ? null : before;
      if (nextValue != beforeValue) {
        payload[key] = nextValue;
      }
    }

    if (_priority != _workOrder.priority && _priority.isNotEmpty) {
      payload['priority'] = _priority;
    }
    putString(
      'description',
      _descriptionController.text,
      _workOrder.description,
    );
    putNullableString('remark', _remarkController.text, _workOrder.remark);
    putString(
      'location_code',
      _locationCodeController.text,
      _workOrder.locationCode,
    );
    putString(
      'asset_number',
      _assetNumberController.text,
      _workOrder.assetNumber,
    );
    putString(
      'serial_number',
      _serialNumberController.text,
      _workOrder.serialNumber,
    );
    putString(
      'device_brand',
      _deviceBrandController.text,
      _workOrder.deviceBrand,
    );
    putString(
      'device_model',
      _deviceModelController.text,
      _workOrder.deviceModel,
    );
    putString(
      'contact_name',
      _contactNameController.text,
      _workOrder.contactName,
    );
    putString(
      'contact_number',
      _contactNumberController.text,
      _workOrder.contactNumber,
    );
    putNullableString(
      'ha_created_at',
      _haCreatedAtController.text,
      _workOrder.haCreatedAt,
    );
    putNullableString(
      'ha_outbound_at',
      _haOutboundAtController.text,
      _workOrder.haOutboundAt,
    );
    putNullableString(
      'cm_breakdown_at',
      _cmBreakdownAtController.text,
      _workOrder.cmBreakdownAt,
    );
    putNullableString(
      'pm_deadline_at',
      _pmDeadlineAtController.text,
      _workOrder.pmDeadlineAt,
    );

    payload.removeWhere((key, value) => value is String && value.isEmpty);
    return payload;
  }

  Future<void> _openSourcePdf() async {
    if (_workOrder.sourceFileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Source PDF is not available.')),
      );
      return;
    }

    final resolvedUrl = ApiController.resolveServerUrl(
      _workOrder.sourceFileUrl,
    );
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid source PDF URL.')));
      return;
    }

    await LoginSessionController.instance.refreshTokenIfNeeded();
    final accessToken = LoginSessionController.instance.loginInfo.accessToken;
    if (accessToken.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in again.')));
      return;
    }

    final headers = {'Authorization': 'Bearer $accessToken'};
    final fileName = _workOrder.sourceFileName.isEmpty
        ? 'Source PDF'
        : _workOrder.sourceFileName;

    if (_isDesktopSplitLayout(context)) {
      if (kIsWeb) {
        try {
          final response = await http.get(uri, headers: headers);
          if (response.statusCode != 200) {
            throw Exception('Unable to load PDF preview.');
          }
          if (!mounted) return;
          setState(() {
            _showDesktopPdf = true;
            _desktopPdfUrl = uri.toString();
            _desktopPdfFileName = fileName;
            _desktopPdfHeaders = headers;
            _desktopPdfBytes = response.bodyBytes;
          });
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _showDesktopPdf = true;
        _desktopPdfUrl = uri.toString();
        _desktopPdfFileName = fileName;
        _desktopPdfHeaders = headers;
        _desktopPdfBytes = null;
      });
      return;
    }

    if (kIsWeb) {
      try {
        final response = await http.get(uri, headers: headers);
        if (response.statusCode != 200) {
          throw Exception('Unable to load PDF.');
        }
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _EditWebSourcePdfViewerPage(
              fileName: fileName,
              pdfBytes: response.bodyBytes,
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EditSourcePdfViewerPage(
          fileName: fileName,
          networkUrl: uri.toString(),
          networkHeaders: headers,
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final payload = _buildPatchPayload();
    if (payload.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No changes.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await ApiController.updateWorkOrder(
        widget.workOrderId,
        payload,
      );
      if (!mounted) return;
      final message = updated.message.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message == 'No Change' ? 'No changes.' : 'Work order updated.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.trim().isNotEmpty)
              IconButton(
                onPressed: () => setState(() => controller.clear()),
                icon: const Icon(Icons.close),
                tooltip: 'Clear',
              ),
            IconButton(
              onPressed: () => _pickDateTime(controller),
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Pick date and time',
            ),
          ],
        ),
      ),
      onTap: () => _pickDateTime(controller),
    );
  }

  Widget _buildViewPdfButton() {
    if (_workOrder.sourceFileUrl.isEmpty) {
      return const Text(
        'Source PDF is not available.',
        style: TextStyle(color: Color(0xFF64748B)),
      );
    }

    return ElevatedButton(
      onPressed: _openSourcePdf,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF334155),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: const Text('View PDF'),
    );
  }

  Widget _buildDesktopPdfPanel({required double height}) {
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: height,
        child: _showDesktopPdf && _desktopPdfUrl.isNotEmpty
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _desktopPdfFileName.isEmpty
                                ? 'Source PDF'
                                : _desktopPdfFileName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showDesktopPdf = false;
                              _desktopPdfUrl = '';
                              _desktopPdfFileName = '';
                              _desktopPdfHeaders = const {};
                              _desktopPdfBytes = null;
                            });
                          },
                          child: const Text('Close PDF'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: kIsWeb
                          ? (_desktopPdfBytes == null
                                ? const Center(
                                    child: Text('Unable to load PDF preview.'),
                                  )
                                : PdfEmbedView(bytes: _desktopPdfBytes!))
                          : _EmbeddedEditSourcePdfViewer(
                              networkUrl: _desktopPdfUrl,
                              networkHeaders: _desktopPdfHeaders,
                            ),
                    ),
                  ),
                ],
              )
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Open the source PDF to review the original request while editing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      color: Colors.white,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Work Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField('WO Number', _woNoController, readOnly: true),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _priority = value);
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Description',
                _descriptionController,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField('Remark', _remarkController, maxLines: 3),
              const SizedBox(height: 16),
              _buildTextField(
                'Location Code',
                _locationCodeController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 280,
                    child: _buildTextField(
                      'Asset Number',
                      _assetNumberController,
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: _buildTextField(
                      'Serial Number',
                      _serialNumberController,
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: _buildTextField(
                      'Device Brand',
                      _deviceBrandController,
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: _buildTextField(
                      'Device Model',
                      _deviceModelController,
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: _buildTextField(
                      'Contact Name',
                      _contactNameController,
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: _buildTextField(
                      'Contact Number',
                      _contactNumberController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 280,
                    child: _buildDateField(
                      'HA Created At',
                      _haCreatedAtController,
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: _buildDateField(
                      'HA Outbound At',
                      _haOutboundAtController,
                    ),
                  ),
                  if (_workOrder.woType.toUpperCase() == 'CM')
                    SizedBox(
                      width: 280,
                      child: _buildDateField(
                        'CM Breakdown At',
                        _cmBreakdownAtController,
                      ),
                    ),
                  if (_workOrder.woType.toUpperCase() == 'PM')
                    SizedBox(
                      width: 280,
                      child: _buildDateField(
                        'PM Schedule',
                        _pmDeadlineAtController,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              const Text(
                'Source PDF',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _workOrder.sourceFileName.isEmpty
                    ? 'Use the source PDF to verify fields before saving.'
                    : _workOrder.sourceFileName,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              _buildViewPdfButton(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useSplitLayout = _isDesktopSplitLayout(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit ${_workOrder.woNo.isEmpty ? 'Work Order' : _workOrder.woNo}',
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (useSplitLayout && _showDesktopPdf) {
                  final panelHeight = constraints.maxHeight - 32;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(child: _buildFormCard()),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDesktopPdfPanel(height: panelHeight),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildFormCard(),
                );
              },
            ),
    );
  }
}

class _EmbeddedEditSourcePdfViewer extends StatefulWidget {
  const _EmbeddedEditSourcePdfViewer({
    required this.networkUrl,
    required this.networkHeaders,
  });

  final String networkUrl;
  final Map<String, String> networkHeaders;

  @override
  State<_EmbeddedEditSourcePdfViewer> createState() =>
      _EmbeddedEditSourcePdfViewerState();
}

class _EmbeddedEditSourcePdfViewerState
    extends State<_EmbeddedEditSourcePdfViewer> {
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return SfTheme(
      data: SfThemeData(
        pdfViewerThemeData: const SfPdfViewerThemeData(
          backgroundColor: Colors.white,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.white,
          child: _errorMessage == null
              ? SfPdfViewer.network(
                  widget.networkUrl,
                  headers: widget.networkHeaders,
                  onDocumentLoadFailed: (details) {
                    setState(() {
                      final rawMessage =
                          '${details.error} ${details.description}'.trim();
                      _errorMessage = rawMessage.isEmpty
                          ? 'Unable to load PDF.'
                          : rawMessage;
                    });
                  },
                )
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
}

class _EditWebSourcePdfViewerPage extends StatelessWidget {
  const _EditWebSourcePdfViewerPage({
    required this.fileName,
    required this.pdfBytes,
  });

  final String fileName;
  final Uint8List pdfBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fileName.isEmpty ? 'View PDF' : fileName)),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.white,
            child: PdfEmbedView(bytes: pdfBytes),
          ),
        ),
      ),
    );
  }
}

class _EditSourcePdfViewerPage extends StatefulWidget {
  const _EditSourcePdfViewerPage({
    required this.fileName,
    required this.networkUrl,
    required this.networkHeaders,
  });

  final String fileName;
  final String networkUrl;
  final Map<String, String> networkHeaders;

  @override
  State<_EditSourcePdfViewerPage> createState() =>
      _EditSourcePdfViewerPageState();
}

class _EditSourcePdfViewerPageState extends State<_EditSourcePdfViewerPage> {
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName.isEmpty ? 'View PDF' : widget.fileName),
      ),
      backgroundColor: Colors.white,
      body: SfTheme(
        data: SfThemeData(
          pdfViewerThemeData: const SfPdfViewerThemeData(
            backgroundColor: Colors.white,
          ),
        ),
        child: Container(
          color: Colors.white,
          child: _errorMessage == null
              ? SfPdfViewer.network(
                  widget.networkUrl,
                  headers: widget.networkHeaders,
                  onDocumentLoadFailed: (details) {
                    setState(() {
                      final rawMessage =
                          '${details.error} ${details.description}'.trim();
                      _errorMessage = rawMessage.isEmpty
                          ? 'Unable to load PDF.'
                          : rawMessage;
                    });
                  },
                )
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
}
