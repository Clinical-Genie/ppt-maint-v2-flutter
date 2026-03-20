import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/email_batch.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/pages/email_batch_detail_page.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/login_session_controller.dart';

class EmailBatchListPage extends StatefulWidget {
  const EmailBatchListPage({super.key});

  @override
  State<EmailBatchListPage> createState() => _EmailBatchListPageState();
}

class _EmailBatchListPageState extends State<EmailBatchListPage> {
  static const _statuses = ['all', 'draft', 'sending', 'sent', 'failed'];
  String _selectedStatus = 'all';
  bool _isLoading = true;
  EmailBatchListResult _result = EmailBatchListResult();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiController.listEmailBatches(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        limit: 50,
        offset: 0,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openCreateDraftDialog() async {
    final workOrderIdsController = TextEditingController();
    final toEmailsController = TextEditingController();
    final subjectController = TextEditingController();
    final bodyTextController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool creating = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Create Email Draft'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: workOrderIdsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Work Order IDs',
                          hintText: 'Comma-separated UUIDs',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: toEmailsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Recipients',
                          hintText: 'Comma-separated emails',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyTextController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Body',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: creating
                      ? null
                      : () async {
                          final ids = workOrderIdsController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                          final emails = toEmailsController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                          if (ids.isEmpty || emails.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Work order IDs and recipients are required.',
                                ),
                              ),
                            );
                            return;
                          }
                          setStateDialog(() => creating = true);
                          try {
                            final created = await ApiController.createEmailBatch(
                              workOrderIds: ids,
                              toEmails: emails,
                              subject: subjectController.text.trim(),
                              bodyText: bodyTextController.text.trim(),
                            );
                            if (!mounted) return;
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EmailBatchDetailPage(
                                  batchId: created.emailBatchId,
                                ),
                              ),
                            );
                            _load();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                          } finally {
                            if (dialogContext.mounted) {
                              setStateDialog(() => creating = false);
                            }
                          }
                        },
                  child: const Text('Create Draft'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF334155);
    if (normalized == 'draft') {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1D4ED8);
    } else if (normalized == 'sending') {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFF9A3412);
    } else if (normalized == 'sent') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (normalized == 'failed') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        status,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  String _formatDateTime(String value) {
    if (value.isEmpty) return '-';
    try {
      final dt = DateTime.parse(value).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserInfo user = LoginSessionController.instance.userInfo;
    return Scaffold(
      drawer: AppDrawer(user: user),
      appBar: AppBar(
        title: const Text('Email Batches'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              items: _statuses
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedStatus = value);
                _load();
              },
            ),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDraftDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Draft'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _result.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _result.items[index];
                return Card(
                  child: ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EmailBatchDetailPage(batchId: item.id),
                        ),
                      );
                    },
                    title: Text(item.subject.isEmpty ? 'No subject' : item.subject),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.toEmails.isEmpty ? '-' : item.toEmails.join(', '),
                        ),
                        Text('Updated: ${_formatDateTime(item.updatedAt)}'),
                        if (item.error.isNotEmpty)
                          Text(
                            'Error: ${item.error}',
                            style: const TextStyle(color: Color(0xFFB91C1C)),
                          ),
                      ],
                    ),
                    trailing: _statusBadge(item.status),
                  ),
                );
              },
            ),
    );
  }
}
