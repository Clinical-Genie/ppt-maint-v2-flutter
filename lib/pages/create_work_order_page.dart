import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/app_state.dart';
import 'package:maintapp/state/login_session_controller.dart';
import 'package:maintapp/widgets/pdf_embed_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class CreateWorkOrderPage extends StatefulWidget {
  const CreateWorkOrderPage({super.key});

  @override
  State<CreateWorkOrderPage> createState() => _CreateWorkOrderPageState();
}

class _CreateWorkOrderPageState extends State<CreateWorkOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _formControllers = <String, TextEditingController>{
    'woNo': TextEditingController(),
    'description': TextEditingController(),
    'locationCode': TextEditingController(),
    'assetNumber': TextEditingController(),
    'serialNumber': TextEditingController(),
    'deviceBrand': TextEditingController(),
    'deviceModel': TextEditingController(),
    'contactName': TextEditingController(),
    'contactNumber': TextEditingController(),
    'priority': TextEditingController(text: 'normal'),
    'haCreatedAt': TextEditingController(),
    'haOutboundAt': TextEditingController(),
    'cmBreakdownAt': TextEditingController(),
    'pmDeadlineAt': TextEditingController(),
    'remark': TextEditingController(),
  };

  final List<String> _workOrderTypes = const ['CM', 'PM'];
  String _workOrderType = 'CM';
  bool _isLoading = false;
  bool _isUploadingPdf = false;
  String _selectedPdfName = '';
  String _selectedPdfStatus = '';
  String _sourceFileId = '';
  String _sourceFileName = '';
  String _sourceFileUrl = '';
  String _ocrJobId = '';
  String _extractionMode = '';
  String _extractionLabel = '';
  WorkOrder? _ocrDraft;
  bool _showDesktopPdf = false;
  String _desktopPdfUrl = '';
  String _desktopPdfFileName = '';
  Map<String, String> _desktopPdfHeaders = const {};
  Uint8List? _desktopPdfBytes;

  @override
  void dispose() {
    for (final controller in _formControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _currentUserId {
    return LoginSessionController.instance.userInfo.id;
  }

  Future<void> _pickPdf() async {
    setState(() {
      _isUploadingPdf = true;
      _selectedPdfStatus = 'Uploading and running OCR...';
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        setState(() {
          _selectedPdfStatus = '';
        });
        return;
      }

      final pdf = picked.files.first;
      if (pdf.bytes == null || pdf.bytes!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected PDF has no content.')),
        );
        setState(() {
          _selectedPdfStatus = '';
        });
        return;
      }

      final ocrResult = await ApiController.uploadWorkOrderOcr(
        pdf.bytes!,
        filename: pdf.name,
      );
      if (!mounted) return;

      _selectedPdfName = pdf.name;
      _extractionMode = ocrResult.extractionMode.toLowerCase();
      _extractionLabel = ocrResult.extractionLabel;
      _selectedPdfStatus = _extractionMode == 'failed'
          ? 'OCR failed'
          : (ocrResult.ok ? 'OCR done' : 'OCR completed with limited results');
      final ocrWoType = ocrResult.workOrderDraft.woType.trim().toUpperCase();
      if (ocrWoType == 'CM' || ocrWoType == 'PM') {
        _workOrderType = ocrWoType;
      }
      if (_extractionLabel.isNotEmpty) {
        _selectedPdfStatus =
            '$_selectedPdfStatus (method: ${_extractionLabel.toLowerCase()})';
      }
      _sourceFileId = ocrResult.sourceFileId;
      _sourceFileName = ocrResult.sourceFileName;
      _sourceFileUrl = ocrResult.sourceFileUrl;
      _ocrJobId = ocrResult.ocrJobId;
      _ocrDraft = ocrResult.workOrderDraft;

      _applyOcrDraft(ocrResult.workOrderDraft);
      await _openSourcePdfInSplitLayoutIfNeeded();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR completed, form auto-filled.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPdf = false);
      }
    }
  }

  void _clearPdf() {
    _resetFormFields();
    setState(() {
      _selectedPdfName = '';
      _selectedPdfStatus = '';
      _sourceFileId = '';
      _sourceFileName = '';
      _sourceFileUrl = '';
      _ocrJobId = '';
      _extractionMode = '';
      _extractionLabel = '';
      _ocrDraft = null;
      _showDesktopPdf = false;
      _desktopPdfUrl = '';
      _desktopPdfFileName = '';
      _desktopPdfHeaders = const {};
      _desktopPdfBytes = null;
      _workOrderType = 'CM';
    });
  }

  bool _isDesktopSplitLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  Future<void> _openSourcePdfInSplitLayoutIfNeeded() async {
    if (_sourceFileUrl.isEmpty) return;
    if (!_isDesktopSplitLayout(context)) return;

    final resolvedUrl = ApiController.resolveServerUrl(_sourceFileUrl);
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) return;

    await LoginSessionController.instance.refreshTokenIfNeeded();
    final accessToken = LoginSessionController.instance.loginInfo.accessToken;
    if (accessToken.isEmpty) return;

    final fileName = _sourceFileName.isNotEmpty
        ? _sourceFileName
        : _selectedPdfName;

    if (!mounted) return;

    if (kIsWeb) {
      try {
        final request = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        if (request.statusCode == 200) {
          setState(() {
            _showDesktopPdf = true;
            _desktopPdfUrl = uri.toString();
            _desktopPdfFileName = fileName;
            _desktopPdfHeaders = {'Authorization': 'Bearer $accessToken'};
            _desktopPdfBytes = request.bodyBytes;
          });
        }
      } catch (_) {
        return;
      }
      return;
    }

    setState(() {
      _showDesktopPdf = true;
      _desktopPdfUrl = uri.toString();
      _desktopPdfFileName = fileName;
      _desktopPdfHeaders = {'Authorization': 'Bearer $accessToken'};
      _desktopPdfBytes = null;
    });
  }

  Future<void> _openSourcePdf() async {
    if (_sourceFileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF source is not available yet.')),
      );
      return;
    }

    final resolvedUrl = ApiController.resolveServerUrl(_sourceFileUrl);
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid PDF source URL.')));
      return;
    }

    if (!mounted) return;

    await LoginSessionController.instance.refreshTokenIfNeeded();
    final accessToken = LoginSessionController.instance.loginInfo.accessToken;
    if (accessToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login expired. Please sign in again.')),
        );
      }
      return;
    }

    final fileName = _sourceFileName.isNotEmpty
        ? _sourceFileName
        : _selectedPdfName;

    if (_isDesktopSplitLayout(context) && !kIsWeb) {
      setState(() {
        _showDesktopPdf = true;
        _desktopPdfUrl = uri.toString();
        _desktopPdfFileName = fileName;
        _desktopPdfHeaders = {'Authorization': 'Bearer $accessToken'};
        _desktopPdfBytes = null;
      });
      return;
    }

    try {
      log('PDF request: ${uri.toString()}');
      final request = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      log(
        'PDF response: status=${request.statusCode},'
        ' contentType=${request.headers['content-type']},'
        ' contentLength=${request.bodyBytes.length}',
      );
      if (request.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unauthorized to open PDF. Please re-login.'),
          ),
        );
        return;
      }
      if (request.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Open PDF failed (${request.statusCode}): ${request.reasonPhrase ?? 'Request error'}',
            ),
          ),
        );
        return;
      }
      final contentType = request.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/pdf') &&
          !contentType.toLowerCase().contains('application/octet-stream')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid content type for PDF: ${contentType.isEmpty ? 'unknown' : contentType}',
            ),
          ),
        );
        return;
      }
      if (request.bodyBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF file returned empty data.')),
        );
        return;
      }

      if (_isDesktopSplitLayout(context)) {
        setState(() {
          _showDesktopPdf = true;
          _desktopPdfUrl = uri.toString();
          _desktopPdfFileName = fileName;
          _desktopPdfHeaders = {'Authorization': 'Bearer $accessToken'};
          _desktopPdfBytes = Uint8List.fromList(request.bodyBytes);
        });
        return;
      }

      if (kIsWeb) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _WebSourcePdfViewerPage(
              fileName: fileName,
              pdfBytes: Uint8List.fromList(request.bodyBytes),
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _SourcePdfViewerPage(
            networkUrl: uri.toString(),
            networkHeaders: {'Authorization': 'Bearer $accessToken'},
            fileName: fileName,
            parseErrorHint:
                'Fetched with status ${request.statusCode}, content-type: ${request.headers['content-type'] ?? 'unknown'}, size: ${request.bodyBytes.length} bytes.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load PDF: $e')));
    }
  }

  void _setText(String key, String value) {
    _formControllers[key]!.text = value;
  }

  void _resetFormFields({bool clearPriority = true}) {
    for (final entry in _formControllers.entries) {
      entry.value.text = '';
    }
    if (clearPriority) {
      _formControllers['priority']!.text = 'normal';
    }
  }

  void _resetForm() {
    setState(() {
      _workOrderType = 'CM';
      _resetFormFields();
    });
  }

  void _applyOcrDraft(WorkOrder draft, {bool force = false}) {
    if (force) {
      _setText('woNo', draft.woNo);
      _setText('description', draft.description);
      if (draft.locationCode.isNotEmpty) {
        _setText('locationCode', draft.locationCode);
      } else if (draft.institutionCode.isNotEmpty) {
        _setText('locationCode', draft.institutionCode);
      } else {
        _setText('locationCode', '');
      }
      _setText('assetNumber', draft.assetNumber);
      _setText('serialNumber', draft.serialNumber);
      _setText('deviceBrand', draft.deviceBrand);
      _setText('deviceModel', draft.deviceModel);
      _setText('contactName', draft.contactName);
      _setText('contactNumber', draft.contactNumber);
      _setText(
        'priority',
        draft.priority.isNotEmpty ? draft.priority : 'normal',
      );
      _setText('haCreatedAt', draft.haCreatedAt);
      _setText('haOutboundAt', draft.haOutboundAt);
      _setText('cmBreakdownAt', draft.cmBreakdownAt);
      _setText('pmDeadlineAt', draft.pmDeadlineAt);
      _setText('remark', draft.remark);
      setState(() {});
      return;
    }

    if (draft.woNo.isNotEmpty) _formControllers['woNo']!.text = draft.woNo;
    if (draft.description.isNotEmpty) {
      _formControllers['description']!.text = draft.description;
    }
    if (draft.locationCode.isNotEmpty) {
      _formControllers['locationCode']!.text = draft.locationCode;
    } else if (draft.institutionCode.isNotEmpty) {
      _formControllers['locationCode']!.text = draft.institutionCode;
    }
    if (draft.assetNumber.isNotEmpty) {
      _formControllers['assetNumber']!.text = draft.assetNumber;
    }
    if (draft.serialNumber.isNotEmpty) {
      _formControllers['serialNumber']!.text = draft.serialNumber;
    }
    if (draft.deviceBrand.isNotEmpty) {
      _formControllers['deviceBrand']!.text = draft.deviceBrand;
    }
    if (draft.deviceModel.isNotEmpty) {
      _formControllers['deviceModel']!.text = draft.deviceModel;
    }
    if (draft.contactName.isNotEmpty) {
      _formControllers['contactName']!.text = draft.contactName;
    }
    if (draft.contactNumber.isNotEmpty) {
      _formControllers['contactNumber']!.text = draft.contactNumber;
    }
    if (draft.priority.isNotEmpty) {
      _formControllers['priority']!.text = draft.priority;
    }
    if (draft.haCreatedAt.isNotEmpty) {
      _formControllers['haCreatedAt']!.text = draft.haCreatedAt;
    }
    if (draft.haOutboundAt.isNotEmpty) {
      _formControllers['haOutboundAt']!.text = draft.haOutboundAt;
    }
    if (draft.cmBreakdownAt.isNotEmpty) {
      _formControllers['cmBreakdownAt']!.text = draft.cmBreakdownAt;
    }
    if (draft.pmDeadlineAt.isNotEmpty) {
      _formControllers['pmDeadlineAt']!.text = draft.pmDeadlineAt;
    }
    setState(() {});
  }

  void _resetFormToOcrDraft() {
    if (_ocrDraft == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No OCR draft available.')));
      return;
    }
    setState(() {
      final draftType = _ocrDraft!.woType.trim().toUpperCase();
      _workOrderType = (draftType == 'CM' || draftType == 'PM')
          ? draftType
          : 'CM';
      _applyOcrDraft(_ocrDraft!, force: true);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Form reset to OCR result.')));
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final initialDate = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;

    final current = DateTime.tryParse(controller.text) ?? picked;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (pickedTime == null) return;

    final selected = DateTime(
      picked.year,
      picked.month,
      picked.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      controller.text = selected.toIso8601String().split('.').first;
    });
  }

  Map<String, dynamic> _buildPayload() {
    final isPm = _workOrderType == 'PM';
    final locationCode = _formControllers['locationCode']!.text.trim();

    final locationParts = locationCode.split('-');
    final institutionCode =
        locationParts.isNotEmpty && locationParts.first.isNotEmpty
        ? locationParts.first
        : locationCode;

    return <String, dynamic>{
      'wo_type': _workOrderType,
      'woType': _workOrderType,
      'wo_no': _formControllers['woNo']!.text.trim(),
      'description': _formControllers['description']!.text.trim(),
      'location_code': locationCode,
      'institution_code': institutionCode,
      'institutionCode': institutionCode,
      'asset_number': _formControllers['assetNumber']!.text.trim(),
      'serial_number': _formControllers['serialNumber']!.text.trim(),
      'device_brand': _formControllers['deviceBrand']!.text.trim(),
      'device_model': _formControllers['deviceModel']!.text.trim(),
      'contact_name': _formControllers['contactName']!.text.trim(),
      'contact_number': _formControllers['contactNumber']!.text.trim(),
      'priority': _formControllers['priority']!.text.trim(),
      'ha_created_at': _formControllers['haCreatedAt']!.text.trim(),
      'ha_outbound_at': _formControllers['haOutboundAt']!.text.trim(),
      if (!isPm)
        'cm_breakdown_at': _formControllers['cmBreakdownAt']!.text.trim(),
      if (isPm) 'pm_deadline_at': _formControllers['pmDeadlineAt']!.text.trim(),
      'remark': _formControllers['remark']!.text.trim(),
      'owner_user_id': _currentUserId,
      if (_sourceFileId.isNotEmpty) 'source_file_id': _sourceFileId,
      if (_sourceFileName.isNotEmpty) 'source_file_name': _sourceFileName,
      if (_sourceFileUrl.isNotEmpty) 'source_file_url': _sourceFileUrl,
      if (_ocrJobId.isNotEmpty) 'ocr_job_id': _ocrJobId,
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_workOrderType.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select CM or PM.')));
      return;
    }

    final isPm = _workOrderType == 'PM';
    if (_formControllers['woNo']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a work order number.')),
      );
      return;
    }

    if (_formControllers['locationCode']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location code is required.')),
      );
      return;
    }

    if (_formControllers['haCreatedAt']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('HA Created time is required.')),
      );
      return;
    }

    if (_formControllers['assetNumber']!.text.trim().isEmpty ||
        _formControllers['serialNumber']!.text.trim().isEmpty ||
        _formControllers['deviceBrand']!.text.trim().isEmpty ||
        _formControllers['deviceModel']!.text.trim().isEmpty ||
        _formControllers['contactName']!.text.trim().isEmpty ||
        _formControllers['contactNumber']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill required asset/device/contact fields.'),
        ),
      );
      return;
    }

    if (!isPm && _formControllers['cmBreakdownAt']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CM Breakdown time is required.')),
      );
      return;
    }

    if (isPm && _formControllers['pmDeadlineAt']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PM deadline time is required.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final created = await ApiController.createWorkOrder(_buildPayload());
      if (!mounted) return;
      try {
        AppState.instance.setInstitutions(
          await ApiController.listInstitutions(),
        );
      } catch (_) {}

      if (created.id.isEmpty && created.woNo.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create work order failed.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work order created successfully.')),
      );
      Navigator.of(context).pop(created);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create work order: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = LoginSessionController.instance.userInfo;
    final bool isCompactPdfActions = MediaQuery.of(context).size.width < 600;
    final bool isDesktopSplitLayout = _isDesktopSplitLayout(context);
    final formCard = _buildFormCard(isCompactPdfActions);
    final bool showDesktopSplit = isDesktopSplitLayout && _showDesktopPdf;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      drawer: AppDrawer(user: user),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Create Work Order',
          style: TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: showDesktopSplit
          ? LayoutBuilder(
              builder: (context, constraints) {
                final panelHeight = constraints.maxHeight;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: panelHeight > 0 ? panelHeight : null,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(24),
                          child: formCard,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildDesktopPdfPanel(
                        height: panelHeight > 0 ? panelHeight : 860,
                      ),
                    ),
                  ],
                );
              },
            )
          : isDesktopSplitLayout
          ? SingleChildScrollView(padding: EdgeInsets.zero, child: formCard)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: formCard,
                ),
              ),
            ),
    );
  }

  Widget _buildFormCard(bool isCompactPdfActions) {
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
                'Step 1: Attach PDF (optional)',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.start,
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _selectedPdfName.isEmpty
                        ? 'No PDF selected'
                        : 'Selected: $_selectedPdfName',
                    style: const TextStyle(color: Color(0xFF334155)),
                  ),
                  if (_selectedPdfName.isEmpty)
                    ElevatedButton(
                      onPressed: _isUploadingPdf ? null : _pickPdf,
                      child: _isUploadingPdf
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Select PDF'),
                    ),
                  if (_selectedPdfName.isNotEmpty)
                    isCompactPdfActions
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_sourceFileUrl.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [_buildViewPdfButton()],
                                  ),
                                ),
                              if (_sourceFileUrl.isNotEmpty)
                                const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  OutlinedButton(
                                    onPressed: _clearPdf,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF334155),
                                    ),
                                    child: const Text('Clear'),
                                  ),
                                  if (_ocrDraft != null)
                                    OutlinedButton(
                                      onPressed: _isUploadingPdf
                                          ? null
                                          : _resetFormToOcrDraft,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF334155,
                                        ),
                                      ),
                                      child: const Text('Reset to OCR'),
                                    ),
                                ],
                              ),
                            ],
                          )
                        : Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (_sourceFileUrl.isNotEmpty)
                                _buildViewPdfButton(),
                              OutlinedButton(
                                onPressed: _clearPdf,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF334155),
                                ),
                                child: const Text('Clear'),
                              ),
                              if (_ocrDraft != null)
                                OutlinedButton(
                                  onPressed: _isUploadingPdf
                                      ? null
                                      : _resetFormToOcrDraft,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF334155),
                                  ),
                                  child: const Text('Reset to OCR'),
                                ),
                            ],
                          ),
                ],
              ),
              if (_selectedPdfName.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'If you skip PDF upload, please complete the form manually.',
                    style: TextStyle(color: Color(0xFFB6C2D1), fontSize: 13),
                  ),
                ),
              if (_selectedPdfStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _selectedPdfStatus,
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_ocrDraft != null && _extractionMode == 'ocr')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'The text may not correct, please check',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_sourceFileName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Source file: $_sourceFileName',
                    style: const TextStyle(
                      color: Color(0xFFB6C2D1),
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                spacing: 20,
                children: [
                  const Text(
                    'Step 2: Work Order Type',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Center(
                    child: ToggleButtons(
                      isSelected: [
                        _workOrderType == 'CM',
                        _workOrderType == 'PM',
                      ],
                      onPressed: (index) {
                        if (index == 0) {
                          if (_workOrderType == 'CM') return;
                          setState(() => _workOrderType = 'CM');
                        } else {
                          if (_workOrderType == 'PM') return;
                          setState(() => _workOrderType = 'PM');
                        }
                      },
                      constraints: const BoxConstraints(
                        minHeight: 28,
                        minWidth: 56,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      children: const [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.build, size: 14),
                            SizedBox(width: 4),
                            Text('CM', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 14),
                            SizedBox(width: 4),
                            Text('PM', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text(
                'Step 3: Work Order Details',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField('Work Order No', 'woNo', required: true),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final fieldWidth = (constraints.maxWidth - 24) / 3;
                      final useDynamic = fieldWidth > 220;
                      if (useDynamic) {
                        return Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'Location Code',
                                'locationCode',
                                required: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                'Contact Name',
                                'contactName',
                                required: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                'Contact Number',
                                'contactNumber',
                                required: true,
                              ),
                            ),
                          ],
                        );
                      }
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 230,
                            child: _buildTextField(
                              'Location Code',
                              'locationCode',
                              required: true,
                            ),
                          ),
                          SizedBox(
                            width: 230,
                            child: _buildTextField(
                              'Contact Name',
                              'contactName',
                              required: true,
                            ),
                          ),
                          SizedBox(
                            width: 230,
                            child: _buildTextField(
                              'Contact Number',
                              'contactNumber',
                              required: true,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool canFitAllFields =
                      constraints.maxWidth >= (230 * 4 + 12 * 3);
                  final assetField = SizedBox(
                    width: 230,
                    child: _buildTextField(
                      'Asset Number',
                      'assetNumber',
                      required: true,
                    ),
                  );
                  final serialField = SizedBox(
                    width: 230,
                    child: _buildTextField(
                      'Serial Number',
                      'serialNumber',
                      required: true,
                    ),
                  );
                  final brandField = SizedBox(
                    width: 230,
                    child: _buildTextField(
                      'Device Brand',
                      'deviceBrand',
                      required: true,
                    ),
                  );
                  final modelField = SizedBox(
                    width: 230,
                    child: _buildTextField(
                      'Device Model',
                      'deviceModel',
                      required: true,
                    ),
                  );
                  if (canFitAllFields) {
                    return Row(
                      children: [
                        Expanded(child: assetField),
                        const SizedBox(width: 12),
                        Expanded(child: serialField),
                        const SizedBox(width: 12),
                        Expanded(child: brandField),
                        const SizedBox(width: 12),
                        Expanded(child: modelField),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: assetField),
                          const SizedBox(width: 12),
                          Expanded(child: serialField),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: brandField),
                          const SizedBox(width: 12),
                          Expanded(child: modelField),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                'Description',
                'description',
                maxLines: 3,
                required: true,
              ),
              const SizedBox(height: 12),
              _buildTextField('Remark (optional)', 'remark', maxLines: 3),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final canFitAll =
                          constraints.maxWidth >= (230 * 4 + 12 * 3);
                      final createdField = SizedBox(
                        width: 230,
                        child: _buildDateField(
                          'HA Created At',
                          'haCreatedAt',
                          required: true,
                        ),
                      );
                      final outboundField = SizedBox(
                        width: 230,
                        child: _buildDateField(
                          'HA Outbound At',
                          'haOutboundAt',
                        ),
                      );
                      final breakdownField = SizedBox(
                        width: 230,
                        child: _buildDateField(
                          _workOrderType == 'PM'
                              ? 'PM Deadline At'
                              : 'CM Breakdown At',
                          _workOrderType == 'PM'
                              ? 'pmDeadlineAt'
                              : 'cmBreakdownAt',
                          required: true,
                        ),
                      );
                      final priorityField = SizedBox(
                        width: 230,
                        child: DropdownButtonFormField<String>(
                          initialValue: _formControllers['priority']!.text,
                          items: const [
                            DropdownMenuItem(
                              value: 'normal',
                              child: Text('normal'),
                            ),
                            DropdownMenuItem(
                              value: 'critical',
                              child: Text('critical'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _formControllers['priority']!.text = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            hintStyle: TextStyle(color: Color(0xFFE2E8F0)),
                            labelStyle: TextStyle(color: Color(0xFFB6C2D1)),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      );
                      if (canFitAll) {
                        return Row(
                          children: [
                            Expanded(child: createdField),
                            const SizedBox(width: 12),
                            Expanded(child: outboundField),
                            const SizedBox(width: 12),
                            Expanded(child: breakdownField),
                            const SizedBox(width: 12),
                            Expanded(child: priorityField),
                          ],
                        );
                      }
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(width: 230, child: createdField),
                          SizedBox(width: 230, child: outboundField),
                          SizedBox(width: 230, child: breakdownField),
                          SizedBox(width: 230, child: priorityField),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _resetForm,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                      ),
                      child: const Text('Clear Form'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewPdfButton() {
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
                          : _EmbeddedSourcePdfViewer(
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
                    'Open a source PDF to preview it here while editing the form.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDateField(String label, String key, {bool required = false}) {
    return TextFormField(
      controller: _formControllers[key],
      readOnly: true,
      decoration:
          const InputDecoration(
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
          ).copyWith(
            labelText: label,
            hintStyle: const TextStyle(color: Color(0xFFE2E8F0)),
            labelStyle: const TextStyle(color: Color(0xFFB6C2D1)),
          ),
      onTap: () => _pickDateTime(_formControllers[key]!),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildTextField(
    String label,
    String key, {
    int maxLines = 1,
    bool required = false,
  }) {
    final controller = _formControllers[key]!;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        hintStyle: const TextStyle(color: Color(0xFFE2E8F0)),
        labelStyle: const TextStyle(color: Color(0xFFB6C2D1)),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              return null;
            }
          : null,
    );
  }
}

class _EmbeddedSourcePdfViewer extends StatefulWidget {
  const _EmbeddedSourcePdfViewer({
    required this.networkUrl,
    required this.networkHeaders,
  });

  final String networkUrl;
  final Map<String, String> networkHeaders;

  @override
  State<_EmbeddedSourcePdfViewer> createState() =>
      _EmbeddedSourcePdfViewerState();
}

class _EmbeddedSourcePdfViewerState extends State<_EmbeddedSourcePdfViewer> {
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

class _WebSourcePdfViewerPage extends StatelessWidget {
  const _WebSourcePdfViewerPage({
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

class _SourcePdfViewerPage extends StatefulWidget {
  const _SourcePdfViewerPage({
    this.pdfBytes,
    this.networkUrl,
    this.networkHeaders,
    required this.fileName,
    this.parseErrorHint,
  });

  final Uint8List? pdfBytes;
  final String? networkUrl;
  final Map<String, String>? networkHeaders;
  final String fileName;
  final String? parseErrorHint;
  bool get hasNetworkSource => networkUrl != null && networkUrl!.isNotEmpty;
  bool get hasMemorySource => pdfBytes != null && pdfBytes!.isNotEmpty;

  @override
  State<_SourcePdfViewerPage> createState() => _SourcePdfViewerPageState();
}

class _SourcePdfViewerPageState extends State<_SourcePdfViewerPage> {
  String? _errorMessage;
  bool _openingFallback = false;

  @override
  Widget build(BuildContext context) {
    Widget viewer = const SizedBox.shrink();
    if (_errorMessage == null) {
      if (widget.hasNetworkSource && !kIsWeb) {
        viewer = SfPdfViewer.network(
          widget.networkUrl!,
          headers: widget.networkHeaders,
          onDocumentLoadFailed: (details) {
            setState(() {
              final rawMessage = '${details.error} ${details.description}'
                  .trim();
              final hint = widget.parseErrorHint?.trim();
              if (hint == null || hint.isEmpty) {
                _errorMessage = rawMessage.isEmpty
                    ? 'Unable to load PDF.'
                    : rawMessage;
              } else if (rawMessage.isEmpty) {
                _errorMessage = hint;
              } else {
                _errorMessage = '$rawMessage\n$hint';
              }
            });
          },
        );
      } else if (widget.hasMemorySource) {
        viewer = SfPdfViewer.memory(
          widget.pdfBytes!,
          onDocumentLoadFailed: (details) {
            setState(() {
              final rawMessage = '${details.error} ${details.description}'
                  .trim();
              final hint = widget.parseErrorHint?.trim();
              if (hint == null || hint.isEmpty) {
                _errorMessage = rawMessage.isEmpty
                    ? 'Unable to load PDF.'
                    : rawMessage;
              } else if (rawMessage.isEmpty) {
                _errorMessage = hint;
              } else {
                _errorMessage = '$rawMessage\n$hint';
              }
            });
          },
        );
      } else {
        viewer = const Center(child: Text('No PDF source is available.'));
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
        title: Text(widget.fileName.isEmpty ? 'View PDF' : widget.fileName),
      ),
      backgroundColor: Colors.white,
      body: SfTheme(
        data: SfThemeData(
          pdfViewerThemeData: SfPdfViewerThemeData(
            backgroundColor: Colors.white,
          ),
        ),
        child: Container(color: Colors.white, child: viewer),
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
              content: Text('No PDF bytes available to open locally.'),
            ),
          );
          return;
        }
        final dataUri = Uri.dataFromBytes(
          sourceBytes,
          mimeType: 'application/pdf',
        );
        final launched = await launchUrl(
          dataUri,
          mode: LaunchMode.platformDefault,
        );
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app found to open PDF file.')),
          );
        }
        return;
      }

      if (widget.pdfBytes == null && widget.hasNetworkSource) {
        final uri = Uri.parse(widget.networkUrl!);
        final response = await http.get(uri, headers: widget.networkHeaders);
        if (response.statusCode != 200) {
          throw Exception(
            'Open PDF failed (${response.statusCode}): ${response.reasonPhrase ?? 'Request error'}',
          );
        }
        sourceBytes = Uint8List.fromList(response.bodyBytes);
      } else if (widget.pdfBytes != null) {
        sourceBytes = widget.pdfBytes;
      }

      final tempFile = File(
        '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      if (sourceBytes == null || sourceBytes.isEmpty) {
        throw Exception('No PDF content available.');
      }
      await tempFile.writeAsBytes(sourceBytes, flush: true);
      final opened = await launchUrl(
        Uri.file(tempFile.path),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No app found to open PDF file on this device.'),
          ),
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
