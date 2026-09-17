import 'package:flutter/material.dart';

import '../../data/services/account_service.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final _searchController = TextEditingController();
  List<ManagedAccount> _accounts = const [];
  String _query = '';
  bool _loading = true;
  String? _error;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await AccountService.loadManagedAccounts();
      if (mounted) setState(() => _accounts = accounts);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'De accounts konden niet worden opgehaald.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setPlus(ManagedAccount account, bool active) async {
    setState(() => _saving.add(account.id));
    try {
      await AccountService.setComplimentaryPlus(
        userId: account.id,
        active: active,
      );
      if (!mounted) return;
      setState(() {
        final index = _accounts.indexWhere((item) => item.id == account.id);
        if (index >= 0) {
          _accounts[index] = ManagedAccount(
            id: account.id,
            name: account.name,
            email: account.email,
            role: account.role,
            plusActive: active,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'PasKluis Plus is geactiveerd.'
                : 'PasKluis Plus is ingetrokken.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wijzigen is niet gelukt.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(account.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _query.trim().toLowerCase();
    final accounts = normalized.isEmpty
        ? _accounts
        : _accounts.where((account) {
            return account.name.toLowerCase().contains(normalized) ||
                account.email.toLowerCase().contains(normalized);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text('Accounts beheren'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        actions: [
          IconButton(
            tooltip: 'Vernieuwen',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Opnieuw proberen'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFD51B46),
                    ),
                    title: Text(
                      'Gebruikers registreren zichzelf eerst',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Daarna verschijnt hun account hier en kun je Plus aan- of uitzetten.',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Zoek op naam of e-mailadres',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${accounts.length} ${accounts.length == 1 ? 'account' : 'accounts'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ...accounts.map((account) {
                  final busy = _saving.contains(account.id);
                  return Card(
                    elevation: 0,
                    child: SwitchListTile.adaptive(
                      value: account.plusActive,
                      onChanged: busy
                          ? null
                          : (active) => _setPlus(account, active),
                      secondary: CircleAvatar(
                        backgroundColor: const Color(0xFFF8E3EA),
                        child: busy
                            ? const Padding(
                                padding: EdgeInsets.all(11),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                color: Color(0xFFD51B46),
                              ),
                      ),
                      title: Text(
                        account.name.isEmpty ? account.email : account.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        account.name.isEmpty
                            ? account.role
                            : '${account.email}\n${account.role}',
                      ),
                      isThreeLine: account.name.isNotEmpty,
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
