const siteAsset=(name)=>`https://paskluis.com/assets/${name}`;

const group=(title,description,fields)=>({title,description,fields});
const field=(path,label,type='text',options={})=>({path,label,type,...options});

const siteHomeGroups=[
  group('Website en merk','De basisgegevens, het PasKluis-logo en de teksten in de bovenbalk.',[
    field('meta.title','Titel in het browsertabblad','text',{defaultValue:'PasKluis · Al je kaarten veilig bij elkaar'}),
    field('meta.description','Omschrijving voor zoekmachines','textarea',{defaultValue:'Bewaar klantenkaarten, cadeaukaarten en QR-codes veilig in PasKluis.'}),
    field('brand.name','Merknaam','text',{defaultValue:'PasKluis'}),
    field('brand.byline','Naam onderaan de website','text',{defaultValue:'Ronald & Jordi'}),
    field('images.brandIcon','PasKluis-logo','image',{defaultValue:siteAsset('icon.png?v=20261001-2')}),
    field('header.menuLabel','Tekst mobiele menuknop','text',{defaultValue:'Menu'}),
    field('header.navFeatures','Menu: Functies','text',{defaultValue:'Functies'}),
    field('header.navSecurity','Menu: Veiligheid','text',{defaultValue:'Veiligheid'}),
    field('header.navPlus','Menu: Plus','text',{defaultValue:'Plus'}),
    field('header.navSupport','Menu: Support','text',{defaultValue:'Support'}),
    field('header.ctaLabel','Knop rechtsboven','text',{defaultValue:'Binnenkort beschikbaar'}),
    field('header.ctaHref','Link knop rechtsboven','url',{defaultValue:'#download'}),
  ]),
  group('Hoofdblok','De grote introductie bovenaan en de afbeelding van het beginscherm.',[
    field('hero.eyebrow','Kleine tekst boven de titel','text',{defaultValue:'Je portemonnee, maar dan slimmer'}),
    field('hero.titleMain','Titel – eerste regel','text',{defaultValue:'Al je kaarten.'}),
    field('hero.titleAccent','Titel – gekleurde regel','text',{defaultValue:'Veilig bij elkaar.'}),
    field('hero.body','Introductietekst','textarea',{defaultValue:'Bewaar klantenkaarten, cadeaukaarten en QR-codes overzichtelijk op je telefoon. Snel gevonden, klaar om te scannen en altijd binnen handbereik.'}),
    field('hero.primaryCta','Tekst rode knop','text',{defaultValue:'Download PasKluis'}),
    field('hero.primaryHref','Link rode knop','url',{defaultValue:'#download'}),
    field('hero.secondaryCta','Tekst grijze knop','text',{defaultValue:'Bekijk de functies'}),
    field('hero.secondaryHref','Link grijze knop','url',{defaultValue:'#functies'}),
    field('hero.trust.0','Voordeel 1','text',{defaultValue:'Geen advertenties'}),
    field('hero.trust.1','Voordeel 2','text',{defaultValue:'Biometrische beveiliging'}),
    field('hero.trust.2','Voordeel 3','text',{defaultValue:'Nederlandse app'}),
    field('hero.plusTitle','Zwevend kaartje – titel','text',{defaultValue:'PLUS'}),
    field('hero.plusBody','Zwevend kaartje – tekst','text',{defaultValue:'Eenmalig € 1,99'}),
    field('hero.safeTitle','Veiligheidskaartje – titel','text',{defaultValue:'Veilig opgeslagen'}),
    field('hero.safeBody','Veiligheidskaartje – tekst','text',{defaultValue:'Jij houdt de controle'}),
    field('images.homeScreen','Afbeelding beginscherm app','image',{defaultValue:siteAsset('home.png')}),
  ]),
  group('Drie voordelenbalk','De donkere balk direct onder het hoofdblok.',[
    field('quickbar.0.title','Kolom 1 – titel','text',{defaultValue:'3 soorten'}),
    field('quickbar.0.body','Kolom 1 – tekst','text',{defaultValue:'Klantenkaarten, QR-codes en cadeaukaarten'}),
    field('quickbar.1.title','Kolom 2 – titel','text',{defaultValue:'1 veilige plek'}),
    field('quickbar.1.body','Kolom 2 – tekst','text',{defaultValue:'Overzichtelijk en direct te openen'}),
    field('quickbar.2.title','Kolom 3 – titel','text',{defaultValue:'€ 1,99'}),
    field('quickbar.2.body','Kolom 3 – tekst','text',{defaultValue:'Plus voor altijd, zonder abonnement'}),
  ]),
  group('Functies','De introductie en de vier gekleurde functiekaarten.',[
    field('featuresSection.kicker','Kleine kop','text',{defaultValue:'Alles wat je nodig hebt'}),
    field('featuresSection.title','Hoofdtitel','text',{defaultValue:'Nooit meer zoeken naar het juiste pasje'}),
    field('featuresSection.body','Introductietekst','textarea',{defaultValue:'PasKluis is ontworpen voor dagelijks gemak. De app herkent winkels, brengt je kaarten netjes samen en toont ze precies wanneer je ze nodig hebt.'}),
    field('features.0.icon','Kaart 1 – icoon/teken','text',{defaultValue:'▣'}),
    field('features.0.title','Kaart 1 – titel','text',{defaultValue:'Klantenkaarten'}),
    field('features.0.body','Kaart 1 – tekst','textarea',{defaultValue:'Scan of voer je kaart handmatig in. Favorieten en winkels in de buurt staan direct voor je klaar.'}),
    field('features.1.icon','Kaart 2 – icoon/teken','text',{defaultValue:'★'}),
    field('features.1.title','Kaart 2 – titel','text',{defaultValue:'Cadeaukaarten'}),
    field('features.1.body','Kaart 2 – tekst','textarea',{defaultValue:'Bewaar aankoopbedrag en restsaldo. PasKluis waarschuwt ook voor dubbele codes.'}),
    field('features.2.icon','Kaart 3 – icoon/teken','text',{defaultValue:'⌗'}),
    field('features.2.title','Kaart 3 – titel','text',{defaultValue:'QR-codes'}),
    field('features.2.body','Kaart 3 – tekst','textarea',{defaultValue:'Bewaar tickets, toegangscodes en andere QR-codes met een herkenbare naam.'}),
    field('features.3.icon','Kaart 4 – icoon/teken','text',{defaultValue:'↻'}),
    field('features.3.title','Kaart 4 – titel','text',{defaultValue:'Versleutelde back-up'}),
    field('features.3.body','Kaart 4 – tekst','textarea',{defaultValue:'Herstel je eigen kaarten op een nieuwe telefoon wanneer je back-up actief is.'}),
  ]),
  group('Appschermen','Teksten, tabknoppen, opsomming en alle drie schermafbeeldingen.',[
    field('showcase.kicker','Kleine kop','text',{defaultValue:'Vertrouwd ontwerp'}),
    field('showcase.title','Hoofdtitel','text',{defaultValue:'Rustig, duidelijk en razendsnel'}),
    field('showcase.body','Introductietekst','textarea',{defaultValue:'De herkenbare kaarttegels en grote knoppen zorgen dat je ook bij de kassa zonder gedoe de juiste kaart opent.'}),
    field('showcase.tabs.0.label','Tab 1','text',{defaultValue:'Klantenkaarten'}),
    field('showcase.tabs.1.label','Tab 2','text',{defaultValue:'Cadeaukaarten'}),
    field('showcase.tabs.2.label','Tab 3','text',{defaultValue:'QR-codes'}),
    field('showcase.bullets.0','Punt 1','text',{defaultValue:'Automatische winkelherkenning'}),
    field('showcase.bullets.1','Punt 2','text',{defaultValue:'Afstanden bij winkels in de buurt'}),
    field('showcase.bullets.2','Punt 3','text',{defaultValue:'Scherm blijft helder tijdens het scannen'}),
    field('images.loyaltyScreen','Afbeelding klantenkaarten','image',{defaultValue:siteAsset('loyalty.png')}),
    field('images.giftcardsScreen','Afbeelding cadeaukaarten','image',{defaultValue:siteAsset('giftcards.png')}),
    field('images.qrScreen','Afbeelding QR-codes','image',{defaultValue:siteAsset('qr.png')}),
  ]),
  group('Veiligheid','De donkere veiligheidssectie en de drie uitlegkaarten.',[
    field('security.kicker','Kleine kop','text',{defaultValue:'Veiligheid voorop'}),
    field('security.title','Hoofdtitel','text',{defaultValue:'Jouw kaarten blijven van jou'}),
    field('security.body','Introductietekst','textarea',{defaultValue:'PasKluis is gebouwd met zo min mogelijk toegang tot gevoelige gegevens. Ook onze klantenservice kan nooit je codes bekijken.'}),
    field('security.cards.0.number','Kaart 1 – nummer','text',{defaultValue:'01'}),
    field('security.cards.0.title','Kaart 1 – titel','text',{defaultValue:'Biometrisch vergrendeld'}),
    field('security.cards.0.body','Kaart 1 – tekst','textarea',{defaultValue:'Beveilig de app met Face ID, Touch ID of de beveiliging van je Android-toestel.'}),
    field('security.cards.1.number','Kaart 2 – nummer','text',{defaultValue:'02'}),
    field('security.cards.1.title','Kaart 2 – titel','text',{defaultValue:'Geen inzage door support'}),
    field('security.cards.1.body','Kaart 2 – tekst','textarea',{defaultValue:'Support ziet nooit kaartnummers, barcodes, QR-codes, pincodes, wachtwoorden of betaalgegevens.'}),
    field('security.cards.2.number','Kaart 3 – nummer','text',{defaultValue:'03'}),
    field('security.cards.2.title','Kaart 3 – titel','text',{defaultValue:'Veilige Supportmodus'}),
    field('security.cards.2.body','Kaart 3 – tekst','textarea',{defaultValue:'Geef met een tijdelijke code alleen-lezen toegang tot instellingen en technische status. Automatisch verlopen na 30 minuten.'}),
  ]),
  group('PasKluis Plus','De goudkleurige Plus-sectie, voordelen en prijs.',[
    field('plus.badge','Badge','text',{defaultValue:'PLUS'}),
    field('plus.title','Titel','textarea',{defaultValue:'Meer ruimte. Meer gemak. Geen abonnement.'}),
    field('plus.body','Uitleg','textarea',{defaultValue:'Activeer PasKluis Plus één keer en gebruik de extra functies blijvend.'}),
    field('plus.bullets.0','Voordeel 1','text',{defaultValue:'Onbeperkt cadeaukaarten bewaren'}),
    field('plus.bullets.1','Voordeel 2','text',{defaultValue:'Klanten- en cadeaukaarten veilig delen'}),
    field('plus.bullets.2','Voordeel 3','text',{defaultValue:'Blijvende toegang tot alle Plus-functies'}),
    field('plus.priceLabel','Prijs – bovenregel','text',{defaultValue:'Eenmalig'}),
    field('plus.price','Prijs','text',{defaultValue:'€ 1,99'}),
    field('plus.priceCaption','Prijs – onderregel','text',{defaultValue:'Geen abonnement'}),
  ]),
  group('Support','De supportuitleg en de voorbeeldcode.',[
    field('support.kicker','Kleine kop','text',{defaultValue:'Hulp zonder je kluis te openen'}),
    field('support.title','Hoofdtitel','text',{defaultValue:'Persoonlijke support, met privacy als grens'}),
    field('support.body','Uitleg','textarea',{defaultValue:'Start een gesprek vanuit de app. Alleen wanneer jij de Supportmodus inschakelt, kunnen we tijdelijk instellingen en technische foutmeldingen bekijken.'}),
    field('support.codeLabel','Code – titel','text',{defaultValue:'Tijdelijke supportcode'}),
    field('support.codeExample','Voorbeeldcode','text',{defaultValue:'8 4 1 2 9 6'}),
    field('support.codeCaption','Code – uitleg','text',{defaultValue:'Voorbeeld · één keer te gebruiken'}),
  ]),
  group('Download en storeknoppen','Het rode downloadblok, beide storelogo’s en de bestemmingslinks.',[
    field('download.kicker','Kleine kop','text',{defaultValue:'Binnenkort beschikbaar'}),
    field('download.title','Hoofdtitel','text',{defaultValue:'Maak je portemonnee een stuk lichter'}),
    field('download.body','Uitleg','textarea',{defaultValue:'PasKluis komt naar de App Store en Google Play.'}),
    field('download.appStoreLabel','Alt-tekst App Store','text',{defaultValue:'Download in de App Store'}),
    field('download.appStoreUrl','Link App Store','url',{defaultValue:'#download'}),
    field('images.appStoreBadge','Logo/knop App Store','image',{defaultValue:siteAsset('app-store-badge.svg')}),
    field('download.googlePlayLabel','Alt-tekst Google Play','text',{defaultValue:'Download via Google Play'}),
    field('download.googlePlayUrl','Link Google Play','url',{defaultValue:'#download'}),
    field('images.googlePlayBadge','Logo/knop Google Play','image',{defaultValue:siteAsset('google-play-badge.svg')}),
  ]),
  group('Voettekst','De slogan, linkteksten, bestemmingen en copyrightregel.',[
    field('footer.tagline','Slogan','text',{defaultValue:'Jouw kaarten. Jouw controle.'}),
    field('footer.supportLabel','Linktekst Support','text',{defaultValue:'Support'}),
    field('footer.supportUrl','Link Support','url',{defaultValue:'support.html'}),
    field('footer.privacyLabel','Linktekst Privacy','text',{defaultValue:'Privacy'}),
    field('footer.privacyUrl','Link Privacy','url',{defaultValue:'privacy.html'}),
    field('footer.termsLabel','Linktekst Voorwaarden','text',{defaultValue:'Voorwaarden'}),
    field('footer.termsUrl','Link Voorwaarden','url',{defaultValue:'terms.html'}),
    field('footer.deleteLabel','Linktekst Account verwijderen','text',{defaultValue:'Account verwijderen'}),
    field('footer.deleteUrl','Link Account verwijderen','url',{defaultValue:'delete-account.html'}),
    field('footer.copyright','Copyrighttekst','text',{defaultValue:'© 2026 PasKluis · Ronald & Jordi'}),
  ]),
];

const appCopyGroups=[
  group('Veilige Supportmodus','Deze tekst verschijnt in de Nederlandse en Engelse app.',[
    field('supportMode.title.nl','Titel Nederlands','text',{defaultValue:'Veilige Supportmodus'}),
    field('supportMode.description.nl','Uitleg Nederlands','textarea',{defaultValue:'Geef klantenservice tijdelijk en alleen-lezen inzage in technische instellingen. Kaartcodes, barcodes, QR-codes, pincodes, afbeeldingen, wachtwoorden, betaalgegevens en je exacte locatie zijn nooit zichtbaar.'}),
    field('supportMode.title.en','Titel Engels','text',{defaultValue:'Secure Support Mode'}),
    field('supportMode.description.en','Uitleg Engels','textarea',{defaultValue:'Temporarily share read-only technical settings with support. Card codes, barcodes, QR codes, PINs, images, passwords, payment details and your exact location are never visible.'}),
  ]),
];

export const contentSchemas={
  'site.home':{title:'Volledige website',description:'Alle zichtbare woorden, afbeeldingen, knoppen en links van de homepage.',groups:siteHomeGroups},
  'app.copy':{title:'Appteksten',description:'Beheer appteksten per taal zonder JSON te hoeven aanpassen.',groups:appCopyGroups},
};

export function valueAt(object,path){return path.split('.').reduce((value,key)=>value?.[key],object)}

export function setAt(object,path,value){
  const keys=path.split('.');let cursor=object;
  keys.forEach((key,index)=>{
    if(index===keys.length-1){cursor[key]=value;return;}
    const next=keys[index+1];
    if(cursor[key]===undefined||cursor[key]===null||typeof cursor[key]!=='object')cursor[key]=/^\d+$/.test(next)?[]:{};
    cursor=cursor[key];
  });
  return object;
}

function escapeHtml(value=''){return String(value).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]))}
function inputId(path){return `content-${path.replace(/[^a-z0-9]+/gi,'-')}`}

export function renderContentEditor(root,key,content={}){
  const schema=contentSchemas[key];
  if(!schema){root.innerHTML='<p class="empty-text">Voor dit onderdeel is nog geen eenvoudig formulier beschikbaar.</p>';return false;}
  root.innerHTML=`<div class="content-editor-intro"><h2>${escapeHtml(schema.title)}</h2><p>${escapeHtml(schema.description)}</p></div>`+schema.groups.map(section=>`<section class="content-field-group"><div class="content-field-heading"><h3>${escapeHtml(section.title)}</h3><p>${escapeHtml(section.description||'')}</p></div><div class="content-field-grid">${section.fields.map(item=>renderField(item,valueAt(content,item.path)??item.defaultValue??'')).join('')}</div></section>`).join('');
  return true;
}

function renderField(item,value){
  const id=inputId(item.path);const common=`id="${id}" data-content-field="${escapeHtml(item.path)}" data-content-type="${escapeHtml(item.type)}"`;
  if(item.type==='textarea')return `<label class="content-field wide"><span>${escapeHtml(item.label)}</span><textarea ${common} rows="4">${escapeHtml(value)}</textarea>${item.help?`<small>${escapeHtml(item.help)}</small>`:''}</label>`;
  if(item.type==='image')return `<div class="content-field image-field wide"><label for="${id}"><span>${escapeHtml(item.label)}</span></label><div class="image-field-editor"><div class="content-image-preview" data-content-preview-for="${escapeHtml(item.path)}">${value?`<img src="${escapeHtml(value)}" alt="Voorbeeld ${escapeHtml(item.label)}">`:'<span>Nog geen afbeelding</span>'}</div><div><input ${common} type="url" value="${escapeHtml(value)}" placeholder="https://…"><label class="content-upload-button">Nieuwe afbeelding kiezen<input type="file" data-content-upload="${escapeHtml(item.path)}" accept="image/png,image/jpeg,image/webp"></label><small>PNG, JPG of WebP · maximaal 2 MB</small></div></div></div>`;
  return `<label class="content-field ${item.type==='url'?'wide':''}"><span>${escapeHtml(item.label)}</span><input ${common} type="${item.type==='url'?'text':'text'}" value="${escapeHtml(value)}" ${item.type==='url'?'inputmode="url"':''}>${item.help?`<small>${escapeHtml(item.help)}</small>`:''}</label>`;
}

export function collectContentEditor(root,original={}){
  const content=JSON.parse(JSON.stringify(original||{}));
  root.querySelectorAll('[data-content-field]').forEach(input=>setAt(content,input.dataset.contentField,input.value));
  return content;
}

export function updateImagePreview(root,path,value){
  const preview=[...root.querySelectorAll('[data-content-preview-for]')].find(node=>node.dataset.contentPreviewFor===path);
  if(preview)preview.innerHTML=value?`<img src="${escapeHtml(value)}" alt="Afbeeldingsvoorbeeld">`:'<span>Nog geen afbeelding</span>';
}

export function schemaPaths(key){return (contentSchemas[key]?.groups||[]).flatMap(section=>section.fields.map(item=>item.path));}
