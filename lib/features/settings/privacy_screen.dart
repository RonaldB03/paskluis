import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text('Privacy en gegevens'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF27313D),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        children: const [
          _PrivacyHero(),
          SizedBox(height: 18),
          _PrivacySection(
            icon: Icons.phone_iphone_rounded,
            title: 'Blijft op jouw telefoon',
            color: Color(0xFF23814A),
            points: [
              'Klantenkaarten, QR-codes en cadeaukaarten',
              'Barcodes, kaartnummers, pincodes en krascodes',
              'Saldo’s, notities en geïmporteerde afbeeldingen',
              'Opgeslagen gebruikslocaties voor kaarten in de buurt',
            ],
          ),
          _PrivacySection(
            icon: Icons.cloud_outlined,
            title: 'Alleen online wanneer jij dat gebruikt',
            color: Color(0xFF286DC8),
            points: [
              'Je accountnaam, e-mailadres en Plus-status na inloggen',
              'Een kaart die je bewust met iemand deelt, inclusief de gegevens die op die kaart staan',
              'Vragen en berichten die je zelf naar de klantenservice stuurt',
              'Openbare winkelinformatie en logo’s die de app ophaalt',
            ],
          ),
          _PrivacySection(
            icon: Icons.visibility_off_outlined,
            title: 'Niet zichtbaar in het beheer',
            color: Color(0xFFD51B46),
            points: [
              'Jouw gewone lokale kaarten en codes',
              'Pincodes of krascodes van niet-gedeelde cadeaukaarten',
              'Je precieze locatie of locatiegeschiedenis',
              'Welke kaart je waar en wanneer opent',
            ],
          ),
          _PrivacySection(
            icon: Icons.share_outlined,
            title: 'Bij het delen van een kaart',
            color: Color(0xFFA26D00),
            points: [
              'Je kiest zelf welke kaart en met welk e-mailadres je deelt.',
              'Een cadeaukaart wordt altijd volledig gedeeld, dus ook met pincode of krascode.',
              'Je kunt gedeelde toegang later weer stoppen.',
              'Zonder Plus kan de ontvanger alleen kijken; met Plus kunnen beide gebruikers bewerken.',
            ],
          ),
          _PrivacySection(
            icon: Icons.security_rounded,
            title: 'Beveiliging en jouw keuzes',
            color: Color(0xFF7046B8),
            points: [
              'Je kunt PasKluis vergrendelen met Face ID, biometrie of je toestelcode.',
              'Gevoelige codes kunnen standaard verborgen blijven.',
              'Locatiegestuurde kaarten kun je volledig uitschakelen.',
              'Uitloggen verwijdert je lokale kaarten niet van het apparaat.',
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text(
              'PasKluis verkoopt geen persoonsgegevens en gebruikt je kaartgegevens niet voor advertenties. PasKluis is voor iedereen reclamevrij.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5D6875), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF174B7A), Color(0xFF2879B9)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_rounded, color: Colors.white, size: 40),
          SizedBox(height: 13),
          Text('Jouw PasKluis is van jou',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900)),
          SizedBox(height: 7),
          Text(
            'De belangrijkste gegevens blijven lokaal op je telefoon. Hieronder zie je precies wat wel en niet online wordt verwerkt.',
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
