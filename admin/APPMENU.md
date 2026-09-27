# Appmenu

Open **Appmenu** in PasKluis Beheer. Wijzigingen blijven een concept totdat je
**Concept opslaan** en daarna **Publiceren** kiest. Bekijk de indeling eerst als
Gratis en Plus, in Nederlands en Engels. Een categorie kan standaard open of
ingeklapt zijn. Meerdere categorieën kunnen in de app tegelijk openstaan.

Sleep categorieën en items via de greep, of gebruik de pijlen. Verplaats een item
naar een andere categorie via de categorie-keuze. Lege itemtitels en omschrijvingen
gebruiken de ingebouwde vertaling. Externe links hebben een titel in beide talen
en een volledig HTTPS-adres nodig. De deeltekst en deellink staan apart bovenaan.

Accountbeheer blijft vast bovenaan. De interne privacypagina moet zichtbaar blijven
voor iedereen. Een menu-item verbergen of op Plus zetten verandert geen account-
of aankooprechten. De bestaande limieten voor cadeaukaarten en gedeelde toegang
blijven gelden. De standaard back-upfuncties zijn beschikbaar voor Gratis en Plus.

Een vorige publicatie kan via **Versie terugzetten** opnieuw gepubliceerd worden.
Dit vervangt ook het concept. Bij gelijktijdige wijzigingen door twee beheerders
weigert de server de verouderde versie; herlaad dan het concept.

De app haalt de publicatie op bij openen/hervatten en bij openen van Instellingen.
Een ongeldige of onbereikbare configuratie vervangt nooit de laatste geldige lokale
kopie. Zonder cache gebruikt de app `assets/config/app_menu.json`. Nieuwe functies
vereisen nog steeds een app-update; teksten, volgorde, links en zichtbaarheid niet.

## Technisch

- Schema 1: `app_menu_publication`, `app_menu_draft`, `app_menu_history`.
- Alleen publicaties zijn leesbaar zonder beheerdersrol. Schrijven loopt via
  `save_app_menu` / `publish_app_menu`, met rolcontrole, validatie en versiecontrole.
- Publicaties worden in `admin_audit_log` geregistreerd.
- Geen sleutels, persoonsgegevens of willekeurige uitvoerbare code in de configuratie.
- Dezelfde standaard-JSON staat in app en beheer; een test controleert gelijkheid.
- `show_card_distances` staat standaard aan. Locatie moet toegestaan/ingeschakeld
  zijn en de winkel moet binnen de gekozen straal vallen. Sorteren op afstand blijft
  een afzonderlijke, bestaande voorkeur.
