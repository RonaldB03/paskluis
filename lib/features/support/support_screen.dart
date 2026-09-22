import '../settings/help_center_screen.dart';
import '../../data/services/locale_service.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';
import '../../data/services/help_service.dart';
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
  late Future<List<HelpFaq>> _faqs;
  Locale? _faqLocale;
  List<Map<String,dynamic>> _incidents = [];

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_faqLocale != locale) {
      _faqLocale = locale;
      _faqs = HelpService.loadFaqs();
      if (_error != null) _error = L10n.current.unableToLoadConversations;
    }
  }

  Future<void> _loadThreads() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final threads = await SupportService.loadThreads();
      final incidents = await SupportService.loadIncidents();
      if (mounted) setState(() { _threads = threads; _incidents = incidents; });
    } catch (_) {
      if (mounted) {
        setState(() => _error = L10n.current.unableToLoadConversations);
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
        category: result.category,
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
           SnackBar(content: Text(L10n.current.yourQuestionCouldNotBeSent)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F6),
      appBar: AppBar(
        title:  Text(L10n.current.customerSupport),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _newConversation,
        backgroundColor: const Color(0xFFD51B46),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded),
        label:  Text(L10n.current.newQuestion),
      ),
      body: _buildSupport(),
    );
  }

  Widget _supportTools() => Column(children:[
    for(final incident in _incidents) Card(
      color:const Color(0xFFFFF3CB),elevation:0,
      child:ListTile(leading:const Icon(Icons.info_outline),
        title:Text((LocaleService.languageCode=='en' && (incident['title_en'] as String).isNotEmpty ? incident['title_en'] : incident['title_nl']) as String),
        subtitle:Text((LocaleService.languageCode=='en' && (incident['body_en'] as String).isNotEmpty ? incident['body_en'] : incident['body_nl']) as String),
      ),
    ),
    Card(elevation:0,color:Colors.white,child:ListTile(
      leading:const Icon(Icons.search_rounded),title:Text(L10n.current.searchQuestions),
      trailing:const Icon(Icons.chevron_right),
      onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const HelpCenterScreen())),
    )),
    const SizedBox(height:12),
  ]);

  Widget _buildSupport() {
    if (_loading && _threads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _threads.isEmpty) {
      return _SupportEmpty(
        icon: Icons.cloud_off_rounded,
        title: _error!,
        subtitle: L10n.current.checkYourConnectionAndTryAgain,
        buttonLabel: L10n.current.tryAgain,
        onPressed: _loadThreads,
      );
    }
    if (_threads.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
        children: [
          _supportTools(),
          _SupportEmpty(
            icon: Icons.support_agent_rounded,
            title: L10n.current.weAreHereToHelp,
            subtitle: AccountService.currentUser == null
                ? L10n.current.noSignInNeededLeaveYourName
                : L10n.current.feelFreeToAskAQuestionYou,
            showAction: false,
            buttonLabel: '',
            onPressed: _newConversation,
          ),
          const SizedBox(height: 24),
           Text(
            L10n.current.frequentlyAskedQuestions,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<HelpFaq>>(
            future: _faqs,
            builder: (context, snapshot) {
              final faqs = snapshot.data ?? const <HelpFaq>[];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                children: faqs
                    .take(5)
                    .map(
                      (faq) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 9),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Text(
                            faq.question,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            17,
                            0,
                            17,
                            17,
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                faq.answer,
                                style: const TextStyle(
                                  color: Color(0xFF625E67),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
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
          if (index == 0) return Column(children:[_supportTools(), const _SupportHero()]);
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
        return L10n.current.aReplyIsWaitingForYou;
      case 'closed':
        return L10n.current.closed;
      default:
        return L10n.current.open;
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
  String _category = 'overig';
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
    L10n.watch(context);
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
             Text(
              L10n.current.howCanWeHelp,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            if (widget.askContactDetails) ...[
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration:  InputDecoration(
                  labelText: L10n.current.name,
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? L10n.current.enterYourName
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration:  InputDecoration(
                  labelText: L10n.current.emailAddress,
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  return !email.contains('@') || !email.contains('.')
                      ? L10n.current.enterAValidEmailAddress
                      : null;
                },
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: L10n.current.supportCategory, border: const OutlineInputBorder()),
              items: [
                for (final entry in <String,String>{
                  'overig': L10n.current.supportOther, 'account': L10n.current.account,
                  'plus': 'PasKluis Plus', 'kaarten': L10n.current.cards,
                  'delen': L10n.current.supportSharing, 'meldingen': L10n.current.supportNotifications,
                  'import': L10n.current.supportImport, 'privacy': L10n.current.privacyAndData,
                }.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _category = value ?? 'overig'),
            ),
            const SizedBox(height: 12),
            Text(L10n.current.supportSafeDetails, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjectController,
              textInputAction: TextInputAction.next,
              maxLength: 100,
              decoration:  InputDecoration(
                labelText: L10n.current.subject,
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? L10n.current.enterASubject
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _messageController,
              minLines: 4,
              maxLines: 7,
              maxLength: 5000,
              decoration:  InputDecoration(
                labelText: L10n.current.yourQuestionOrProblem,
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? L10n.current.brieflyDescribeWhatYouNeedHelpWith
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
                    category: _category,
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label:  Text(L10n.current.sendQuestion),
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
  final String category;

  const _NewSupportQuestion({
    required this.subject,
    required this.message,
    required this.name,
    required this.email,
    required this.category,
  });
}

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF343B67), Color(0xFF5967A3)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child:  Row(
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
                Text(L10n.current.personalSupport,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(L10n.current.findYourQuestionsAndOurRepliesIn,
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
  final bool showAction;

  const _SupportEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    this.showAction = true,
  });

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
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
              if (showAction) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(buttonLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
