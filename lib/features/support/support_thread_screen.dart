import 'package:image_picker/image_picker.dart';
import 'package:paskluis_v1/l10n/l10n.dart';
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
  List<Map<String,dynamic>> _attachments=[];
  DateTime? _attachmentRefresh;
  late String _status = widget.thread.status;

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
      if(_attachmentRefresh==null || DateTime.now().difference(_attachmentRefresh!).inSeconds>180 || messages.length!=_messages.length){
        try {
          final attachments=await SupportService.loadAttachments(widget.thread.id);
          if(mounted){_attachments=attachments;_attachmentRefresh=DateTime.now();}
        } catch (_) {}
      }
      final threads = await SupportService.loadThreads();
      final latest = threads.where((t) => t.id == widget.thread.id).firstOrNull;
      if (!mounted) return;
      final changed = messages.length != _messages.length;
      setState(() {
        _messages = messages;
        _status = latest?.status ?? _status;
        _loading = false;
      });
      if (scroll || changed) _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ?  Center(child: Text(L10n.current.noMessagesYet))
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
                        final mine = message.senderKind == 'guest' ||
                            (message.senderKind == 'user' && message.senderId == user?.id);
                        return _MessageBubble(message: message, mine: mine, attachments: _attachments.where((a)=>a['message_id']==message.id).map((a)=>a['url'] as String).toList());
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

class _MessageBubble extends StatelessWidget {
  final SupportMessage message;
  final bool mine;
  final List<String> attachments;

  const _MessageBubble({required this.message, required this.mine, this.attachments=const []});

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
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
            if (message.senderKind == 'automatic')
              Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Text(L10n.current.automaticAcknowledgement, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            Text(
              message.message,
              style: TextStyle(color: mine ? Colors.white : Colors.black87),
            ),
            for(final url in attachments) Padding(padding:const EdgeInsets.only(top:10),child:
              InkWell(onTap:()=>showDialog<void>(context:context,builder:(dialogContext)=>Dialog(
                child:Column(mainAxisSize:MainAxisSize.min,children:[
                  Flexible(child:InteractiveViewer(child:Image.network(url,fit:BoxFit.contain))),
                  TextButton(onPressed:()=>Navigator.pop(dialogContext),child:Text(L10n.current.close)),
                ]),
              )),child:Image.network(url,height:180,fit:BoxFit.contain,
                errorBuilder:(_,__,___)=>Text(L10n.current.screenshotUnavailable))),
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
