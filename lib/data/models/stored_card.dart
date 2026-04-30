import '../../shared/enums/card_status.dart';

class StoredCard {
  final String id;
  final String name;
  final String type;
  final String codeValue;
  final String codeFormat;
  final bool isFavorite;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CardStatus status;

  final String? cardNumber;
  final String? pinCode;
  final double? initialBalance;
  final double? currentBalance;
  final DateTime? expiryDate;
  final DateTime? usedAt;
  final DateTime? archivedAt;

  const StoredCard({
    required this.id,
    required this.name,
    required this.type,
    required this.codeValue,
    required this.codeFormat,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.note,
    this.cardNumber,
    this.pinCode,
    this.initialBalance,
    this.currentBalance,
    this.expiryDate,
    this.usedAt,
    this.archivedAt,
  });
}