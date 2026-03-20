import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/user_info.dart';

class UserEditPage extends StatefulWidget {
  const UserEditPage({required this.user, super.key});

  final UserInfo user;

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _timezoneController;
  late final TextEditingController _positionController;
  late final TextEditingController _departmentController;
  bool _isSaving = false;
  bool _isLoadingRoles = false;
  bool _isSavingRoles = false;
  RoleList _availableRoles = RoleList();
  final Set<String> _selectedRoles = {};

  String get _userId => widget.user.id;
  String get _username => widget.user.username;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);
    _timezoneController = TextEditingController(text: widget.user.timezone);
    _positionController = TextEditingController(
      text: '${widget.user.profile['position'] ?? widget.user.position}'.trim(),
    );
    _departmentController = TextEditingController(
      text: '${widget.user.profile['department'] ?? widget.user.department}'
          .trim(),
    );
    _selectedRoles.addAll(widget.user.roles);
    _loadAvailableRoles();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _timezoneController.dispose();
    _positionController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableRoles() async {
    setState(() => _isLoadingRoles = true);
    final roles = await ApiController.getAvailableRoles();
    if (!mounted) return;
    setState(() {
      _availableRoles = roles;
      _selectedRoles.addAll(roles.containsRoleCodes(widget.user.roles));
      _isLoadingRoles = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID is missing. Cannot update.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final updated = await ApiController.updateUserProfile(
      _userId,
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      timezone: _timezoneController.text.trim(),
      profile: {
        ...widget.user.profile,
        'position': _positionController.text.trim(),
        'department': _departmentController.text.trim(),
      },
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (updated.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed. Please try again.')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User updated successfully.')));
    Navigator.of(context).pop(true);
  }

  Future<void> _saveRoles() async {
    if (_userId.isEmpty) return;
    setState(() => _isSavingRoles = true);
    final updatedRoles = await ApiController.replaceRolesForUser(
      _userId,
      _selectedRoles.toList(),
    );
    if (!mounted) return;
    setState(() {
      _isSavingRoles = false;
      if (updatedRoles.isNotEmpty) {
        _selectedRoles
          ..clear()
          ..addAll(updatedRoles);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updatedRoles.isEmpty
              ? 'Role update may have failed.'
              : 'Roles updated successfully.',
        ),
      ),
    );
  }

  Future<void> _showResetPasswordDialog() async {
    if (_userId.isEmpty) return;
    final formKey = GlobalKey<FormState>();
    final newPasswordController = TextEditingController();
    bool generatePassword = true;
    bool revokeSessions = true;
    bool obscurePassword = true;
    bool isSubmitting = false;

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!generatePassword &&
                  !(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => isSubmitting = true);
              final result = await ApiController.adminResetUserPassword(
                _userId,
                newPassword: generatePassword
                    ? null
                    : newPasswordController.text.trim(),
                generate: generatePassword,
                revokeSessions: revokeSessions,
              );

              if (dialogContext.mounted) {
                final responseText = result.newPassword.isNotEmpty
                    ? result.newPassword
                    : (result.message.isNotEmpty
                          ? result.message
                          : 'Password reset completed.');
                Navigator.of(dialogContext).pop(responseText);
              }
            }

            return AlertDialog(
              title: const Text('Reset Password'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Generate temporary password'),
                      value: generatePassword,
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              setDialogState(() => generatePassword = value);
                            },
                    ),
                    if (!generatePassword)
                      Form(
                        key: formKey,
                        child: TextFormField(
                          controller: newPasswordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setDialogState(
                                  () => obscurePassword = !obscurePassword,
                                );
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter new password';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Revoke all user sessions'),
                      value: revokeSessions,
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              setDialogState(() => revokeSessions = value);
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    );
    // newPasswordController.dispose();

    if (!mounted || result == null) return;
    if (result.trim().isNotEmpty &&
        !result.toLowerCase().contains('completed') &&
        !result.toLowerCase().contains('reset')) {
      await _showTempPasswordResultDialog(result);
      return;
    }
    log("Password reset result: $result");
    final message = result;
    log("message after reset password: $message");
    // ScaffoldMessenger.of(
    //   context,
    // ).showSnackBar(SnackBar(content: Text('$message')));
    newPasswordController.dispose();
  }

  Future<void> _showTempPasswordResultDialog(String tempPassword) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Temporary Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Password reset completed.'),
              const SizedBox(height: 10),
              SelectableText(
                tempPassword,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: tempPassword));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Temporary password copied')),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('Edit User: $_username')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TextFormField(
                  //   initialValue: _userId,
                  //   decoration: const InputDecoration(
                  //     labelText: 'User ID',
                  //     border: OutlineInputBorder(),
                  //   ),
                  //   enabled: false,
                  // ),
                  // const SizedBox(height: 16),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Full name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _timezoneController,
                    decoration: const InputDecoration(
                      labelText: 'Timezone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _positionController,
                    decoration: const InputDecoration(
                      labelText: 'Position',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Roles', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_isLoadingRoles)
                    const Center(child: CircularProgressIndicator())
                  else if (_availableRoles.items.isEmpty)
                    const Text('No role list available.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableRoles.items.map((role) {
                        return FilterChip(
                          label: Text(role.code),
                          selected: _selectedRoles.contains(role.code),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedRoles.add(role.code);
                              } else {
                                _selectedRoles.remove(role.code);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed:
                          (_isLoadingRoles ||
                              _isSavingRoles ||
                              _availableRoles.items.isEmpty)
                          ? null
                          : _saveRoles,
                      icon: _isSavingRoles
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.admin_panel_settings_outlined),
                      label: Text(_isSavingRoles ? 'Saving...' : 'Save Roles'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Password',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _showResetPasswordDialog,
                      icon: const Icon(Icons.lock_reset_outlined),
                      label: const Text('Reset Password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
