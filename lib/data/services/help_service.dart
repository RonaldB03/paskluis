import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import 'locale_service.dart';

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

  factory HelpFaq.fromJson(Map<String, dynamic> json, {String language = 'nl'}) {
    final suffix = language == 'en' ? '_en' : '';
    return HelpFaq(
      id: json['id']?.toString() ?? '',
      category: json['category$suffix']?.toString() ?? L10n.current.general,
      question: json['question$suffix']?.toString() ?? '',
      answer: json['answer$suffix']?.toString() ?? '',
    );
  }

}

abstract final class HelpService {
  static List<HelpFaq> get fallbackFaqs => <HelpFaq>[
    HelpFaq(
      id: 'add',
      category: L10n.current.addingCards,
      question: L10n.current.howDoIAddACard,
      answer:
          L10n.current.tapChooseALoyaltyCardQrCode,
    ),
    HelpFaq(
      id: 'local',
      category: L10n.current.privacy,
      question: L10n.current.whereAreMyCardsStored,
      answer:
          L10n.current.yourCardsBarcodesPinsAndImagesAre,
    ),
    HelpFaq(
      id: 'share',
      category: L10n.current.share,
      question: L10n.current.howDoesASharedCardWork,
      answer:
          L10n.current.theSenderNeedsPlusRecipientsWithoutPlus,
    ),
    HelpFaq(
      id: 'gift',
      category: 'PasKluis Plus',
      question: L10n.current.whatDoIGetWithPaskluisPlus,
      answer:
          L10n.current.withPlusYouCanStoreUnlimitedGift,
    ),
  ];

  static Future<List<HelpFaq>> loadFaqs() async {
    final language = LocaleService.languageCode;
    final client = SupabaseService.client;
    if (client == null) return fallbackFaqs;
    try {
      final rows = await client
          .from('help_faqs')
          .select('id, category, question, answer, category_en, question_en, answer_en')
          .eq('is_active', true)
          .order('sort_order')
          .order('question');
      final result = rows.map((row) => HelpFaq.fromJson(row, language: language)).where((item) =>
          item.question.trim().isNotEmpty && item.answer.trim().isNotEmpty).toList();
      return result.isEmpty ? fallbackFaqs : result;
    } on PostgrestException {
      return fallbackFaqs;
    } catch (_) {
      return fallbackFaqs;
    }
  }
}
