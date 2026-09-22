import 'package:paskluis_v1/l10n/l10n.dart';
import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title:  Text(L10n.current.privacyAndData),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF27313D),
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          children:  [
          _PrivacyHero(),
          SizedBox(height: 18),
          _PrivacySection(
            icon: Icons.phone_iphone_rounded,
            title: L10n.current.staysOnYourPhone,
            color: Color(0xFF23814A),
            points: [
              L10n.current.loyaltyCardsQrCodesAndGiftCards,
              L10n.current.barcodesCardNumbersPinsAndScratchCodes,
              L10n.current.balancesNotesAndImportedImages,
              L10n.current.savedCardUsageLocationsForNearbyCards,
            ],
          ),
          _PrivacySection(
            icon: Icons.cloud_outlined,
            title: L10n.current.onlyOnlineWhenYouUseIt,
            color: Color(0xFF286DC8),
            points: [
              L10n.current.yourAccountNameEmailAddressAndPlus,
              L10n.current.aCardYouDeliberatelyShareWithSomeone,
              L10n.current.questionsAndMessagesYouSendToCustomer,
              L10n.current.publicStoreInformationAndLogosRetrievedBy,
            ],
          ),
          _PrivacySection(
            icon: Icons.visibility_off_outlined,
            title: L10n.current.notVisibleInTheAdminPortal,
            color: Color(0xFFD51B46),
            points: [
              L10n.current.yourRegularLocalCardsAndCodes,
              L10n.current.pinsOrScratchCodesOfUnsharedGift,
              L10n.current.yourPreciseLocationOrLocationHistory,
              L10n.current.whichCardYouOpenWhereAndWhen,
            ],
          ),
          _PrivacySection(
            icon: Icons.share_outlined,
            title: L10n.current.whenSharingACard,
            color: Color(0xFFA26D00),
            points: [
              L10n.current.youChooseWhichCardToShareAnd,
              L10n.current.aGiftCardIsAlwaysSharedIn,
              L10n.current.youCanStopSharedAccessLater,
              L10n.current.recipientsWithoutPlusCanOnlyViewCards,
            ],
          ),
          _PrivacySection(
            icon: Icons.security_rounded,
            title: L10n.current.securityAndYourChoices,
            color: Color(0xFF7046B8),
            points: [
              L10n.current.youCanLockPaskluisWithFaceId,
              L10n.current.sensitiveCodesCanStayHiddenByDefault,
              L10n.current.youCanDisableLocationBasedCardsEntirely,
              L10n.current.signingOutDoesNotRemoveYourLocal,
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text(
              L10n.current.paskluisDoesNotSellPersonalDataOr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5D6875), height: 1.45),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero();

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF174B7A), Color(0xFF2879B9)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child:  Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_rounded, color: Colors.white, size: 40),
          SizedBox(height: 13),
          Text(L10n.current.yourPaskluisBelongsToYou,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900)),
          SizedBox(height: 7),
          Text(
            L10n.current.yourMostImportantDataStaysLocallyOn,
            style: TextStyle(color: Color(0xFFE7F3FF), height: 1.42),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> points;

  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.color,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .11),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...points.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, color: color, size: 18),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(point,
                          style: const TextStyle(
                              color: Color(0xFF55515A), height: 1.38)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
