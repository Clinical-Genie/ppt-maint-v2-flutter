import 'package:flutter/material.dart';
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
  static const String _serverManagedWorkingDateKey = 'working_date';
  static const double _workOrderInfoFontSize = 14;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  FormTemplate? _selectedTemplate;
  WorkOrderForm _workOrderForm = WorkOrderForm();
  Map<String, dynamic> _baseDataJson = {};
  final Map<String, FormTemplateChoiceGroupDetail> _choiceGroupByCode = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<_DynamicTableRow>> _tableRows = {};
  final Map<String, List<_DynamicChoiceSelection>> _multiSelectWithRemarks = {};
  final Map<String, bool> _boolValues = {};
  final Map<String, Set<String>> _checkboxGroupValues = {};
  final Map<String, String> _radioValues = {};

  bool get _isCompletedEditMode =>
      widget.workOrder.status.trim().toLowerCase() == 'completed';

  List<FormTemplateField> get _editableFields {
    return _selectedTemplate?.schema.fields
            .where(
              (field) =>
                  field.isFillStage &&
                  field.key.trim() != _serverManagedWorkingDateKey,
            )
            .toList() ??
        const <FormTemplateField>[];
  }

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
      WorkOrderForm form;
      FormTemplate selectedTemplate;

      try {
        form = await ApiController.getWorkOrderForm(widget.workOrder.id);
        if (form.templateId.trim().isEmpty) {
          throw Exception('Template is missing from existing form.');
        }
        selectedTemplate = await ApiController.getFormTemplateById(
          form.templateId,
        );
      } catch (_) {
        if (_isCompletedEditMode) {
          throw Exception(
            'No submitted report form found for this completed work order.',
          );
        }
        final templates = await ApiController.listFormTemplates(
          type: widget.workOrder.woType.trim().toUpperCase(),
        );
        if (templates.items.isEmpty) {
          throw Exception('No form template available.');
        }

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
        form = await ApiController.createWorkOrderForm(
          widget.workOrder.id,
          selectedTemplate.id,
        );
      }

      await _loadChoiceGroupsForTemplate(selectedTemplate.schema);

      _selectedTemplate = selectedTemplate;
      _workOrderForm = form;
      _baseDataJson = Map<String, dynamic>.from(form.dataJson);
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

    for (final field in schema.fields.where(
      (item) =>
          item.isFillStage && item.key.trim() != _serverManagedWorkingDateKey,
    )) {
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
        } else {
          controller.text = rawValue;
        }
        _controllers[field.key] = controller;
      }
    }
  }

  Map<String, dynamic> _buildDataJson() {
    final output = Map<String, dynamic>.from(_baseDataJson);
    output.remove(_serverManagedWorkingDateKey);
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
      _baseDataJson = Map<String, dynamic>.from(_workOrderForm.dataJson);
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
      if (!_isCompletedEditMode) {
        _workOrderForm = await ApiController.saveWorkOrderFormDraft(
          widget.workOrder.id,
          dataJson,
        );
        _baseDataJson = Map<String, dynamic>.from(_workOrderForm.dataJson);
      }
      final message = _isCompletedEditMode
          ? await ApiController.updateWorkOrderForm(
              widget.workOrder.id,
              dataJson: dataJson,
            )
          : await ApiController.submitWorkOrderForm(
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _fieldLabel(FormTemplateField field) {
    return field.required ? field.label : '${field.label} (Optional)';
  }

  Widget _buildWorkOrderInfoBlock() {
    final locationCode = widget.workOrder.locationCode.trim();
    final locationParts = locationCode.split('-');
    final locationPrefix = locationParts.isNotEmpty ? locationParts.first : '';
    final locationRest =
        locationPrefix.isNotEmpty && locationCode.startsWith(locationPrefix)
        ? locationCode.substring(locationPrefix.length)
        : locationCode;

    final deviceText = [
      if (widget.workOrder.deviceBrand.trim().isNotEmpty)
        widget.workOrder.deviceBrand.trim(),
      if (widget.workOrder.deviceModel.trim().isNotEmpty)
        widget.workOrder.deviceModel.trim(),
    ].join(' - ');

    final contactText = [
      if (widget.workOrder.contactName.trim().isNotEmpty)
        widget.workOrder.contactName.trim(),
      if (widget.workOrder.contactNumber.trim().isNotEmpty)
        '(${widget.workOrder.contactNumber.trim()})',
    ].join(' ');

    final infoRows = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.location_on_outlined,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectionArea(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: _workOrderInfoFontSize,
                    color: Color(0xFF0F172A),
                  ),
                  children: [
                    TextSpan(
                      text: locationPrefix,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    TextSpan(text: locationRest),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      if (deviceText.isNotEmpty)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.memory_outlined,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectionArea(
                child: SelectableText(
                  deviceText,
                  style: const TextStyle(
                    fontSize: _workOrderInfoFontSize,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ],
        ),
      if (widget.workOrder.assetNumber.trim().isNotEmpty ||
          widget.workOrder.serialNumber.trim().isNotEmpty)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.numbers_outlined,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectionArea(
                child: SelectableText(
                  'Asset No: ${widget.workOrder.assetNumber.trim()}, S/N: ${widget.workOrder.serialNumber.trim()}',
                  style: const TextStyle(
                    fontSize: _workOrderInfoFontSize,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ),
          ],
        ),
      if (contactText.isNotEmpty)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.phone_outlined,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectionArea(
                child: SelectableText(
                  contactText,
                  style: const TextStyle(
                    fontSize: _workOrderInfoFontSize,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectionArea(
          child: SelectableText(
            '${widget.workOrder.woNo.trim()} (${widget.workOrder.woType.trim().toUpperCase()})',
            style: const TextStyle(
              fontSize: _workOrderInfoFontSize,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final useTwoColumns = constraints.maxWidth >= 860;
            if (!useTwoColumns) {
              return Column(
                children: [
                  for (var i = 0; i < infoRows.length; i++) ...[
                    infoRows[i],
                    if (i < infoRows.length - 1) const SizedBox(height: 8),
                  ],
                ],
              );
            }
            final itemWidth = (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final item in infoRows) SizedBox(width: itemWidth, child: item),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFieldWidget(FormTemplateField field) {
    Widget wrapWithQuickChoices({required Widget child}) {
      final group = _choiceGroupByCode[field.choiceGroupCode.trim()];
      final groupItems = group?.items ?? const <FormTemplateChoiceItem>[];
      final fallbackOptions = field.options;
      final hasChoices = groupItems.isNotEmpty || fallbackOptions.isNotEmpty;
      if (field.choiceGroupCode.trim().isEmpty || !hasChoices) {
        return child;
      }
      final controller = _controllers[field.key];
      if (controller == null) {
        return child;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () async {
                final selectedText = await showDialog<String>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: Text('Select ${_fieldLabel(field)}'),
                      content: SizedBox(
                        width: 420,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: groupItems.isNotEmpty
                              ? groupItems.length
                              : fallbackOptions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final insertText = groupItems.isNotEmpty
                                ? (() {
                                    final option = groupItems[index];
                                    if (option.labelEn.trim().isNotEmpty) {
                                      return option.labelEn.trim();
                                    }
                                    if (option.labelZh.trim().isNotEmpty) {
                                      return option.labelZh.trim();
                                    }
                                    return option.code.trim();
                                  })()
                                : (() {
                                    final option = fallbackOptions[index];
                                    if (option.label.trim().isNotEmpty) {
                                      return option.label.trim();
                                    }
                                    if (option.labelEn.trim().isNotEmpty) {
                                      return option.labelEn.trim();
                                    }
                                    if (option.labelZh.trim().isNotEmpty) {
                                      return option.labelZh.trim();
                                    }
                                    return option.value.trim();
                                  })();
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
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    if (field.type == 'checkbox' || field.type == 'boolean') {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _boolValues[field.key] ?? false,
        title: Text(_fieldLabel(field)),
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
          _buildSectionTitle(_fieldLabel(field)),
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
          _buildSectionTitle(_fieldLabel(field)),
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
            labelText: _fieldLabel(field),
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
          labelText: _fieldLabel(field),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 720;
                  final removeButton = IconButton(
                    onPressed: () {
                      setState(() {
                        row.dispose();
                        rows.removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.delete_outline),
                  );

                  final fieldWidgets = columns.map((column) {
                    final key = '${column['key'] ?? ''}'.trim();
                    return TextFormField(
                      controller: row.controllers[key],
                      decoration: InputDecoration(
                        labelText: '${column['label'] ?? key}',
                        border: const OutlineInputBorder(),
                      ),
                    );
                  }).toList();

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...fieldWidgets.map(
                          (fieldWidget) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: fieldWidget,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: removeButton,
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...fieldWidgets.map(
                        (fieldWidget) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: fieldWidget,
                          ),
                        ),
                      ),
                      removeButton,
                    ],
                  );
                },
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
          _buildSectionTitle(_fieldLabel(field)),
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
          labelText: _fieldLabel(field),
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
          _isCompletedEditMode
              ? 'Edit Report'
              : _selectedTemplate?.name.isNotEmpty == true
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
                          _buildWorkOrderInfoBlock(),
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
                          ..._editableFields.map(
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
          child: _isCompletedEditMode
              ? FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                )
              : Row(
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Ready To Sign'),
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
