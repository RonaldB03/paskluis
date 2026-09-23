import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

abstract final class CardShareService {
  static SupabaseClient get _client {
    final client = SupabaseService.client;
    if (client == null) {
      throw  AuthException(L10n.current.onlineServicesAreUnavailable);
    }
    return client;
  }

  static Map<String, dynamic> safePayload(Map<String, dynamic> card) => {
        'name': card['name']?.toString() ?? '',
        'type': card['type']?.toString() ?? 'Pasje',
        'code': card['code']?.toString() ?? '',
        'codes': card['codes']?.toString() ?? '',
        'used': card['used']?.toString() ?? '',
        'codeFormat': card['codeFormat']?.toString() ?? 'barcode',
        'barcodeSymbology': card['barcodeSymbology']?.toString() ?? '',
        'cardNumber': card['cardNumber']?.toString() ?? '',
        // The owner explicitly chose to share the complete gift card.
        'pinCode': card['pinCode']?.toString() ?? '',
        'initialBalance': card['initialBalance']?.toString() ?? '',
        'currentBalance': card['currentBalance']?.toString() ?? '',
        'note': card['note']?.toString() ?? '',
        'brandId': card['brandId']?.toString() ?? '',
        'logoAsset': card['logoAsset']?.toString() ?? '',
        'brandColor': card['brandColor']?.toString() ?? '',
        'expiryDate': card['expiryDate']?.toString() ?? '',
        'expiryNotificationsEnabled':
            card['expiryNotificationsEnabled'] == true ||
                card['expiryNotificationsEnabled']?.toString() == 'true',
        'balanceHistory': card['balanceHistory']?.toString() ?? '[]',
      };

  static Future<Map<String, dynamic>> shareWithEmail(
    Map<String, dynamic> card,
    String email,
  ) async {
    final user = AccountService.currentUser;
    if (user == null) {
      throw  AuthException(L10n.current.signInToShareACard);
    }
    final status = await AccountService.loadPlusStatus();
    if (!status.isActive) {
      throw  AuthException(
        L10n.current.paskluisPlusIsRequiredToShareCards,
      );
    }
    final result = await _client.rpc(
      'share_card_by_email',
      params: {
        'p_recipient_email': email.trim(),
        'p_card_external_id': card['id']?.toString() ?? '',
        'p_card_type': card['type']?.toString() ?? 'Pasje',
        'p_card_payload': safePayload(card),
      },
    );
    final share = Map<String, dynamic>.from(result as Map);
    final membershipId = share['membership_id']?.toString() ?? '';
    if (membershipId.isNotEmpty) {
      try {
        await _client.functions.invoke(
          'send-shared-card-notification',
          body: {'membership_id': membershipId},
        );
      } catch (_) {
        // The card is already shared. A temporary push failure must not turn
        // a successful share into an error for the sender.
      }
    }
    return share;
  }

  static Future<Map<String, dynamic>> updateSharedCard(
    Map<String, dynamic> card,
  ) async {
    final sharedCardId = card['sharedCardId']?.toString() ?? '';
    if (sharedCardId.isEmpty) return card;
    final version = int.tryParse(card['sharedVersion']?.toString() ?? '') ?? 1;
    final result = await _client.rpc(
      'update_shared_card',
      params: {
        'p_shared_card_id': sharedCardId,
        'p_expected_version': version,
        'p_card_payload': safePayload(card),
      },
    );
    final next = Map<String, dynamic>.from(card);
    next['sharedVersion'] = result is int
        ? result
        : int.tryParse(result.toString()) ?? version + 1;
    return next;
  }

  static Future<List<Map<String, dynamic>>> outgoingForCard(
    String cardId,
  ) async {
    final user = AccountService.currentUser;
    if (user == null) return [];
    final cards = await _client
        .from('shared_cards')
        .select(
          'id, version, card_share_members(id, recipient_email, created_at, revoked_at)',
        )
        .eq('owner_id', user.id)
        .eq('card_external_id', cardId)
        .maybeSingle();
    if (cards == null) return [];
    final members = cards['card_share_members'];
    if (members is! List) return [];
    return members
        .where(
          (member) => member is Map && member['revoked_at'] == null,
        )
        .map((member) => Map<String, dynamic>.from(member as Map))
        .toList();
  }

  static Future<void> revokeShare(String membershipId) async {
    if (membershipId.isEmpty) return;
    await _client.rpc(
      'revoke_shared_card_access',
      params: {'p_membership_id': membershipId},
    );
  }

  static Future<void> revokeAllForCard(String cardId) async {
    if (cardId.isEmpty || AccountService.currentUser == null) return;
    await _client.rpc(
      'revoke_all_shared_card_access',
      params: {'p_card_external_id': cardId},
    );
  }

  static Future<void> removeReceivedCard(String membershipId) async {
    if (membershipId.isEmpty) return;
    await _client.rpc(
      'remove_received_shared_card',
      params: {'p_membership_id': membershipId},
    );
  }

  static Future<void> syncAllToLocal() async {
    if (AccountService.currentUser == null || !SupabaseService.isAvailable) {
      return;
    }
    await _syncIncomingToLocal();
    await _syncOwnedToLocal();
  }

  static Future<void> _syncIncomingToLocal() async {
    final user = AccountService.currentUser;
    if (user == null) return;
    final revision = StorageService.accountRevision;
    bool current() => AccountService.currentUser?.id == user.id &&
        StorageService.accountId == user.id &&
        StorageService.accountRevision == revision;
    final plus = await AccountService.loadPlusStatus();
    final rows = await _client
        .from('card_share_members')
        .select(
          'id, shared_card_id, shared_cards!inner(id, owner_id, card_type, card_payload, version, updated_at)',
        )
        .eq('recipient_id', user.id)
        .isFilter('revoked_at', null)
        .isFilter('removed_by_recipient_at', null);

    final activeMembershipIds = <String>{};
    if (!current()) return;
    for (final rawRow in rows) {
      if (!current()) return;
      final row = Map<String, dynamic>.from(rawRow);
      final membershipId = row['id']?.toString() ?? '';
      final shared = row['shared_cards'];
      if (membershipId.isEmpty || shared is! Map) continue;
      final sharedCard = Map<String, dynamic>.from(shared);
      final payload = sharedCard['card_payload'];
      if (payload is! Map) continue;
      activeMembershipIds.add(membershipId);
      final local = <String, dynamic>{
        ...Map<String, dynamic>.from(payload),
        'id': 'shared:$membershipId',
        'type': sharedCard['card_type']?.toString() ?? 'Pasje',
        'shareMembershipId': membershipId,
        'sharedCardId': sharedCard['id']?.toString() ?? '',
        'shareOwnerId': sharedCard['owner_id']?.toString() ?? '',
        'shareRecipientId': user.id,
        'sharedVersion': sharedCard['version'] ?? 1,
        'canEditShared': plus.isActive,
        'isShared': true,
        'isFavorite': false,
        'isArchived': false,
        'customImage': '',
        'createdAt': sharedCard['updated_at']?.toString() ??
            DateTime.now().toIso8601String(),
        'updatedAt': sharedCard['updated_at']?.toString() ??
            DateTime.now().toIso8601String(),
      };
      dynamic existingKey;
      for (final key in StorageService.cardsBox.keys) {
        final existing = StorageService.cardsBox.get(key);
        if (existing is Map &&
            existing['shareMembershipId']?.toString() == membershipId) {
          existingKey = key;
          local['isFavorite'] = existing['isFavorite'] == true;
          break;
        }
      }
      if (existingKey == null) {
        await StorageService.addCard(local);
        try {
          await NotificationService.showSharedCardReceived(local);
          await NotificationService.syncGiftCard(local);
        } catch (_) {
          // Receiving the shared card must also work without permission.
        }
      } else {
        await StorageService.saveCard(existingKey, local);
        try {
          await NotificationService.syncGiftCard(local);
        } catch (_) {
          // Reminder scheduling is best effort.
        }
      }
    }

    for (final key in StorageService.cardsBox.keys.toList()) {
      if (!current()) return;
      final card = StorageService.cardsBox.get(key);
      if (card is Map &&
          card['isShared'] == true &&
          !activeMembershipIds.contains(
            card['shareMembershipId']?.toString(),
          )) {
        await StorageService.deleteCard(key);
      }
    }
  }

  static Future<void> _syncOwnedToLocal() async {
    final user = AccountService.currentUser;
    if (user == null) return;
    final revision = StorageService.accountRevision;
    final rows = await _client
        .from('shared_cards')
        .select('id, card_external_id, card_type, card_payload, version, updated_at')
        .eq('owner_id', user.id)
        .isFilter('deleted_at', null);
    for (final rawRow in rows) {
      if (AccountService.currentUser?.id != user.id ||
          StorageService.accountId != user.id ||
          StorageService.accountRevision != revision) return;
      final row = Map<String, dynamic>.from(rawRow);
      final externalId = row['card_external_id']?.toString() ?? '';
      final payload = row['card_payload'];
      if (externalId.isEmpty || payload is! Map) continue;
      for (final key in StorageService.cardsBox.keys) {
        final existing = StorageService.cardsBox.get(key);
        if (existing is! Map ||
            existing['id']?.toString() != externalId ||
            existing['isShared'] == true) {
          continue;
        }
        final current = Map<String, dynamic>.from(existing);
        final remoteVersion = int.tryParse(row['version'].toString()) ?? 1;
        final localVersion =
            int.tryParse(current['sharedVersion']?.toString() ?? '') ?? 0;
        if (remoteVersion < localVersion) break;
        final merged = <String, dynamic>{
          ...current,
          ...Map<String, dynamic>.from(payload),
          'id': externalId,
          'type': row['card_type']?.toString() ?? current['type'],
          'sharedCardId': row['id']?.toString() ?? '',
          'sharedVersion': remoteVersion,
          'updatedAt': row['updated_at']?.toString() ?? current['updatedAt'],
        };
        await StorageService.saveCard(key, merged);
        break;
      }
    }
  }
}
