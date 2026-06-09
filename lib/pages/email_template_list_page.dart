import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/email_template.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/login_session_controller.dart';

class EmailTemplateListPage extends StatefulWidget {
  const EmailTemplateListPage({super.key});

  @override
  State<EmailTemplateListPage> createState() => _EmailTemplateListPageState();
}

class _EmailTemplateListPageState extends State<EmailTemplateListPage> {
  final _searchController = TextEditingController();
  bool _loading = true;
  List<EmailTemplate> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiController.listEmailTemplates(
        q: _searchController.text,
      );
      if (!mounted) return;
      setState(() => _items = result.items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([EmailTemplate? item]) async {
    final name = TextEditingController(text: item?.name ?? '');
    final subject = TextEditingController(text: item?.subject ?? '');
    final bodyHtml = TextEditingController(text: item?.bodyHtml ?? '');
    final bodyText = TextEditingController(text: item?.bodyText ?? '');
    final formKey = GlobalKey<FormState>();
    var active = item?.isActive ?? true;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            item == null ? 'Add Email Template' : 'Edit Email Template',
          ),
          content: SizedBox(
            width: 620,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: subject,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bodyHtml,
                      minLines: 6,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: 'HTML Body',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bodyText,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Text Body (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: active,
                      onChanged: saving
                          ? null
                          : (value) => setDialogState(() => active = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final saved = await ApiController.saveEmailTemplate(
                          id: item?.id,
                          name: name.text.trim(),
                          subject: subject.text.trim(),
                          bodyHtml: bodyHtml.text.trim(),
                          bodyText: bodyText.text.trim().isEmpty
                              ? null
                              : bodyText.text.trim(),
                          isActive: active,
                        );
                        if (saved.id.isEmpty) {
                          throw Exception('Unable to save email template.');
                        }
                        if (!mounted) return;
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        await _load();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          this.context,
                        ).showSnackBar(SnackBar(content: Text('$e')));
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    subject.dispose();
    bodyHtml.dispose();
    bodyText.dispose();
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  Future<void> _deactivate(EmailTemplate item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate template?'),
        content: Text(item.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiController.deactivateEmailTemplate(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final UserInfo user = LoginSessionController.instance.userInfo;
    return Scaffold(
      drawer: AppDrawer(user: user),
      appBar: AppBar(
        title: const Text('Email Templates'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Add Template'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search templates',
              onSubmitted: (_) => _load(),
              trailing: [
                IconButton(onPressed: _load, icon: const Icon(Icons.search)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.subject),
                          onTap: () => _edit(item),
                          trailing: IconButton(
                            tooltip: 'Deactivate',
                            onPressed: () => _deactivate(item),
                            icon: const Icon(Icons.delete_outline),
                          ),
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
