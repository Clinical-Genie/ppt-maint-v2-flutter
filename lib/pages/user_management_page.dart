import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/pages/user_edit_page.dart';
import 'package:maintapp/state/login_session_controller.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _searchController = TextEditingController();
  final _listScrollController = ScrollController();
  bool _isLoading = false;
  bool _isAddingUser = false;
  bool _includeInactive = false;
  UserList _userList = UserList();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  bool get _hasAdminRole {
    final roles = LoginSessionController.instance.userInfo.roles;
    return roles.contains('ADMIN');
  }

  Future<void> _loadUsers() async {
    if (!_hasAdminRole) return;
    setState(() => _isLoading = true);
    _userList = await ApiController.listUsers(
      q: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
      includeInactive: _includeInactive,
      limit: 100,
      offset: 0,
    );
    log("Loaded ${_userList.items.length} users (total: ${_userList.total})");
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _openAddUserDialog() async {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() => isSubmitting = true);
              setState(() => _isAddingUser = true);

              final ok = await ApiController.createUser(
                username: usernameController.text.trim(),
                fullName: fullNameController.text.trim(),
                password: passwordController.text,
                email: emailController.text.trim().isEmpty
                    ? null
                    : emailController.text.trim(),
              );

              if (!mounted) return;
              setState(() => _isAddingUser = false);
              setDialogState(() => isSubmitting = false);

              if (!ok) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Create user failed.')),
                );
                return;
              }

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('User added successfully.')),
              );
              await _loadUsers();
            }

            return AlertDialog(
              title: const Text('Add User'),
              content: SizedBox(
                width: 460,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Username is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fullNameController,
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email (optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
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
                            return 'Password is required';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
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
                      : const Text('Add User'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleUserStatus(UserInfo user) async {
    if (user.id.isEmpty) return;
    final currentUser = LoginSessionController.instance.userInfo;
    final isSelf =
        (currentUser.id.isNotEmpty && user.id == currentUser.id) ||
        (currentUser.username.isNotEmpty &&
            user.username == currentUser.username);
    if (isSelf) return;

    final isActive = user.isActive;
    final result = await ApiController.updateUserStatus(user.id, !isActive);
    if (!mounted) return;
    if (result.userId.isEmpty && result.message.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Update status failed.')));
      return;
    }
    await _loadUsers();
  }

  Future<void> _editUser(UserInfo user) async {
    final updated = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => UserEditPage(user: user)));
    if (updated == true && mounted) {
      await _loadUsers();
    }
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = LoginSessionController.instance;
    final currentUser = session.userInfo;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      drawer: AppDrawer(user: currentUser),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'User Management',
          style: TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _hasAdminRole
          ? FloatingActionButton.extended(
              onPressed: _isAddingUser ? null : _openAddUserDialog,
              icon: _isAddingUser
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: const Text('Add User'),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 768;
          if (!_hasAdminRole) {
            return const Center(
              child: Text('Admin role required for User Management.'),
            );
          }
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isPhone ? 12 : 16,
                  12,
                  isPhone ? 12 : 16,
                  8,
                ),
                child: isPhone
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText:
                                  'Search by username / full name / email',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _loadUsers(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _isLoading ? null : _loadUsers,
                                  child: const Text('Search'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Show inactive'),
                              Switch(
                                value: _includeInactive,
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        setState(
                                          () => _includeInactive = value,
                                        );
                                        _loadUsers();
                                      },
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search by username / full name / email',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _loadUsers(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: _isLoading ? null : _loadUsers,
                            child: const Text('Search'),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Show inactive'),
                              Switch(
                                value: _includeInactive,
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        setState(
                                          () => _includeInactive = value,
                                        );
                                        _loadUsers();
                                      },
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    if (_userList.items.isEmpty && _isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_userList.items.isEmpty)
                      const Center(child: Text('No users found.'))
                    else
                      RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.separated(
                          key: const PageStorageKey<String>(
                            'user_management_list',
                          ),
                          controller: _listScrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            isPhone ? 12 : 16,
                            4,
                            isPhone ? 12 : 16,
                            24,
                          ),
                          itemCount: _userList.items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final user = _userList.items[index];
                            final isSelf =
                                (currentUser.id.isNotEmpty &&
                                    user.id == currentUser.id) ||
                                (currentUser.username.isNotEmpty &&
                                    user.username == currentUser.username);

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: isPhone
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  user.fullName.isEmpty
                                                      ? user.username
                                                      : user.fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildStatusBadge(user.isActive),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            user.username.isNotEmpty
                                                ? user.username
                                                : '-',
                                            style: const TextStyle(
                                              color: Color(0xFF4B5563),
                                            ),
                                          ),
                                          if (user.roles.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: user.roles
                                                  .map(
                                                    (role) => Chip(
                                                      label: Text(role),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _editUser(user),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                                label: const Text('Edit'),
                                              ),
                                              if (!isSelf)
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _toggleUserStatus(user),
                                                  icon: Icon(
                                                    user.isActive
                                                        ? Icons
                                                              .pause_circle_outline
                                                        : Icons
                                                              .play_circle_outline,
                                                  ),
                                                  label: Text(
                                                    user.isActive
                                                        ? 'Deactivate'
                                                        : 'Activate',
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          Text(
                                                            user
                                                                    .fullName
                                                                    .isEmpty
                                                                ? user.username
                                                                : user.fullName,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 16,
                                                                ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),

                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          _buildStatusBadge(
                                                            user.isActive,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  user.username.isNotEmpty
                                                      ? user.username
                                                      : '-',
                                                  style: const TextStyle(
                                                    color: Color(0xFF4B5563),
                                                  ),
                                                ),
                                                if (user.roles.isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children: user.roles
                                                        .map(
                                                          (role) => Chip(
                                                            label: Text(role),
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                          ),
                                                        )
                                                        .toList(),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _editUser(user),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                                label: const Text('Edit'),
                                              ),
                                              if (!isSelf)
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _toggleUserStatus(user),
                                                  icon: Icon(
                                                    user.isActive
                                                        ? Icons
                                                              .pause_circle_outline
                                                        : Icons
                                                              .play_circle_outline,
                                                  ),
                                                  label: Text(
                                                    user.isActive
                                                        ? 'Deactivate'
                                                        : 'Activate',
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (_isLoading && _userList.items.isNotEmpty)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
