# PasKluis 1.8.0 — uitsluitend testdistributie

## Wijzigingen
- Plus kopen en herstellen zonder verplicht PasKluis-account.
- Directe koopknop op het gouden Plus-scherm, met de prijs uit de winkel.
- Herladen bij ontbrekende winkelprijs; geen vaste prijs als schijnbaar koopaanbod.
- Aankoop optioneel koppelen aan één geauthenticeerd PasKluis-account.
- Lokale Plus-toegang uit servergecontroleerde winkelbewijzen in secure storage, maximaal zeven dagen offline.
- Extra cadeaukaarten ook vrijgeven zonder ingelogd account; delen en back-up blijven accountgebonden.
- Beheer toont gecontroleerde winkeltransacties inclusief aankopen zonder account.

## Server
De nieuwe `verify-store-purchase`-route is aanvullend op de 1.7.0-route. Apple-bewijzen worden met Apples officiële Node-bibliotheek 3.1.0 cryptografisch gecontroleerd in een interne service en daarna opnieuw bij de Apple API opgehaald voor actuele terugbetalingsstatus. Google-bewijzen worden rechtstreeks bij Google gecontroleerd. Ruwe aankoopbewijzen worden niet opgeslagen in de serverledger of getoond in beheer.

Migratie `20261005155639_accountless_store_purchases.sql` voegt alleen velden en een uitsluitend door service_role uitvoerbare functie toe. Repetities, koppelen, ongeoorloofde overdracht, verwijderde accounts en terugbetalingen zijn in een rollback-only test gecontroleerd. Bestaande productieaankoop is succesvol met de nieuwe Apple-route geverifieerd, met behoud van de bestaande accountkoppeling.

## Testen op echte apparaten
1. TestFlight / gesloten Play-test installeren; geen PasKluis-account gebruiken.
2. Plus-scherm openen; prijs komt uit de winkel; tik opent de winkelbevestiging.
3. Annuleren mag geen Plus geven. Een geslaagde testbetaling geeft Plus en laat meerdere cadeaukaarten toe.
4. App herstarten; Plus blijft actief. Zonder netwerk blijven eerder geverifieerde rechten maximaal zeven dagen bruikbaar.
5. Met hetzelfde winkelaccount herstellen na herinstallatie (lokale kaarten eerst veiligstellen).
6. Later inloggen en de winkelaankoop koppelen; delen controleren. Een ander PasKluis-account mag dezelfde aankoop niet opnieuw claimen.
7. Ander winkelaccount zonder aankoop: geen Plus na een schone installatie/herstel.
8. Android testbetaling uitsluitend met een ingestelde licentietester; de gesloten testtrack op zichzelf voorkomt geen echte betaling.

## Distributie
Alleen `ios-testflight` en `android-test` starten. Buildnummers worden door Codemagic vastgesteld aan de hand van de hoogste bestaande nummers. Geen App Store-review en geen productie-uitrol aangevraagd. Apple kan voor externe TestFlight-testers afzonderlijke beta-review verlangen.
