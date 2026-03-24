import 'package:flutter/material.dart';
import 'package:maintapp/api/api_controller.dart';
import 'package:maintapp/model/session.dart';
import 'package:maintapp/pages/shared/app_drawer.dart';
import 'package:maintapp/state/login_session_controller.dart';

class LoginSessionsPage extends StatefulWidget {
  const LoginSessionsPage({super.key});

  @override
  State<LoginSessionsPage> createState() => _LoginSessionsPageState();
}

class _LoginSessionsPageState extends State<LoginSessionsPage> {
  bool _isLoading = false;
  bool _isRevokingAll = false;
  bool _showOnlyActive = true;
  final Set<String> _revokingSessionIds = <String>{};
  List<Session> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final payload = await ApiController.getActiveSessions();
      if (!mounted) return;
      setState(() {
        _sessions = payload.items;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool?> _confirmDialog(String title, String content) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _revokeSession(Session session) async {
    final sessionId = _sessionId(session);
    if (sessionId.isEmpty || _isBusy(sessionId)) return;

    final shouldRevoke = await _confirmDialog(
      'Revoke session',
      'This session will be signed out immediately. Continue?',
    );

    if (shouldRevoke != true) return;

    setState(() => _revokingSessionIds.add(sessionId));
    try {
      final message = await ApiController.revokeSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.isNotEmpty ? message : 'Session revoked.'),
          ),
        );
      }
      await _loadSessions();
    } finally {
      if (mounted) {
        setState(() => _revokingSessionIds.remove(sessionId));
      }
    }
  }

  Future<void> _revokeAllSessions() async {
    final shouldRevoke = await _confirmDialog(
      'Revoke all sessions',
      'This will revoke all sessions except the current one.',
    );

    if (shouldRevoke != true) return;

    setState(() => _isRevokingAll = true);
    try {
      final revoked = await ApiController.revokeAllSessions();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Revoked $revoked session(s).')));
      }
      await _loadSessions();
    } finally {
      if (mounted) {
        setState(() => _isRevokingAll = false);
      }
    }
  }

  bool _isBusy(String sessionId) => _revokingSessionIds.contains(sessionId);

  String _sessionId(Session session) {
    return session.identifier;
  }

  String _sessionLabel(Session session) {
    return session.getLabel();
  }

  String _sessionSubLabel(Session session) {
    final ip = session.getIp().isEmpty ? '-' : session.getIp();
    final userAgent = session.getUserAgent().isEmpty
        ? '-'
        : session.getUserAgent();
    final lastActive = session.getLastActive().isEmpty
        ? '-'
        : session.getLastActive();
    final createdAt = session.createdAt.isEmpty ? '-' : session.createdAt;
    return 'IP: $ip\nLast active: $lastActive\nCreated: $createdAt\nAgent: $userAgent';
  }

  bool _isCurrentSession(Session session) {
    return session.isCurrent;
  }

  bool _isActiveSession(Session session) {
    return session.isActive;
  }

  String _sessionStatusLabel(Session session) {
    final status = session.status;
    if (_isActiveSession(session)) {
      return 'Active';
    }
    if (status.trim().isNotEmpty) {
      final normalized = status.trim().toLowerCase();
      if (normalized == 'revoked') {
        return 'Revoked';
      }
      return normalized[0].toUpperCase() + normalized.substring(1);
    }
    return 'Unknown';
  }

  Color _sessionStatusColor(String statusLabel) {
    return switch (statusLabel) {
      'Active' => const Color(0xFF065F46),
      'Revoked' => const Color(0xFFB91C1C),
      _ => const Color(0xFF475569),
    };
  }

  Color _sessionStatusBgColor(String statusLabel) {
    return switch (statusLabel) {
      'Active' => const Color(0xFFDDF7E6),
      'Revoked' => const Color(0xFFFEE2E2),
      _ => const Color(0xFFE2E8F0),
    };
  }

  List<Session> get _filteredSessions => _sessions
      .where((session) => !_showOnlyActive || _isActiveSession(session))
      .toList();

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
          'Login Sessions',
          style: TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Manage where you are signed in and clear sessions if needed.',
                    style: TextStyle(color: Color(0xFF334155)),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isRevokingAll || _isLoading
                      ? null
                      : _revokeAllSessions,
                  icon: _isRevokingAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Revoke All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Active only'),
                const SizedBox(width: 8),
                Switch(
                  value: _showOnlyActive,
                  onChanged: (value) {
                    setState(() {
                      _showOnlyActive = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadSessions,
              child: const Text('Refresh'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_filteredSessions.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No sessions found.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.separated(
                    itemCount: _filteredSessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final sessionInfo = _filteredSessions[index];
                      final sessionId = _sessionId(sessionInfo);
                      final isCurrent = _isCurrentSession(sessionInfo);
                      final isBusy = _isBusy(sessionId);
                      final isActive = _isActiveSession(sessionInfo);
                      final statusLabel = _sessionStatusLabel(sessionInfo);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x120F172A),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.phone_android_outlined,
                              color: Color(0xFF334155),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _sessionLabel(sessionInfo),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDDF7E6),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'Current',
                                            style: TextStyle(
                                              color: Color(0xFF065F46),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _sessionStatusBgColor(
                                            statusLabel,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: _sessionStatusColor(
                                              statusLabel,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'ID: ${sessionId.isEmpty ? '-' : sessionId}',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _sessionSubLabel(sessionInfo),
                                    style: const TextStyle(
                                      color: Color(0xFF334155),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (!isCurrent && isActive)
                              IconButton(
                                onPressed: isBusy
                                    ? null
                                    : () => _revokeSession(sessionInfo),
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
