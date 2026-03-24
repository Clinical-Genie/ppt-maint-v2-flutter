import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/form_template.dart';
import 'package:maintapp/model/form_template_choice_group.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/model/work_order_form.dart';

class WorkOrderReportFormPage extends StatefulWidget {
  const WorkOrderReportFormPage({required this.workOrder, super.key});

  final WorkOrder workOrder;

  @override
  State<WorkOrderReportFormPage> createState() =>
      _WorkOrderReportFormPageState();
}

class _WorkOrderReportFormPageState extends State<WorkOrderReportFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  FormTemplate? _selectedTemplate;
  WorkOrderForm _workOrderForm = WorkOrderForm();
  final Map<String, FormTemplateChoiceGroupDetail> _choiceGroupByCode = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<_DynamicTableRow>> _tableRows = {};
  final Map<String, List<_DynamicChoiceSelection>> _multiSelectWithRemarks = {};
  final Map<String, bool> _boolValues = {};
  final Map<String, Set<String>> _checkboxGroupValues = {};
  final Map<String, String> _radioValues = {};

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final rows in _tableRows.values) {
      for (final row in rows) {
        row.dispose();
      }
    }
    for (final items in _multiSelectWithRemarks.values) {
      for (final item in items) {
        item.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() => _isLoading = true);
    try {
      final templates = await ApiController.listFormTemplates(
        type: widget.workOrder.woType.trim().toUpperCase(),
      );
      if (templates.items.isEmpty) {
        throw Exception('No form template available.');
      }

      FormTemplate selectedTemplate;
      if (templates.items.length == 1) {
        selectedTemplate = templates.items.first;
      } else {
        final pickedId = await _pickTemplate(templates.items);
        if (pickedId == null || pickedId.isEmpty) {
          if (mounted) {
            Navigator.of(context).pop(false);
          }
          return;
        }
        selectedTemplate = templates.items.firstWhere(
          (item) => item.id == pickedId,
          orElse: () => templates.items.first,
        );
      }

      if (selectedTemplate.schema.fields.isEmpty) {
        selectedTemplate = await ApiController.getFormTemplateById(
          selectedTemplate.id,
        );
      }

      await _loadChoiceGroupsForTemplate(selectedTemplate.schema);

      final form = await ApiController.createWorkOrderForm(
        widget.workOrder.id,
        selectedTemplate.id,
      );

      _selectedTemplate = selectedTemplate;
      _workOrderForm = form;
      _applyDataJson(selectedTemplate.schema, form.dataJson);
    } catch (e) {
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

  Future<void> _loadChoiceGroupsForTemplate(FormTemplateSchema schema) async {
    _choiceGroupByCode.clear();
    final codes = schema.fields
        .map((field) => field.choiceGroupCode.trim())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList();
    for (final code in codes) {
      final group = await ApiController.getFormTemplateChoiceGroupByCode(code);
      if (group != null) {
        _choiceGroupByCode[code] = group;
      }
    }
  }

  Future<String?> _pickTemplate(List<FormTemplate> templates) {
    String selectedId = templates.first.id;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select report template'),
              content: DropdownButtonFormField<String>(
                initialValue: selectedId,
                items: templates
                    .map(
                      (template) => DropdownMenuItem<String>(
                        value: template.id,
                        child: Text('${template.name} (v${template.version})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null || value.isEmpty) return;
                  setDialogState(() => selectedId = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Template',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selectedId),
                  child: const Text('Use'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyDataJson(FormTemplateSchema schema, Map<String, dynamic> data) {
    final sourceData = {...schema.defaultDataJson, ...data};

    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    for (final rows in _tableRows.values) {
      for (final row in rows) {
        row.dispose();
      }
    }
    _tableRows.clear();

    for (final items in _multiSelectWithRemarks.values) {
      for (final item in items) {
        item.dispose();
      }
    }
    _multiSelectWithRemarks.clear();
    _boolValues.clear();
    _checkboxGroupValues.clear();
    _radioValues.clear();

    for (final field in schema.fields) {
      if (field.type == 'table') {
        final rows = <_DynamicTableRow>[];
        final rawRows = sourceData[field.key];
        if (rawRows is List && rawRows.isNotEmpty) {
          for (final item in rawRows.whereType<Map>()) {
            rows.add(
              _DynamicTableRow.fromMap(field, Map<String, dynamic>.from(item)),
            );
          }
        }
        if (rows.isEmpty) {
          rows.add(_DynamicTableRow(field));
        }
        _tableRows[field.key] = rows;
      } else if (field.type == 'checkbox' || field.type == 'boolean') {
        final rawValue = sourceData[field.key];
        _boolValues[field.key] = rawValue is bool
            ? rawValue
            : '$rawValue'.toLowerCase() == 'true' || '$rawValue' == '1';
      } else if (field.type == 'checkbox_group') {
        final selected = <String>{};
        final rawValue = sourceData[field.key];
        if (rawValue is List) {
          for (final item in rawValue) {
            final value = '$item'.trim();
            if (value.isNotEmpty) {
              selected.add(value);
            }
          }
        }
        _checkboxGroupValues[field.key] = selected;
      } else if (field.type == 'radio_group') {
        _radioValues[field.key] = '${sourceData[field.key] ?? ''}'.trim();
      } else if (field.type == 'multiselect_with_remarks') {
        final selectedItems = <_DynamicChoiceSelection>[];
        final rawItems = sourceData[field.key];
        if (rawItems is List) {
          for (final item in rawItems.whereType<Map>()) {
            selectedItems.add(
              _DynamicChoiceSelection.fromMap(Map<String, dynamic>.from(item)),
            );
          }
        }
        _multiSelectWithRemarks[field.key] = selectedItems;
      } else {
        final controller = TextEditingController();
        final rawValue = '${sourceData[field.key] ?? ''}'.trim();
        if (field.type == 'date' && rawValue.isNotEmpty) {
          controller.text = rawValue.split('T').first;
        } else if (field.type == 'date' && field.key == 'working_date') {
          controller.text = DateTime.now().toIso8601String().split('T').first;
        } else {
          controller.text = rawValue;
        }
        _controllers[field.key] = controller;
      }
    }
  }

  Map<String, dynamic> _buildDataJson() {
    final output = <String, dynamic>{};
    _controllers.forEach((key, controller) {
      output[key] = controller.text.trim();
    });
    _tableRows.forEach((key, rows) {
      output[key] = rows
          .map((row) => row.toMap())
          .where(
            (item) => item.values.any((value) => '$value'.trim().isNotEmpty),
          )
          .toList();
    });
    _multiSelectWithRemarks.forEach((key, items) {
      output[key] = items
          .where((item) => item.selected)
          .map((item) => item.toMap())
          .toList();
    });
    _boolValues.forEach((key, value) {
      output[key] = value;
    });
    _checkboxGroupValues.forEach((key, values) {
      output[key] = values.toList();
    });
    _radioValues.forEach((key, value) {
      output[key] = value;
    });
    return output;
  }

  Future<void> _pickDateForController(TextEditingController controller) async {
    final initialDate =
        DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      controller.text = picked.toIso8601String().split('T').first;
    });
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      _workOrderForm = await ApiController.saveWorkOrderFormDraft(
        widget.workOrder.id,
        _buildDataJson(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final dataJson = _buildDataJson();
      await ApiController.saveWorkOrderFormDraft(widget.workOrder.id, dataJson);
      final message = await ApiController.submitWorkOrderForm(
        widget.workOrder.id,
        dataJson: dataJson,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectionArea(
            child: SelectableText(
              value.trim().isEmpty ? '-' : value.trim(),
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildFieldWidget(FormTemplateField field) {
    Widget wrapWithQuickChoices({required Widget child}) {
      final group = _choiceGroupByCode[field.choiceGroupCode.trim()];
      final options = group?.items ?? const <FormTemplateChoiceItem>[];
      if (field.choiceGroupCode.trim().isEmpty || options.isEmpty) {
        return child;
      }
      final controller = _controllers[field.key];
      if (controller == null) {
        return child;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: child),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final selectedText = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        title: Text('Select ${field.label}'),
                        content: SizedBox(
                          width: 420,
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final option = options[index];
                              final insertText =
                                  option.labelEn.trim().isNotEmpty
                                  ? option.labelEn.trim()
                                  : option.labelZh.trim().isNotEmpty
                                  ? option.labelZh.trim()
                                  : option.code.trim();
                              return ListTile(
                                title: Text(insertText),
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(insertText),
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ],
                      );
                    },
                  );
                  if (selectedText == null || selectedText.isEmpty) return;
                  setState(() {
                    controller.text = selectedText;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  minimumSize: const Size(44, 44),
                ),
                child: const Icon(Icons.list_alt_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    if (field.type == 'checkbox' || field.type == 'boolean') {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _boolValues[field.key] ?? false,
        title: Text(field.label),
        onChanged: (value) {
          setState(() {
            _boolValues[field.key] = value ?? false;
          });
        },
      );
    }
    if (field.type == 'checkbox_group') {
      final selected = _checkboxGroupValues.putIfAbsent(
        field.key,
        () => <String>{},
      );
      final group = _choiceGroupByCode[field.choiceGroupCode.trim()];
      final choiceItems = group?.items ?? const <FormTemplateChoiceItem>[];
      final runtimeOptions = choiceItems.isNotEmpty
          ? choiceItems
                .map(
                  (item) => FormTemplateFieldOption.fromJson({
                    'value': item.code,
                    'label': item.labelEn,
                  }),
                )
                .toList()
          : field.options;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(field.label),
          ...runtimeOptions.map(
            (option) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected.contains(option.value),
              title: Text(
                option.label.isNotEmpty ? option.label : option.value,
              ),
              onChanged: (value) {
                setState(() {
                  if (value ?? false) {
                    selected.add(option.value);
                  } else {
                    selected.remove(option.value);
                  }
                });
              },
            ),
          ),
        ],
      );
    }
    if (field.type == 'radio_group') {
      final currentValue = _radioValues[field.key] ?? '';
      final group = _choiceGroupByCode[field.choiceGroupCode.trim()];
      final choiceItems = group?.items ?? const <FormTemplateChoiceItem>[];
      final runtimeOptions = choiceItems.isNotEmpty
          ? choiceItems
                .map(
                  (item) => FormTemplateFieldOption.fromJson({
                    'value': item.code,
                    'label': item.labelEn,
                  }),
                )
                .toList()
          : field.options;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(field.label),
          ...runtimeOptions.map(
            (option) => RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: option.value,
              groupValue: currentValue,
              title: Text(
                option.label.isNotEmpty ? option.label : option.value,
              ),
              onChanged: (value) {
                setState(() {
                  _radioValues[field.key] = value ?? '';
                });
              },
            ),
          ),
        ],
      );
    }
    if (field.type == 'textarea') {
      return wrapWithQuickChoices(
        child: TextFormField(
          controller: _controllers[field.key],
          maxLines: 4,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }
    if (field.type == 'date') {
      return TextFormField(
        controller: _controllers[field.key],
        readOnly: true,
        onTap: () => _pickDateForController(_controllers[field.key]!),
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.event_outlined),
        ),
        validator: field.required
            ? (value) {
                if (value == null || value.trim().isEmpty) return 'Required';
                return null;
              }
            : null,
      );
    }
    if (field.type == 'table') {
      final rows = _tableRows[field.key] ?? [];
      final rawColumns = field.raw['columns'];
      final columns = rawColumns is List
          ? rawColumns.whereType<Map>().toList()
          : <Map>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle(field.label),
              TextButton.icon(
                onPressed: () {
                  setState(() => rows.add(_DynamicTableRow(field)));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add row'),
              ),
            ],
          ),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...columns.map((column) {
                    final key = '${column['key'] ?? ''}'.trim();
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextFormField(
                          controller: row.controllers[key],
                          decoration: InputDecoration(
                            labelText: '${column['label'] ?? key}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    );
                  }),
                  IconButton(
                    onPressed: rows.length == 1
                        ? null
                        : () {
                            setState(() {
                              row.dispose();
                              rows.removeAt(index);
                            });
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }
    if (field.type == 'multiselect_with_remarks') {
      final selectedItems = _multiSelectWithRemarks[field.key] ?? [];
      final group = _choiceGroupByCode[field.choiceGroupCode.trim()];
      final choiceItems = group?.items ?? const <FormTemplateChoiceItem>[];
      final runtimeOptions = choiceItems.isNotEmpty
          ? choiceItems
                .map(
                  (item) => FormTemplateFieldOption.fromJson({
                    'value': item.code,
                    'label': item.labelEn,
                  }),
                )
                .toList()
          : field.options;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(field.label),
          ...runtimeOptions.map((option) {
            _DynamicChoiceSelection current;
            final matchIndex = selectedItems.indexWhere(
              (item) => item.value == option.value,
            );
            if (matchIndex >= 0) {
              current = selectedItems[matchIndex];
            } else {
              current = _DynamicChoiceSelection(
                value: option.value,
                label: option.label.isNotEmpty ? option.label : option.value,
              );
              selectedItems.add(current);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: current.selected,
                    title: Text(
                      option.label.isNotEmpty ? option.label : option.value,
                    ),
                    onChanged: (value) {
                      setState(() => current.selected = value ?? false);
                    },
                  ),
                  if (current.selected)
                    TextFormField(
                      controller: current.remarkController,
                      decoration: const InputDecoration(
                        labelText: 'Remark',
                        border: OutlineInputBorder(),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      );
    }

    return wrapWithQuickChoices(
      child: TextFormField(
        controller: _controllers[field.key],
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
        ),
        validator: field.required
            ? (value) {
                if (value == null || value.trim().isEmpty) return 'Required';
                return null;
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTemplate?.name.isNotEmpty == true
              ? _selectedTemplate!.name
              : _workOrderForm.reportNo.isNotEmpty
              ? _workOrderForm.reportNo
              : 'Fill Report',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Work Order Information'),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: 220,
                                child: _buildReadOnlyField(
                                  'Reference',
                                  widget.workOrder.woNo,
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: _buildReadOnlyField(
                                  'Asset Number',
                                  widget.workOrder.assetNumber,
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: _buildReadOnlyField(
                                  'Brand',
                                  widget.workOrder.deviceBrand,
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: _buildReadOnlyField(
                                  'Serial Number',
                                  widget.workOrder.serialNumber,
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: _buildReadOnlyField(
                                  'Product Model',
                                  widget.workOrder.deviceModel,
                                ),
                              ),
                              SizedBox(
                                width: 320,
                                child: _buildReadOnlyField(
                                  'Customer',
                                  widget.workOrder.locationCode,
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: _buildReadOnlyField(
                                  'Contact',
                                  widget.workOrder.contactName,
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                child: _buildReadOnlyField(
                                  'Tel',
                                  widget.workOrder.contactNumber,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Report Form'),
                          ...?_selectedTemplate?.schema.fields.map(
                            (field) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildFieldWidget(field),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _saveDraft,
                  child: const Text('Save Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkOrderSignPage extends StatefulWidget {
  const WorkOrderSignPage({required this.workOrder, super.key});

  final WorkOrder workOrder;

  @override
  State<WorkOrderSignPage> createState() => _WorkOrderSignPageState();
}

class _WorkOrderSignPageState extends State<WorkOrderSignPage> {
  final _formKey = GlobalKey<FormState>();
  final _signedNameController = TextEditingController();
  final _signedPositionController = TextEditingController();
  final _points = <Offset?>[];
  final _boundaryKey = GlobalKey();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _signedNameController.dispose();
    _signedPositionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_points.whereType<Offset>().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a signature first.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Signature canvas is not ready.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Unable to generate signature image.');
      }
      final bytes = byteData.buffer.asUint8List();
      final message = await ApiController.signWorkOrderForm(
        widget.workOrder.id,
        signedName: _signedNameController.text.trim(),
        signedPosition: _signedPositionController.text.trim(),
        signatureBytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Report')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _signedNameController,
              decoration: const InputDecoration(
                labelText: 'Staff Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signedPositionController,
              decoration: const InputDecoration(
                labelText: 'Staff ID / Position',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GestureDetector(
                  onPanStart: (details) {
                    final box =
                        _boundaryKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(details.globalPosition);
                    setState(() => _points.add(local));
                  },
                  onPanUpdate: (details) {
                    final box =
                        _boundaryKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(details.globalPosition);
                    setState(() => _points.add(local));
                  },
                  onPanEnd: (_) {
                    setState(() => _points.add(null));
                  },
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: CustomPaint(
                      painter: _SignaturePainter(List<Offset?>.from(_points)),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _points.clear()),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Signature'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DynamicTableRow {
  final Map<String, TextEditingController> controllers = {};

  _DynamicTableRow(FormTemplateField field) {
    final columns = field.raw['columns'];
    if (columns is List) {
      for (final item in columns.whereType<Map>()) {
        final key = '${item['key'] ?? ''}'.trim();
        if (key.isNotEmpty) {
          controllers[key] = TextEditingController();
        }
      }
    }
  }

  _DynamicTableRow.fromMap(FormTemplateField field, Map<String, dynamic> map) {
    final columns = field.raw['columns'];
    if (columns is List) {
      for (final item in columns.whereType<Map>()) {
        final key = '${item['key'] ?? ''}'.trim();
        if (key.isNotEmpty) {
          controllers[key] = TextEditingController(
            text: '${map[key] ?? ''}'.trim(),
          );
        }
      }
    }
  }

  Map<String, dynamic> toMap() {
    final output = <String, dynamic>{};
    controllers.forEach((key, controller) {
      output[key] = controller.text.trim();
    });
    return output;
  }

  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

class _DynamicChoiceSelection {
  _DynamicChoiceSelection({
    required this.value,
    required this.label,
    this.selected = false,
    String remark = '',
  }) : remarkController = TextEditingController(text: remark);

  factory _DynamicChoiceSelection.fromMap(Map<String, dynamic> map) {
    return _DynamicChoiceSelection(
      value: '${map['value'] ?? ''}'.trim(),
      label: '${map['label'] ?? ''}'.trim(),
      selected: true,
      remark: '${map['remark'] ?? ''}'.trim(),
    );
  }

  final String value;
  final String label;
  bool selected;
  final TextEditingController remarkController;

  Map<String, dynamic> toMap() => {
    'value': value,
    'label': label,
    'remark': remarkController.text.trim(),
  };

  void dispose() {
    remarkController.dispose();
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

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
