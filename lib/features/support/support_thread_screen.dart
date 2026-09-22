import 'package:image_picker/image_picker.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/support_service.dart';

class SupportThreadScreen extends StatefulWidget {
  final SupportThread thread;

  final Future<SupportConversation> Function()? loadConversation;
  final Future<List<Map<String, dynamic>>> Function()? loadAttachments;

  const SupportThreadScreen({super.key, required this.thread,
    this.loadConversation, this.loadAttachments});

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  StreamSubscription<String>? _conversationSubscription;
  int _requestVersion = 0;
  bool _fetching = false;
  bool _loadFailed = false;
  List<SupportMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  List<Map<String,dynamic>> _attachments=[];
  DateTime? _attachmentRefresh;
  late String _status = widget.thread.status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversationSubscription = SupportService.conversationChanges.listen((id) {
      if (id == widget.thread.id) _loadMessages();
    });
    _loadMessages(scroll: true);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) { if (!_fetching) _loadMessages(); },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _requestVersion++;
    _conversationSubscription?.cancel();
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadMessages();
  }

  Future<void> _loadMessages({bool scroll = false}) async {
    final request = ++_requestVersion;
    final userId = AccountService.currentUser?.id;
    _fetching = true;
    try {
      final conversation = await (widget.loadConversation?.call() ??
        SupportService.loadConversation(widget.thread.id, fallbackThread: widget.thread))
        .timeout(const Duration(seconds: 20));
      if (!mounted || request != _requestVersion) return;
      if (AccountService.currentUser?.id != userId) {
        setState(() { _messages = []; _attachments = []; _loading = false; _loadFailed = true; });
        return;
      }
      final changed = conversation.messages.length != _messages.length ||
        conversation.messages.lastOrNull?.id != _messages.lastOrNull?.id;
      final nearBottom = !_scrollController.hasClients ||
        _scrollController.position.extentAfter < 100;
      // Publish the conversation before fetching optional screenshot previews.
      setState(() {
        _messages = conversation.messages;
        _status = conversation.thread.status;
        _loading = false;
        _loadFailed = false;
      });
      if (scroll || (changed && nearBottom)) _scrollToBottom();
      if (_attachmentRefresh == null || changed ||
          DateTime.now().difference(_attachmentRefresh!).inSeconds > 180) {
        unawaited(_loadAttachments(request));
      }
    } catch (error) {
      if (mounted && request == _requestVersion) {
        setState(() {
          _loading = false;
          _loadFailed = true;
          if (AccountService.currentUser?.id != userId || error is AuthException ||
              (error is PostgrestException && error.code == '42501')) {
            _messages = [];
            _attachments = [];
          }
        });
      }
    } finally {
      if (request == _requestVersion) _fetching = false;
    }
  }

  Future<void> _loadAttachments(int request) async {
    try {
      final attachments = await (widget.loadAttachments?.call() ??
        SupportService.loadAttachments(widget.thread.id)).timeout(const Duration(seconds: 15));
      if (!mounted || request != _requestVersion) return;
      setState(() { _attachments = attachments; _attachmentRefresh = DateTime.now(); });
    } catch (_) {
      // Messages remain visible and attachment retrieval can retry independently.
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || _status == 'closed') return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await SupportService.sendMessage(widget.thread.id, text);
      _messageController.clear();
      await _loadMessages(scroll: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(L10n.current.theMessageCouldNotBeSent)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendScreenshot() async {
    if(_sending || _status=='closed')return;
    try {
      final picked=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1600,maxHeight:1600,imageQuality:80);
      if(picked==null || !mounted)return;
      final bytes=await picked.readAsBytes();
      if(!mounted)return;
      if(bytes.length>5*1024*1024)throw StateError('IMAGE_TOO_LARGE');
      final send=await showDialog<bool>(context:context,builder:(dialogContext)=>AlertDialog(
        title:Text(L10n.current.sendScreenshot),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(L10n.current.screenshotPrivacy),const SizedBox(height:12),
          Image.memory(bytes,height:220,fit:BoxFit.contain),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:Text(L10n.current.cancel)),
          FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:Text(L10n.current.send))],
      ));
      if(send!=true || !mounted)return;
      setState(()=>_sending=true);
      await SupportService.sendScreenshot(widget.thread.id,bytes);
      _attachmentRefresh=null;
      await _loadMessages(scroll:true);
    } catch (_) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(L10n.current.screenshotFailed)));
    } finally {if(mounted)setState(()=>_sending=false);}
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
    L10n.watch(context);
    final closed = _status == 'closed';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(widget.thread.subject),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        actions: [
          IconButton(
            tooltip: L10n.current.refresh,
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loadFailed)
            MaterialBanner(
              content: Text(L10n.current.supportMessagesLoadFailed),
              actions: [TextButton(onPressed: () => _loadMessages(),
                child: Text(L10n.current.refresh))],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadMessages(),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
                      itemCount: _messages.isEmpty ? 1 : _messages.length,
                      itemBuilder: (context, index) {
                        if (_messages.isEmpty) return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(child: Text(L10n.current.noMessagesYet)),
                        );
                        final message = _messages[index];
                        return SupportMessageBubble(key: ValueKey(message.id), message: message, attachments: _attachments.where((a)=>a['message_id']==message.id).map((a)=>a['url'] as String).toList());
                      },
                    ),
                  ),
          ),
          if (closed)
             SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(L10n.current.thisConversationIsClosed),
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
                    IconButton(tooltip:L10n.current.sendScreenshot,onPressed:_sending?null:_sendScreenshot,icon:const Icon(Icons.attach_file_rounded)),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 5000,
                        decoration:  InputDecoration(
                          hintText: L10n.current.writeAMessage,
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
                      tooltip: L10n.current.send,
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

class SupportMessageBubble extends StatelessWidget {
  final SupportMessage message;
  final List<String> attachments;

  const SupportMessageBubble({super.key, required this.message, this.attachments = const []});

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    final automatic = message.senderKind == 'automatic';
    final mine = message.senderKind == 'user' || message.senderKind == 'guest';
    final name = message.senderName?.trim() ?? '';
    final label = automatic ? L10n.current.automaticAcknowledgement : mine
      ? L10n.current.supportYou : name.isEmpty ? 'Team PasKluis' : '$name · PasKluis';
    final textColor = mine ? Colors.white : const Color(0xFF292733);
    return LayoutBuilder(builder: (context, constraints) => Align(
      alignment: automatic ? Alignment.center : mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth * (automatic ? .95 : .88)),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
        decoration: BoxDecoration(
          color: automatic ? const Color(0xFFEBECF2) : mine ? const Color(0xFFD51B46) : Colors.white,
          border: mine || automatic ? null : Border.all(color: const Color(0xFFE4E0EB)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine || automatic ? 18 : 4),
            bottomRight: Radius.circular(mine && !automatic ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!mine) ...[
                Icon(automatic ? Icons.info_outline_rounded : Icons.support_agent_rounded,
                  size: 16, color: const Color(0xFF535B90)),
                const SizedBox(width: 6),
              ],
              Flexible(child: Text(label, style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: mine ? Colors.white : const Color(0xFF535B90)))),
            ]),
            const SizedBox(height: 7),
            Text(message.message, style: TextStyle(color: textColor, height: 1.4)),
            for (final url in attachments) Padding(padding: const EdgeInsets.only(top: 10), child:
              InkWell(onTap: () => showDialog<void>(context: context, builder: (dialogContext) => Dialog(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(L10n.current.close)),
                ]),
              )), child: Image.network(url, height: 180, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(L10n.current.screenshotUnavailable, style: TextStyle(color: textColor)))),
            ),
            const SizedBox(height: 7),
            Align(alignment: Alignment.centerRight, child: Text(_time(message.createdAt),
              style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : Colors.black54))),
          ],
        ),
      ),
    ));
  }

  static String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}-${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
