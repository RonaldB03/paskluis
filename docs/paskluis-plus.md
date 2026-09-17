# PasKluis Plus

PasKluis blijft zonder account bruikbaar. Online functies zijn optioneel en worden
alleen geactiveerd nadat de gebruiker bewust inlogt.

## Rollen

- `user`: gebruikt PasKluis en kan eigen supportgesprekken bekijken.
- `support`: kan supportgesprekken beantwoorden.
- `admin`: beheert winkels, logo's, ondersteuning en gratis Plus-toegang.

## Plus-toegang

Product-ID: `paskluis_plus`.

Een recht kan afkomstig zijn van Apple, Google of een gratis toekenning door een
beheerder. Gratis toegang kan een einddatum hebben of levenslang zijn. Een
ingetrokken recht blijft bewaard voor controle, maar geeft geen toegang meer.

## Privacygrens

De backend bewaart nooit kaartnummers, barcodes, pincodes, saldo's of lokale
kaartafbeeldingen, tenzij later uitdrukkelijk een versleutelde back-upfunctie
wordt ingeschakeld. De eerste online fase bevat uitsluitend:

- accountprofiel en rol;
- Plus-toegangsstatus;
- openbare winkel- en logocatalogus;
- supportgesprekken die de gebruiker zelf verstuurt.

## Geplande bouwvolgorde

1. Supabase-project en database-migratie.
2. Optioneel inloggen met Apple en e-mail.
3. Plus-status en gratis beheerderstoegang.
4. Winkel- en logocatalogus met lokale cache.
5. Supportinbox en berichten in de app.
6. App Store- en Play Store-abonnementen.
7. Cadeaukaartscanner met barcode en OCR voor krascodes.
8. Optionele end-to-end versleutelde back-up en synchronisatie.

## Configuratie

Supabase-URL en publiceerbare sleutel worden via buildvariabelen geleverd en
nooit als beheerderssleutel in de app opgenomen. De service-role-sleutel blijft
uitsluitend op een beveiligde server of in Supabase Edge Functions.
