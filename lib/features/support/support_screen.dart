import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';
import '../../data/services/support_service.dart';
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
    _loadThreads();
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
      builder: (_) => _NewQuestionSheet(
        askContactDetails: AccountService.currentUser == null,
      ),
    );
    if (!mounted || result == null) return;

    setState(() => _loading = true);
    try {
      final thread = await SupportService.createThread(
        subject: result.subject,
        message: result.message,
        guestName: result.name,
        guestEmail: result.email,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F6),
      appBar: AppBar(
        title: const Text('Klantenservice'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _newConversation,
        backgroundColor: const Color(0xFFD51B46),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Nieuwe vraag'),
      ),
      body: _buildSupport(),
    );
  }

  Widget _buildSupport() {
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
        icon: Icons.support_agent_rounded,
        title: 'We staan voor je klaar',
        subtitle: AccountService.currentUser == null
            ? 'Je hoeft niet in te loggen. Laat je naam en e-mailadres achter en volg het gesprek gewoon in PasKluis.'
            : 'Stel gerust een vraag. Je vindt onze antwoorden overzichtelijk in dit scherm terug.',
        buttonLabel: 'Nieuwe vraag',
        onPressed: _newConversation,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadThreads,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        itemCount: _threads.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) return const _SupportHero();
          final thread = _threads[index - 1];
          return Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
  final bool askContactDetails;

  const _NewQuestionSheet({required this.askContactDetails});

  @override
  State<_NewQuestionSheet> createState() => _NewQuestionSheetState();
}

class _NewQuestionSheetState extends State<_NewQuestionSheet> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
            if (widget.askContactDetails) ...[
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Naam',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Vul je naam in.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'E-mailadres',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return !email.contains('@') || !email.contains('.')
                      ? 'Vul een geldig e-mailadres in.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
            ],
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
                    name: _nameController.text.trim(),
                    email: _emailController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Vraag versturen'),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewSupportQuestion {
  final String subject;
  final String message;
  final String name;
  final String email;

  const _NewSupportQuestion({
    required this.subject,
    required this.message,
    required this.name,
    required this.email,
  });
}

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF343B67), Color(0xFF5967A3)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.support_agent_rounded,
                color: Colors.white, size: 31),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Persoonlijke hulp',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Bekijk je vragen en onze antwoorden op één plek.',
                    style: TextStyle(color: Color(0xFFE8EBFF), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(color: Color(0x10000000), blurRadius: 25, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 37,
                backgroundColor: const Color(0xFFFFE7ED),
                child: Icon(icon, size: 39, color: const Color(0xFFD51B46)),
              ),
              const SizedBox(height: 17),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6F6A74), height: 1.4)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.add_comment_rounded),
                  label: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
