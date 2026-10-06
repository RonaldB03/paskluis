import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/account_service.dart';
import '../../data/services/locale_service.dart';
import '../../data/services/purchase_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/store_access_service.dart';
import '../../l10n/l10n.dart';

class PurchaseControls extends StatefulWidget {
  final bool gold;
  final bool showManagement;
  const PurchaseControls({
    super.key,
    this.gold = false,
    this.showManagement = true,
  });
  @override
  State<PurchaseControls> createState() => _PurchaseControlsState();
}

class _PurchaseControlsState extends State<PurchaseControls> {
  bool _active = false;
  bool _checking = true;
  String t(String nl, String en) =>
      LocaleService.languageCode == 'nl' ? nl : en;
  @override
  void initState() {
    super.initState();
    PurchaseService.revision.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(PurchaseService.loadProduct());
      _refresh();
    });
  }

  @override
  void dispose() {
    PurchaseService.revision.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (!PurchaseService.busy) _refresh();
  }

  Future<void> _refresh() async {
    final status = await AccountService.loadPlusStatus().catchError(
      (_) => PlusStatus.inactive,
    );
    if (mounted)
      setState(() {
        _active = status.isActive;
        _checking = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    L10n.watch(context);
    final busy = PurchaseService.busy;
    final product = PurchaseService.product;
    final loading = PurchaseService.loading || _checking;
    final enabled = SettingsService.storePurchaseEnabled;
    final userId = AccountService.currentUser?.id;
    final color = widget.gold ? Colors.white : null;
    final message = switch (PurchaseService.messageCode) {
      'success' => L10n.current.purchaseSucceeded,
      'pending' => L10n.current.purchasePending,
      'cancelled' => L10n.current.purchaseCancelled,
      'verification' => L10n.current.purchaseVerificationPending,
      'restoreRequested' => t(
        'Herstel aangevraagd. Verschijnt Plus niet? Controleer of je hetzelfde winkelaccount gebruikt als bij de aankoop.',
        'Restore requested. If Plus does not appear, check that you use the store account that made the purchase.',
      ),
      'revoked' => t(
        'Deze aankoop geeft geen actieve Plus-toegang meer.',
        'This purchase no longer provides active Plus access.',
      ),
      'linkFailed' => t(
        'Je winkelaankoop blijft bruikbaar. Koppelen is nog niet gelukt: controleer je verbinding en of deze aankoop al bij een ander PasKluis-account hoort.',
        'Your store purchase remains usable. Linking failed: check your connection and whether this purchase already belongs to another PasKluis account.',
      ),
      'failed' => L10n.current.purchaseFailed,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_active && widget.showManagement)
          Text(
            t('PasKluis Plus · Actief', 'PasKluis Plus · Active'),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          )
        else if (!_active)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: widget.gold
                  ? Colors.white
                  : const Color(0xFFD5A021),
              foregroundColor: const Color(0xFF513900),
            ),
            onPressed: busy || loading || product == null || !enabled
                ? null
                : PurchaseService.buy,
            icon: const Icon(Icons.workspace_premium_rounded),
            label: Text(
              busy
                  ? L10n.current.purchaseProcessing
                  : loading
                  ? t('Prijs ophalen…', 'Loading price…')
                  : product == null
                  ? t('Aankoop niet beschikbaar', 'Purchase unavailable')
                  : '${product.price} · ${t('eenmalig kopen', 'buy once')}',
            ),
          ),
        if (!_active && !loading && (product == null || !enabled)) ...[
          Text(
            L10n.current.storePurchaseUnavailable,
            style: TextStyle(color: color),
          ),
          if (enabled)
            TextButton(
              onPressed: busy ? null : PurchaseService.loadProduct,
              child: Text(
                t('Prijs opnieuw ophalen', 'Retry loading price'),
                style: TextStyle(color: color),
              ),
            ),
        ],
        if (widget.showManagement) ...[
          const SizedBox(height: 8),
          Text(
            t(
              'Plus kopen en herstellen kan zonder PasKluis-account. Herstel via hetzelfde Apple- of Google-account als bij je aankoop. Voor delen en cloudback-up heb je een gratis PasKluis-account nodig. Koppel je bestaande Plus-aankoop aan je account om te delen; opnieuw betalen is niet nodig. Een aankoop die al gekoppeld is, hoort bij dat PasKluis-account.',
              'Buy and restore Plus without a PasKluis account. Restore using the same Apple or Google account used for your purchase. Sharing and cloud backup require a free PasKluis account. Link your existing Plus purchase to your account to share; no further payment is needed. A purchase that is already linked belongs to that PasKluis account.',
            ),
            style: TextStyle(color: color, height: 1.35),
          ),
          TextButton.icon(
            onPressed: busy ? null : PurchaseService.restore,
            icon: Icon(Icons.restore, color: color),
            label: Text(
              L10n.current.restorePurchases,
              style: TextStyle(color: color),
            ),
          ),
          if (_active &&
              userId != null &&
              StoreAccessService.linkedUserId != userId)
            TextButton(
              onPressed: busy ? null : PurchaseService.linkToAccount,
              child: Text(
                t(
                  'Bestaande Plus-aankoop koppelen',
                  'Link existing Plus purchase',
                ),
                style: TextStyle(color: color),
              ),
            ),
        ],
        if (message != null && (!_active || widget.showManagement))
          Text(
            message,
            style: TextStyle(color: color),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
