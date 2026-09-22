import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../data/services/help_service.dart';
import '../support/support_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  late Future<List<HelpFaq>> _faqs;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _faqs = HelpService.loadFaqs();
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F7),
      appBar: AppBar(
        title:  Text(L10n.current.helpAndGuidance),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D2A31),
      ),
      body: FutureBuilder<List<HelpFaq>>(
        future: _faqs,
        builder: (context, snapshot) {
          final faqs = snapshot.data ?? const <HelpFaq>[];
          final query = _query.trim().toLowerCase();
          final visible = faqs.where((faq) => query.isEmpty ||
              faq.question.toLowerCase().contains(query) ||
              faq.answer.toLowerCase().contains(query) ||
              faq.category.toLowerCase().contains(query)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5E428D), Color(0xFF8C68C8)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child:  Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 36),
                    SizedBox(height: 12),
                    Text(L10n.current.howCanWeHelp,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 6),
                    Text(
                      L10n.current.findHelpWithAddingScanningSharingPrivacy,
                      style: TextStyle(
                          color: Color(0xFFF4EBFF), fontSize: 15, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: L10n.current.searchQuestions,
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
               Text(L10n.current.frequentlyAskedQuestions,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visible.isEmpty)
                 Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(L10n.current.noMatchingQuestionsFound,
                      textAlign: TextAlign.center),
                )
              else
                ...visible.map((faq) => _FaqCard(faq: faq)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                     Text(L10n.current.cannotFindYourQuestion,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                     Text(L10n.current.ourCustomerSupportIsAvailableToEveryone,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6F6A74))),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SupportScreen()),
                      ),
                      icon: const Icon(Icons.support_agent_rounded),
                      label:  Text(L10n.current.contactUs),
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

class _FaqCard extends StatelessWidget {
  final HelpFaq faq;

  const _FaqCard({required this.faq});

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(17, 0, 17, 18),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEFE8FF),
          child: Icon(Icons.help_outline_rounded, color: Color(0xFF7046B8)),
        ),
        title: Text(faq.question,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(faq.category,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7046B8))),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(faq.answer,
                style: const TextStyle(height: 1.48, color: Color(0xFF55515A))),
          ),
        ],
      ),
    );
  }
}
