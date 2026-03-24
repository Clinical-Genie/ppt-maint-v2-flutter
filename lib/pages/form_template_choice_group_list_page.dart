import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/form_template_choice_group.dart';
import 'package:maintapp/pages/form_template_choice_group_detail_page.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/login_session_controller.dart';

class FormTemplateChoiceGroupListPage extends StatefulWidget {
  const FormTemplateChoiceGroupListPage({super.key});

  @override
  State<FormTemplateChoiceGroupListPage> createState() =>
      _FormTemplateChoiceGroupListPageState();
}

class _FormTemplateChoiceGroupListPageState
    extends State<FormTemplateChoiceGroupListPage> {
  bool _isLoading = false;
  bool _includeInactive = false;
  FormTemplateChoiceGroupList _result = FormTemplateChoiceGroupList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiController.listFormTemplateChoiceGroups(
        includeInactive: _includeInactive,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openCreateOrEditGroup({
    FormTemplateChoiceGroupSummary? group,
  }) async {
    final codeController = TextEditingController(text: group?.code ?? '');
    final nameController = TextEditingController(text: group?.name ?? '');
    final descriptionController = TextEditingController(
      text: group?.description ?? '',
    );
    bool isActive = group?.isActive ?? true;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                group == null ? 'Add Choice Group' : 'Edit Choice Group',
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      enabled: group == null && !submitting,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      enabled: !submitting,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      enabled: !submitting,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
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
                          final name = nameController.text.trim();
                          if (code.isEmpty && group == null) return;
                          if (name.isEmpty) return;
                          setDialogState(() => submitting = true);
                          try {
                            if (group == null) {
                              await ApiController.createFormTemplateChoiceGroup(
                                code: code,
                                name: name,
                                description: descriptionController.text.trim(),
                                isActive: isActive,
                              );
                            } else {
                              await ApiController.updateFormTemplateChoiceGroup(
                                group.id,
                                name: name,
                                description: descriptionController.text.trim(),
                                isActive: isActive,
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            await _load();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$e')));
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

  @override
  Widget build(BuildContext context) {
    final user = LoginSessionController.instance.userInfo;
    return Scaffold(
      appBar: AppBar(title: const Text('Template Choice Groups')),
      drawer: AppDrawer(user: user),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateOrEditGroup(),
        icon: const Icon(Icons.add),
        label: const Text('Add Group'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Reusable choice groups for form-template fields.',
                    style: TextStyle(color: Color(0xFF475569)),
                  ),
                ),
                Switch(
                  value: _includeInactive,
                  onChanged: (value) {
                    setState(() => _includeInactive = value);
                    _load();
                  },
                ),
                const Text('Include inactive'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _result.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _result.items[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(item.code),
                              if (item.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(item.description),
                              ],
                              const SizedBox(height: 4),
                              Text('Items: ${item.itemCount}'),
                            ],
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  item.isActive ? 'Active' : 'Inactive',
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _openCreateOrEditGroup(group: item),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final refreshed = await Navigator.of(context)
                                      .push<bool>(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FormTemplateChoiceGroupDetailPage(
                                                groupId: item.id,
                                              ),
                                        ),
                                      );
                                  if (refreshed == true && mounted) {
                                    await _load();
                                  }
                                },
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          onTap: () async {
                            final refreshed = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FormTemplateChoiceGroupDetailPage(
                                          groupId: item.id,
                                        ),
                                  ),
                                );
                            if (refreshed == true && mounted) {
                              await _load();
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
