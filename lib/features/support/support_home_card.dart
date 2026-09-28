import 'dart:async';
import 'package:flutter/material.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
import '../../data/services/account_service.dart';
import '../../data/services/support_service.dart';
import '../../data/services/supabase_service.dart';
import 'support_screen.dart';
import 'support_thread_screen.dart';

class SupportHomeCard extends StatefulWidget {
  const SupportHomeCard({super.key});
  @override
  State<SupportHomeCard> createState() => _SupportHomeCardState();
}

class _SupportHomeCardState extends State<SupportHomeCard> with WidgetsBindingObserver {
  List<SupportThread> _threads = [];
  Timer? _timer;
  StreamSubscription<String>? _changes;
  StreamSubscription<dynamic>? _auth;
  bool _loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changes = SupportService.conversationChanges.listen((_) => _refresh());
    _auth = SupabaseService.client?.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      _generation++;
      setState(() => _threads = []);
      _refresh();
    });
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _changes?.cancel();
    _auth?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted || _loading || ModalRoute.of(context)?.isCurrent != true ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) return;
    final generation = _generation;
    final user = AccountService.currentUser?.id;
    _loading = true;
    try {
      final threads = await SupportService.loadThreads().timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation || user != AccountService.currentUser?.id) return;
      setState(() => _threads = threads.where((t) => t.showOnHome).toList());
    } catch (_) {
      // An unavailable inbox must not block access to cards.
    } finally { _loading = false; }
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    if (_threads.isEmpty) return const SizedBox.shrink();
    final unread = _threads.any((t) => t.hasUnreadReply);
    final single = _threads.length == 1;
    final title = unread ? L10n.current.supportHomeUnread :
      single && _threads.first.lastStaffReplyAt == null ? L10n.current.supportHomeWaiting :
      L10n.current.supportHomeOpen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        color: unread ? const Color(0xFFFFE7ED) : Colors.white,
        child: ListTile(
          leading: Icon(unread ? Icons.mark_chat_unread_outlined : Icons.chat_bubble_outline,
            color: const Color(0xFFD51B46)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(single ? L10n.current.supportHomeView :
            '${_threads.length} · ${L10n.current.supportHomeMultiple}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => single ? SupportThreadScreen(thread: _threads.first) : const SupportScreen(),
            ));
            _refresh();
          },
        ),
      ),
    );
  }
}
