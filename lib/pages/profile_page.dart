import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/user_info.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/login_session_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUploadingSignature = false;
  bool _isChangingPassword = false;
  int _signatureVersion = DateTime.now().millisecondsSinceEpoch;
  int _activeSessionCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSessionCount();
  }

  Future<void> _refreshProfile() async {
    final updatedUser = await ApiController.getMyUserInfo();
    LoginSessionController.instance.userInfo = updatedUser;
    if (mounted) {
      setState(() {
        _signatureVersion = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  Future<void> _openSignatureDialog() async {
    final points = <Offset?>[];
    final boundaryKey = GlobalKey();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveSignature() async {
              if (points.whereType<Offset>().isEmpty) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Please add a signature first.'),
                  ),
                );
                return;
              }

              setDialogState(() => isSaving = true);
              setState(() => _isUploadingSignature = true);

              try {
                final boundary =
                    boundaryKey.currentContext?.findRenderObject()
                        as RenderRepaintBoundary?;
                if (boundary == null) {
                  throw Exception('Signature canvas is not ready.');
                }

                final image = await boundary.toImage(pixelRatio: 3);
                final byteData = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                if (byteData == null) {
                  throw Exception('Unable to generate signature image.');
                }

                final bytes = byteData.buffer.asUint8List();
                await ApiController.uploadMySignature(bytes);
                await _refreshProfile();

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Signature saved.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Failed to save signature: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isUploadingSignature = false);
                }
                if (dialogContext.mounted) {
                  setDialogState(() => isSaving = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Edit Signature'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sign inside the box below. Use a finger or Apple Pencil on tablet/phone.',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GestureDetector(
                          onPanStart: (details) {
                            final box =
                                boundaryKey.currentContext?.findRenderObject()
                                    as RenderBox?;
                            if (box == null) return;
                            final local = box.globalToLocal(
                              details.globalPosition,
                            );
                            setDialogState(() {
                              points.add(local);
                            });
                          },
                          onPanUpdate: (details) {
                            final box =
                                boundaryKey.currentContext?.findRenderObject()
                                    as RenderBox?;
                            if (box == null) return;
                            final local = box.globalToLocal(
                              details.globalPosition,
                            );
                            setDialogState(() {
                              points.add(local);
                            });
                          },
                          onPanEnd: (_) {
                            setDialogState(() {
                              points.add(null);
                            });
                          },
                          child: RepaintBoundary(
                            key: boundaryKey,
                            child: CustomPaint(
                              painter: _SignaturePainter(
                                List<Offset?>.from(points),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          setDialogState(() {
                            points.clear();
                          });
                        },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : saveSignature,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOldPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              setDialogState(() => isSaving = true);
              setState(() => _isChangingPassword = true);

              try {
                final message = await ApiController.changePassword(
                  oldPasswordController.text,
                  newPasswordController.text,
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      backgroundColor:
                          (message.isEmpty ||
                              message.toLowerCase().contains('failed'))
                          ? Colors.red
                          : null,
                      content: Text(
                        message.isNotEmpty
                            ? message
                            : 'Server has some technical issue. Failed to change password. Please try again later.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Failed to change password: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isChangingPassword = false);
                }
                if (dialogContext.mounted) {
                  setDialogState(() => isSaving = false);
                }
              }
            }

            InputDecoration passwordDecoration(
              String label,
              bool obscure,
              VoidCallback onToggle,
            ) {
              return InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: onToggle,
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Change Password'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: obscureOldPassword,
                        decoration: passwordDecoration(
                          'Current Password',
                          obscureOldPassword,
                          () => setDialogState(() {
                            obscureOldPassword = !obscureOldPassword;
                          }),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your current password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNewPassword,
                        decoration: passwordDecoration(
                          'New Password',
                          obscureNewPassword,
                          () => setDialogState(() {
                            obscureNewPassword = !obscureNewPassword;
                          }),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a new password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        decoration: passwordDecoration(
                          'Confirm Password',
                          obscureConfirmPassword,
                          () => setDialogState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          }),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your new password';
                          }
                          if (value != newPasswordController.text) {
                            return 'Passwords do not match';
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
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : submit,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openSessionManagement() async {
    await Navigator.of(context).pushNamed('/login-sessions');
    await _loadSessionCount();
  }

  Future<void> _loadSessionCount() async {
    try {
      final payload = await ApiController.getActiveSessions();
      if (!mounted) return;
      setState(() {
        _activeSessionCount = payload.activeCount;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeSessionCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = LoginSessionController.instance;
    final user = session.userInfo;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      drawer: AppDrawer(user: user),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHero(
                  displayName: user.fullName.isNotEmpty
                      ? user.fullName
                      : user.username.isEmpty
                      ? session.username
                      : user.username,
                  email: user.email,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _InfoCard(
                      title: 'User Information',
                      width: 460,
                      children: [
                        _InfoRow(label: 'ID', value: user.id),
                        _InfoRow(label: 'Full Name', value: user.fullName),
                        _InfoRow(label: 'Email', value: user.email),
                        _InfoRow(label: 'Phone', value: user.phone),
                        _InfoRow(label: 'Username', value: session.username),
                      ],
                    ),
                    _InfoCard(
                      title: 'Work Profile',
                      width: 460,
                      children: [
                        if (user.roles.isEmpty)
                          const _InfoRow(label: 'Roles', value: 'No roles')
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: user.roles
                                .map(
                                  (role) => Chip(
                                    label: Text(role),
                                    backgroundColor: const Color(0xFFE2E8F0),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 12),
                        ...user.profile.entries.map(
                          (entry) => _InfoRow(
                            label: _formatProfileKey(entry.key),
                            value: '${entry.value ?? ''}',
                          ),
                        ),
                        _InfoRow(label: 'Timezone', value: user.timezone),
                        _InfoRow(
                          label: 'Email Verified',
                          value: user.isEmailVerified ? 'Yes' : 'No',
                        ),

                        // _InfoRow(
                        //   label: 'Signature URL',
                        //   value: user.signatureUrl,
                        // ),
                      ],
                    ),
                    _InfoCard(
                      title: 'Signature',
                      width: 460,
                      children: [
                        _SignaturePreview(
                          user: user,
                          isUploading: _isUploadingSignature,
                          cacheBustKey: _signatureVersion,
                          onEdit: _openSignatureDialog,
                        ),
                      ],
                    ),
                    _InfoCard(
                      title: 'Security',
                      width: 460,
                      children: [
                        Divider(color: const Color(0xFFCBD5E1)),
                        const SizedBox(height: 8),
                        const Text(
                          'Update your account password.',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _isChangingPassword
                                ? null
                                : _openChangePasswordDialog,
                            icon: _isChangingPassword
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_outline),
                            label: Text(
                              _isChangingPassword
                                  ? 'Updating...'
                                  : 'Change Password',
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        Divider(color: const Color(0xFFCBD5E1)),
                        const SizedBox(height: 8),
                        Text(
                          'Active login sessions: $_activeSessionCount',
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            // fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _openSessionManagement,
                            icon: const Icon(Icons.phone_android_outlined),
                            label: const Text('Management my login sessions'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.displayName, required this.email});

  final String displayName;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isNotEmpty ? displayName : 'Unnamed User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email.isNotEmpty ? email : 'No email',
                  style: const TextStyle(color: Color(0xFFDCE7FF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignaturePreview extends StatelessWidget {
  const _SignaturePreview({
    required this.user,
    required this.isUploading,
    required this.cacheBustKey,
    required this.onEdit,
  });

  final UserInfo user;
  final bool isUploading;
  final int cacheBustKey;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ApiController.resolveServerUrl(user.signatureUrl);
    final signatureUrl = resolvedUrl.isEmpty
        ? ''
        : Uri.parse(resolvedUrl)
              .replace(
                queryParameters: {
                  ...Uri.parse(resolvedUrl).queryParameters,
                  'v': '$cacheBustKey',
                },
              )
              .toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          alignment: Alignment.center,
          child: signatureUrl.isEmpty
              ? const Text(
                  'No signature',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    signatureUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        'No signature',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: isUploading ? null : onEdit,
            icon: isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.draw_outlined),
            label: Text(isUploading ? 'Saving...' : 'Edit Signature'),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.width,
    required this.children,
  });

  final String title;
  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatProfileKey(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return true;
  }
}
