import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/login_session_controller.dart';

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
  WorkOrder? _ocrDraft;

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
      _selectedPdfStatus = ocrResult.ok
          ? 'OCR done'
          : 'OCR completed with limited results';
      _sourceFileId = ocrResult.sourceFileId;
      _sourceFileName = ocrResult.sourceFileName;
      _sourceFileUrl = ocrResult.sourceFileUrl;
      _ocrJobId = ocrResult.ocrJobId;
      _ocrDraft = ocrResult.workOrderDraft;

      _applyOcrDraft(ocrResult.workOrderDraft);

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
      _ocrDraft = null;
      _workOrderType = 'CM';
    });
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
      _setText('priority', draft.priority.isNotEmpty ? draft.priority : 'normal');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No OCR draft available.')),
      );
      return;
    }
    setState(() {
      _workOrderType = 'CM';
      _applyOcrDraft(_ocrDraft!, force: true);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Form reset to OCR result.')),
    );
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Card(
              color: Colors.white,
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedPdfName.isEmpty
                                  ? 'No PDF selected'
                                  : 'Selected: $_selectedPdfName',
                              style: const TextStyle(color: Color(0xFF334155)),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isUploadingPdf ? null : _pickPdf,
                            child: _isUploadingPdf
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Select PDF'),
                          ),
                          const SizedBox(width: 12),
                          if (_selectedPdfName.isNotEmpty)
                            TextButton(
                              onPressed: _clearPdf,
                              child: const Text('Clear'),
                            ),
                          if (_ocrDraft != null)
                            TextButton(
                              onPressed:
                                  _isUploadingPdf ? null : _resetFormToOcrDraft,
                              child: const Text('Reset to OCR'),
                            ),
                        ],
                      ),
                      if (_selectedPdfName.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'If you skip PDF upload, please complete the form manually.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
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
                      if (_sourceFileName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Source file: $_sourceFileName',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'Step 2: Work Order Type',
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _workOrderType,
                        items: _workOrderTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _workOrderType = value);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Work Order Type',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Select CM or PM'
                            : null,
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
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 230,
                            child: _buildTextField(
                              'Asset Number',
                              'assetNumber',
                              required: true,
                            ),
                          ),
                          SizedBox(
                            width: 230,
                            child: _buildTextField(
                              'Serial Number',
                              'serialNumber',
                              required: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 230,
                            child: _buildTextField(
                              'Device Brand',
                              'deviceBrand',
                              required: true,
                            ),
                          ),
                          SizedBox(
                            width: 230,
                            child: _buildTextField(
                              'Device Model',
                              'deviceModel',
                              required: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Description',
                        'description',
                        maxLines: 3,
                        required: true,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Remark (optional)',
                        'remark',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 230,
                            child: _buildDateField(
                              'HA Created At',
                              'haCreatedAt',
                              required: true,
                            ),
                          ),
                          SizedBox(
                            width: 230,
                            child: _buildDateField(
                              'HA Outbound At',
                              'haOutboundAt',
                            ),
                          ),
                          SizedBox(
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 230,
                            child: DropdownButtonFormField<String>(
                              value: _formControllers['priority']!.text,
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
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _isLoading ? null : _resetForm,
                              child: const Text('Clear Form'),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Create Work Order'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.calendar_today),
      ).copyWith(labelText: label),
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
