import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class HelpFaq {
  final String id;
  final String category;
  final String question;
  final String answer;

  const HelpFaq({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  factory HelpFaq.fromJson(Map<String, dynamic> json) => HelpFaq(
        id: json['id']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Algemeen',
        question: json['question']?.toString() ?? '',
        answer: json['answer']?.toString() ?? '',
      );
}

abstract final class HelpService {
  static const fallbackFaqs = <HelpFaq>[
    HelpFaq(
      id: 'add',
      category: 'Kaarten toevoegen',
      question: 'Hoe voeg ik een kaart toe?',
      answer:
          'Tik rechtsboven op +. Kies daarna een klantenkaart, QR-code of cadeaukaart. Je kunt de code scannen, handmatig invoeren of een foto of screenshot importeren.',
    ),
    HelpFaq(
      id: 'local',
      category: 'Privacy',
      question: 'Waar worden mijn kaarten bewaard?',
      answer:
          'Je kaarten, barcodes, pincodes en afbeeldingen worden lokaal op je telefoon bewaard. Ze worden niet automatisch naar PasKluis of het beheer geüpload.',
    ),
    HelpFaq(
      id: 'share',
      category: 'Delen',
      question: 'Hoe werkt een gedeelde kaart?',
      answer:
          'De verzender heeft Plus nodig. Zonder Plus kan de ontvanger de kaart bekijken. Hebben jullie allebei Plus, dan kunnen jullie de kaart allebei bijwerken.',
    ),
    HelpFaq(
      id: 'gift',
      category: 'PasKluis Plus',
      question: 'Wat krijg ik met PasKluis Plus?',
      answer:
          'Met Plus bewaar je onbeperkt cadeaukaarten en kun je klanten- en cadeaukaarten delen. Plus is een eenmalige aankoop en geen abonnement.',
    ),
  ];

  static Future<List<HelpFaq>> loadFaqs() async {
    final client = SupabaseService.client;
    if (client == null) return fallbackFaqs;
    try {
      final rows = await client
          .from('help_faqs')
          .select('id, category, question, answer')
          .eq('is_active', true)
          .order('sort_order')
          .order('question');
      final result = rows.map(HelpFaq.fromJson).where((item) =>
          item.question.trim().isNotEmpty && item.answer.trim().isNotEmpty).toList();
      return result.isEmpty ? fallbackFaqs : result;
    } on PostgrestException {
      return fallbackFaqs;
    } catch (_) {
      return fallbackFaqs;
    }
  }
}
