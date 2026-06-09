import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/email_contact.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/login_session_controller.dart';

class EmailContactListPage extends StatefulWidget {
  const EmailContactListPage({super.key});

  @override
  State<EmailContactListPage> createState() => _EmailContactListPageState();
}

class _EmailContactListPageState extends State<EmailContactListPage> {
  final _searchController = TextEditingController();
  bool _loading = true;
  EmailContactList _result = EmailContactList();
  int _offset = 0;
  static const _limit = 50;

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

  Future<void> _load({int? offset}) async {
    setState(() => _loading = true);
    try {
      final nextOffset = offset ?? _offset;
      final result = await ApiController.listEmailContacts(
        q: _searchController.text,
        limit: _limit,
        offset: nextOffset,
      );
      if (!mounted) return;
      setState(() {
        _offset = nextOffset;
        _result = result;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([EmailContact? item]) async {
    final name = TextEditingController(text: item?.name ?? '');
    final email = TextEditingController(text: item?.email ?? '');
    final notes = TextEditingController(text: item?.notes ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Add Contact' : 'Edit Contact'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
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
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Required';
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(text)) {
                        return 'Invalid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notes,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
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
                        final saved = await ApiController.saveEmailContact(
                          id: item?.id,
                          name: name.text.trim(),
                          email: email.text.trim(),
                          notes: notes.text.trim(),
                        );
                        if (saved.id.isEmpty) {
                          throw Exception('Unable to save contact.');
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
    email.dispose();
    notes.dispose();
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  Future<void> _deactivate(EmailContact item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate contact?'),
        content: Text('${item.name} <${item.email}>'),
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
    await ApiController.deactivateEmailContact(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final UserInfo user = LoginSessionController.instance.userInfo;
    final canBack = _offset > 0;
    final canNext = _offset + _result.items.length < _result.total;
    return Scaffold(
      drawer: AppDrawer(user: user),
      appBar: AppBar(title: const Text('Address Book')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add Contact'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search contacts',
              onSubmitted: (_) => _load(offset: 0),
              trailing: [
                IconButton(
                  onPressed: () => _load(offset: 0),
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _result.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _result.items[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            item.notes.isEmpty
                                ? item.email
                                : '${item.email}\n${item.notes}',
                          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: canBack
                      ? () =>
                            _load(offset: (_offset - _limit).clamp(0, 1 << 30))
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  _result.total == 0
                      ? '0'
                      : '${_offset + 1}-${_offset + _result.items.length} of ${_result.total}',
                ),
                IconButton(
                  onPressed: canNext
                      ? () => _load(offset: _offset + _limit)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
