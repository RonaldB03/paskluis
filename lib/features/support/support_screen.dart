import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';
import '../../data/services/support_service.dart';
import '../account/account_screen.dart';
import 'support_thread_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _loading = false;
  String? _error;
  List<SupportThread> _threads = const [];

  @override
  void initState() {
    super.initState();
    if (AccountService.currentUser != null) _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final threads = await SupportService.loadThreads();
      if (mounted) setState(() => _threads = threads);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gesprekken konden niet worden opgehaald.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newConversation() async {
    final result = await showModalBottomSheet<_NewSupportQuestion>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NewQuestionSheet(),
    );
    if (!mounted || result == null) return;

    setState(() => _loading = true);
    try {
      final thread = await SupportService.createThread(
        subject: result.subject,
        message: result.message,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SupportThreadScreen(thread: thread)),
      );
      await _loadThreads();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Je vraag kon niet worden verzonden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = AccountService.currentUser != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text('Klantenservice'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
      ),
      floatingActionButton: signedIn
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : _newConversation,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Nieuwe vraag'),
            )
          : null,
      body: signedIn ? _buildSignedIn() : _buildSignedOut(),
    );
  }

  Widget _buildSignedOut() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.support_agent_rounded,
                  size: 54,
                  color: Color(0xFFD51B46),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Log in voor persoonlijke hulp',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Met een gratis account kun je vragen stellen en onze antwoorden teruglezen.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountScreen()),
                    );
                    if (mounted) {
                      setState(() {});
                      if (AccountService.currentUser != null) _loadThreads();
                    }
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Naar inloggen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignedIn() {
    if (_loading && _threads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _threads.isEmpty) {
      return _SupportEmpty(
        icon: Icons.cloud_off_rounded,
        title: _error!,
        subtitle: 'Controleer je verbinding en probeer het opnieuw.',
        buttonLabel: 'Opnieuw proberen',
        onPressed: _loadThreads,
      );
    }
    if (_threads.isEmpty) {
      return _SupportEmpty(
        icon: Icons.forum_outlined,
        title: 'Nog geen gesprekken',
        subtitle: 'Stel gerust een vraag. We helpen je graag verder.',
        buttonLabel: 'Nieuwe vraag',
        onPressed: _newConversation,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadThreads,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        itemCount: _threads.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final thread = _threads[index];
          return Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFFFE7ED),
                child: Icon(
                  thread.status == 'closed'
                      ? Icons.check_rounded
                      : Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFFD51B46),
                ),
              ),
              title: Text(
                thread.subject,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(_statusLabel(thread.status)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupportThreadScreen(thread: thread),
                  ),
                );
                _loadThreads();
              },
            ),
          );
        },
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'waiting_for_user':
        return 'Er staat een antwoord voor je klaar';
      case 'closed':
        return 'Gesloten';
      default:
        return 'Open';
    }
  }
}

class _NewQuestionSheet extends StatefulWidget {
  const _NewQuestionSheet();

  @override
  State<_NewQuestionSheet> createState() => _NewQuestionSheetState();
}

class _NewQuestionSheetState extends State<_NewQuestionSheet> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Waar kunnen we mee helpen?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectController,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Onderwerp',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Vul een onderwerp in.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _messageController,
              minLines: 4,
              maxLines: 7,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Je vraag of probleem',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Vertel kort waar je hulp bij nodig hebt.'
                  : null,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                FocusScope.of(context).unfocus();
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _NewSupportQuestion(
                    subject: _subjectController.text.trim(),
                    message: _messageController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Vraag versturen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewSupportQuestion {
  final String subject;
  final String message;

  const _NewSupportQuestion({required this.subject, required this.message});
}

class _SupportEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _SupportEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFFD51B46)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
