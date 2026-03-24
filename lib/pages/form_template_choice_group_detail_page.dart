import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/form_template_choice_group.dart';

class FormTemplateChoiceGroupDetailPage extends StatefulWidget {
  const FormTemplateChoiceGroupDetailPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<FormTemplateChoiceGroupDetailPage> createState() =>
      _FormTemplateChoiceGroupDetailPageState();
}

class _FormTemplateChoiceGroupDetailPageState
    extends State<FormTemplateChoiceGroupDetailPage> {
  bool _isLoading = true;
  bool _includeInactive = false;
  bool _changed = false;
  FormTemplateChoiceGroupDetail _group = FormTemplateChoiceGroupDetail();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final group = await ApiController.getFormTemplateChoiceGroup(
        widget.groupId,
        includeInactive: _includeInactive,
      );
      if (!mounted) return;
      setState(() => _group = group);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openChoiceItemDialog({FormTemplateChoiceItem? item}) async {
    final codeController = TextEditingController(text: item?.code ?? '');
    final labelEnController = TextEditingController(text: item?.labelEn ?? '');
    final labelZhController = TextEditingController(text: item?.labelZh ?? '');
    final sortController = TextEditingController(
      text: item == null ? '1' : item.sort.toString(),
    );
    final metaController = TextEditingController(
      text: item == null || item.metaJson.isEmpty ? '{}' : jsonEncode(item.metaJson),
    );
    bool isActive = item?.isActive ?? true;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(item == null ? 'Add Choice Item' : 'Edit Choice Item'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codeController,
                        enabled: item == null && !submitting,
                        decoration: const InputDecoration(
                          labelText: 'Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: labelEnController,
                        enabled: !submitting,
                        decoration: const InputDecoration(
                          labelText: 'Label (EN)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: labelZhController,
                        enabled: !submitting,
                        decoration: const InputDecoration(
                          labelText: 'Label (ZH)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: sortController,
                        enabled: !submitting,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sort',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: metaController,
                        enabled: !submitting,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Meta JSON',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        onChanged: submitting
                            ? null
                            : (value) => setDialogState(() => isActive = value),
                        title: const Text('Active'),
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
                  onPressed: submitting
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          final labelEn = labelEnController.text.trim();
                          if (code.isEmpty && item == null) return;
                          if (labelEn.isEmpty) return;
                          Map<String, dynamic> metaJson = {};
                          final rawMeta = metaController.text.trim();
                          if (rawMeta.isNotEmpty) {
                            final decoded = jsonDecode(rawMeta);
                            if (decoded is Map) {
                              metaJson = Map<String, dynamic>.from(decoded);
                            }
                          }
                          setDialogState(() => submitting = true);
                          try {
                            if (item == null) {
                              await ApiController.addFormTemplateChoiceItem(
                                widget.groupId,
                                code: code,
                                labelEn: labelEn,
                                labelZh: labelZhController.text.trim(),
                                sort: int.tryParse(sortController.text.trim()) ?? 0,
                                isActive: isActive,
                                metaJson: metaJson,
                              );
                            } else {
                              await ApiController.updateFormTemplateChoiceItem(
                                widget.groupId,
                                item.id,
                                labelEn: labelEn,
                                labelZh: labelZhController.text.trim(),
                                sort: int.tryParse(sortController.text.trim()) ?? 0,
                                isActive: isActive,
                                metaJson: metaJson,
                              );
                            }
                            _changed = true;
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            await _load();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                            setDialogState(() => submitting = false);
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deactivateItem(FormTemplateChoiceItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate choice item'),
          content: Text('Deactivate "${item.labelEn}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final message = await ApiController.deactivateFormTemplateChoiceItem(
      widget.groupId,
      item.id,
    );
    _changed = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_group.name.isNotEmpty ? _group.name : 'Choice Group'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          actions: [
            Switch(
              value: _includeInactive,
              onChanged: (value) {
                setState(() => _includeInactive = value);
                _load();
              },
            ),
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: Text('Include inactive')),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openChoiceItemDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Item'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _group.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(_group.code),
                          if (_group.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(_group.description),
                          ],
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(_group.isActive ? 'Active' : 'Inactive'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._group.items.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item.labelEn.isNotEmpty ? item.labelEn : item.code),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item.code),
                            if (item.labelZh.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(item.labelZh),
                            ],
                            const SizedBox(height: 4),
                            Text('Sort: ${item.sort}'),
                            if (item.metaJson.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Meta: ${jsonEncode(item.metaJson)}'),
                            ],
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              label: Text(item.isActive ? 'Active' : 'Inactive'),
                            ),
                            IconButton(
                              onPressed: () => _openChoiceItemDialog(item: item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed:
                                  item.isActive ? () => _deactivateItem(item) : null,
                              icon: const Icon(Icons.block_outlined),
                            ),
                          ],
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
