import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_service.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

abstract final class GiftCardShareService {
  static SupabaseClient get _client {
    final client = SupabaseService.client;
    if (client == null) throw  AuthException(L10n.current.onlineServicesAreUnavailable);
    return client;
  }

  static Map<String, dynamic> _safePayload(Map<String, dynamic> card) => {
        'name': card['name']?.toString() ?? '',
        'code': card['code']?.toString() ?? '',
        'codeFormat': card['codeFormat']?.toString() ?? 'barcode',
        'barcodeSymbology': card['barcodeSymbology']?.toString() ?? '',
        'cardNumber': card['cardNumber']?.toString() ?? '',
        'pinCode': card['pinCode']?.toString() ?? '',
        'initialBalance': card['initialBalance']?.toString() ?? '',
        'currentBalance': card['currentBalance']?.toString() ?? '',
        'note': card['note']?.toString() ?? '',
        'brandId': card['brandId']?.toString() ?? '',
        'logoAsset': card['logoAsset']?.toString() ?? '',
        'brandColor': card['brandColor']?.toString() ?? '',
        'expiryDate': card['expiryDate']?.toString() ?? '',
        'balanceHistory': card['balanceHistory']?.toString() ?? '[]',
      };

  static Future<void> shareWithEmail(Map<String, dynamic> card, String email) async {
    final user = AccountService.currentUser;
    if (user == null) throw  AuthException(L10n.current.signInToShareACard);
    final status = await AccountService.loadPlusStatus();
    if (!status.isActive) throw  AuthException(L10n.current.paskluisPlusIsRequiredToShareCards);
    await _client.rpc('share_gift_card_by_email', params: {
      'p_recipient_email': email.trim(),
      'p_card_external_id': card['id']?.toString() ?? '',
      'p_card_payload': _safePayload(card),
    });
  }

  static Future<void> syncOwnedCard(Map<String, dynamic> card) async {
    final user = AccountService.currentUser;
    final id = card['id']?.toString() ?? '';
    if (user == null || id.isEmpty || card['isShared'] == true) return;
    await _client.from('gift_card_shares').update({
      'card_payload': _safePayload(card),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('owner_id', user.id).eq('card_external_id', id).isFilter('revoked_at', null);
  }

  static Future<void> revokeAllForCard(String cardId) async {
    final user = AccountService.currentUser;
    if (user == null || cardId.isEmpty) return;
    await _client.from('gift_card_shares').update({
      'revoked_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('owner_id', user.id).eq('card_external_id', cardId);
  }

  static Future<List<Map<String, dynamic>>> outgoingForCard(String cardId) async {
    final user = AccountService.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('gift_card_shares')
        .select('id, recipient_email, created_at')
        .eq('owner_id', user.id)
        .eq('card_external_id', cardId)
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> revokeShare(String shareId) async {
    final user = AccountService.currentUser;
    if (user == null) return;
    await _client.from('gift_card_shares').update({
      'revoked_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', shareId).eq('owner_id', user.id);
  }

  static Future<void> syncIncomingToLocal() async {
    final user = AccountService.currentUser;
    if (user == null || !SupabaseService.isAvailable) return;
    final rows = await _client
        .from('gift_card_shares')
        .select('id, owner_id, card_payload, updated_at')
        .eq('recipient_id', user.id)
        .isFilter('revoked_at', null);

    final activeIds = <String>{};
    for (final row in rows) {
      final shareId = row['id']?.toString() ?? '';
      final payload = row['card_payload'];
      if (shareId.isEmpty || payload is! Map) continue;
      activeIds.add(shareId);
      final card = <String, dynamic>{
        ...Map<String, dynamic>.from(payload),
        'id': 'shared:$shareId',
        'type': 'Cadeaukaart',
        'shareId': shareId,
        'shareOwnerId': row['owner_id']?.toString() ?? '',
        'isShared': true,
        'isFavorite': false,
        'isArchived': false,
        'customImage': '',
        'createdAt': row['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
        'updatedAt': row['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
      dynamic existingKey;
      for (final key in StorageService.cardsBox.keys) {
        final existing = StorageService.cardsBox.get(key);
        if (existing is Map && existing['shareId']?.toString() == shareId) existingKey = key;
      }
      if (existingKey == null) {
        await StorageService.cardsBox.add(card);
      } else {
        await StorageService.saveCard(existingKey, card);
      }
    }

    for (final key in StorageService.cardsBox.keys.toList()) {
      final card = StorageService.cardsBox.get(key);
      if (card is Map && card['isShared'] == true && !activeIds.contains(card['shareId']?.toString())) {
        await StorageService.deleteCard(key);
      }
    }
  }
}
