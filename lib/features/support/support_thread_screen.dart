import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';
import '../../data/services/support_service.dart';

class SupportThreadScreen extends StatefulWidget {
  final SupportThread thread;

  const SupportThreadScreen({super.key, required this.thread});

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  List<SupportMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages(scroll: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool scroll = false}) async {
    try {
      final messages = await SupportService.loadMessages(widget.thread.id);
      if (!mounted) return;
      final changed = messages.length != _messages.length;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      if (scroll || changed) _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || widget.thread.status == 'closed') return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await SupportService.sendMessage(widget.thread.id, text);
      _messageController.clear();
      await _loadMessages(scroll: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bericht kon niet worden verstuurd.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final closed = widget.thread.status == 'closed';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(widget.thread.subject),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        actions: [
          IconButton(
            tooltip: 'Vernieuwen',
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(child: Text('Nog geen berichten.'))
                : RefreshIndicator(
                    onRefresh: () => _loadMessages(),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final user = AccountService.currentUser;
                        final mine = user == null
                            ? message.senderId.isEmpty
                            : message.senderId == user.id;
                        return _MessageBubble(message: message, mine: mine);
                      },
                    ),
                  ),
          ),
          if (closed)
            const SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Dit gesprek is gesloten.'),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE9E6EC))),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 5000,
                        decoration: const InputDecoration(
                          hintText: 'Schrijf een bericht…',
                          counterText: '',
                          filled: true,
                          fillColor: Color(0xFFF6F4F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(18)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Versturen',
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessage message;
  final bool mine;

  const _MessageBubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFD51B46) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.message,
              style: TextStyle(color: mine ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 5),
            Text(
              _time(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: mine ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}-${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
