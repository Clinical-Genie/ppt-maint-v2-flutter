import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/email_batch.dart';
import 'package:maintapp/model/email_contact.dart';
import 'package:maintapp/model/email_template.dart';
import 'package:maintapp/model/work_order.dart';
import 'package:maintapp/pages/email_batch_detail_page.dart';

class EmailBatchComposePage extends StatefulWidget {
  const EmailBatchComposePage({required this.workOrders, super.key});

  final List<WorkOrder> workOrders;

  @override
  State<EmailBatchComposePage> createState() => _EmailBatchComposePageState();
}

class _EmailBatchComposePageState extends State<EmailBatchComposePage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _bodyHtmlController = TextEditingController();
  final _bodyTextController = TextEditingController();
  final _toController = TextEditingController();
  final _ccController = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  EmailBatchConfig _config = EmailBatchConfig();
  List<EmailTemplate> _templates = [];
  List<EmailContact> _contacts = [];
  String? _templateId;
  final Set<String> _toContactIds = {};
  final Set<String> _ccContactIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyHtmlController.dispose();
    _bodyTextController.dispose();
    _toController.dispose();
    _ccController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait<dynamic>([
        ApiController.getEmailBatchConfig(),
        ApiController.listEmailTemplates(),
        ApiController.listEmailContacts(limit: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _config = values[0] as EmailBatchConfig;
        _templates = (values[1] as EmailTemplateList).items
            .where((item) => item.isActive)
            .toList();
        _contacts = (values[2] as EmailContactList).items
            .where((item) => item.isActive)
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectTemplate(String? id) {
    setState(() => _templateId = id);
    if (id == null) return;
    final template = _templates.where((item) => item.id == id).firstOrNull;
    if (template == null) return;
    _subjectController.text = template.subject;
    _bodyHtmlController.text = template.bodyHtml;
    _bodyTextController.text = template.bodyText;
  }

  List<String> _manualEmails(TextEditingController controller) {
    return controller.text
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _recipientCandidates(
    Set<String> contactIds,
    TextEditingController controller,
  ) {
    return [
      ..._contacts
          .where((item) => contactIds.contains(item.id))
          .map((item) => item.email.trim().toLowerCase())
          .where((item) => item.isNotEmpty),
      ..._manualEmails(controller),
    ];
  }

  String? _validateEmailList(String? value) {
    final emails = (value ?? '')
        .split(RegExp(r'[,;\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);
    for (final email in emails) {
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
        return 'Invalid email: $email';
      }
    }
    return null;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final toCandidates = _recipientCandidates(_toContactIds, _toController);
    final ccCandidates = _recipientCandidates(_ccContactIds, _ccController);
    final toEmails = toCandidates.toSet().toList();
    final ccEmails = ccCandidates.toSet().toList();
    final overlap = toEmails.toSet().intersection(ccEmails.toSet());
    String? error;
    if (!_config.attachmentsSupported) {
      error = 'The configured mail provider does not support attachments.';
    } else if (widget.workOrders.isEmpty) {
      error = 'Select at least one work order.';
    } else if (_config.maxWorkOrders > 0 &&
        widget.workOrders.length > _config.maxWorkOrders) {
      error = 'Select no more than ${_config.maxWorkOrders} work orders.';
    } else if (toEmails.isEmpty) {
      error = 'At least one To recipient is required.';
    } else if (toCandidates.length != toEmails.length) {
      error = 'Duplicate To recipient addresses are not allowed.';
    } else if (ccCandidates.length != ccEmails.length) {
      error = 'Duplicate CC recipient addresses are not allowed.';
    } else if (_config.maxToEmails > 0 &&
        toEmails.length > _config.maxToEmails) {
      error = 'To recipients exceed the limit of ${_config.maxToEmails}.';
    } else if (_config.maxCcEmails > 0 &&
        ccEmails.length > _config.maxCcEmails) {
      error = 'CC recipients exceed the limit of ${_config.maxCcEmails}.';
    } else if (overlap.isNotEmpty) {
      error = 'An email address cannot appear in both To and CC.';
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _sending = true);
    try {
      final created = await ApiController.createEmailBatch(
        workOrderIds: widget.workOrders.map((item) => item.id).toList(),
        toEmails: toEmails,
        ccEmails: ccEmails,
        subject: _subjectController.text.trim(),
        bodyHtml: _bodyHtmlController.text.trim(),
        bodyText: _bodyTextController.text.trim().isEmpty
            ? null
            : _bodyTextController.text.trim(),
      );
      if (created.emailBatchId.isEmpty) {
        throw Exception(
          created.message.isEmpty
              ? 'Unable to create email batch.'
              : created.message,
        );
      }
      final sent = await ApiController.sendEmailBatch(created.emailBatchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${sent.message} Sent: ${sent.sentCount}, Failed: ${sent.failedCount}',
          ),
        ),
      );
      if (sent.failedCount > 0 || sent.status.toLowerCase() != 'sent') {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailBatchDetailPage(batchId: created.emailBatchId),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _contactPicker({
    required String label,
    required Set<String> selectedIds,
    required Set<String> blockedIds,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _contacts.map((contact) {
          final selected = selectedIds.contains(contact.id);
          return FilterChip(
            label: Text('${contact.name} <${contact.email}>'),
            selected: selected,
            onSelected: blockedIds.contains(contact.id)
                ? null
                : (value) {
                    setState(() {
                      if (value) {
                        selectedIds.add(contact.id);
                      } else {
                        selectedIds.remove(contact.id);
                      }
                    });
                  },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Selected Work Orders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_config.attachmentsSupported)
                    const Card(
                      color: Color(0xFFFEE2E2),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Sending is disabled because attachments are not supported.',
                        ),
                      ),
                    ),
                  Text(
                    'Attachments (${widget.workOrders.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.workOrders
                        .map(
                          (item) => Chip(
                            avatar: const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 18,
                            ),
                            label: Text('${item.referenceNumber}.pdf'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _templateId,
                    decoration: const InputDecoration(
                      labelText: 'Email Template',
                      border: OutlineInputBorder(),
                    ),
                    items: _templates
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: _selectTemplate,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bodyHtmlController,
                    minLines: 6,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      labelText: 'Body (HTML)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bodyTextController,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Body (Text, optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _contactPicker(
                    label: 'To - Address Book',
                    selectedIds: _toContactIds,
                    blockedIds: _ccContactIds,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _toController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Additional To emails',
                      hintText: 'Separate emails with commas',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateEmailList,
                  ),
                  const SizedBox(height: 16),
                  _contactPicker(
                    label: 'CC - Address Book',
                    selectedIds: _ccContactIds,
                    blockedIds: _toContactIds,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ccController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Additional CC emails',
                      hintText: 'Separate emails with commas',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateEmailList,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _sending || !_config.attachmentsSupported
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(_sending ? 'Sending...' : 'Send'),
                  ),
                ],
              ),
            ),
    );
  }
}
