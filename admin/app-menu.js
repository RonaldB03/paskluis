import {icons, actions, validateMenu, visibleItems, moveItem} from './app-menu-model.js?v=menu-1';

export function createMenuEditor({client, root, toast, confirmAction}) {
  let config, catalog, revision, publication, history = [], dirty = false, busy = false, loaded = false, drag;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const localized = (nl = '', en = '') => ({nl,en});
  const label = i => i.title.nl || catalog[i.action]?.title.nl || i.action;
  const id = () => crypto.randomUUID();
  const opts = (values, value) => values.map(([v,l]) => `<option value="${esc(v)}" ${v === value ? 'selected' : ''}>${esc(l)}</option>`).join('');
  const iconOpts = value => opts(icons.map(v => [v,v || 'Standaard']), value);
  const audienceOpts = value => opts([['all','Iedereen'],['free','Alleen Gratis'],['plus','Alleen Plus'],['locked','Plus · met slotje voor Gratis']], value);
  const input = (name, value, max = 120) => `<input data-field="${name}" value="${esc(value)}" maxlength="${max}">`;
  function mark() { dirty = true; status(); preview(); }
  function status() {
    root.querySelector('#menu-status').textContent = `Gepubliceerd: versie ${publication?.revision ?? '–'} · ${dirty ? 'Niet-opgeslagen wijzigingen' : `Concept ${revision ?? '–'} opgeslagen`}`;
    root.querySelectorAll('[data-command]').forEach(b => b.disabled = busy || !loaded);
    root.querySelector('[data-command="publish"]').disabled = busy || !loaded || dirty;
    root.querySelector('[data-command="revert"]').disabled = busy || !loaded || !history.some(h => h.revision !== publication?.revision);
  }
  function error(e) {
    toast(String(e?.message || e).includes('MENU_CONFLICT') ? 'Een andere beheerder heeft het menu gewijzigd. Herlaad het concept voordat je verdergaat.' : e?.message || 'Appmenu kon niet worden bijgewerkt.');
  }
  async function load(force = false) {
    if (busy || (loaded && !force)) return;
    if (dirty && !await confirmAction('Concept herladen?', 'Je niet-opgeslagen wijzigingen gaan verloren. Het opgeslagen concept blijft bewaard.')) return;
    busy = true;
    try {
      if (!catalog) { const r = await fetch('./app-menu-catalog.json'); if (!r.ok) throw Error('Functielijst kon niet laden.'); catalog = await r.json(); }
      const results = await Promise.all([
        client.from('app_menu_draft').select('*').eq('id',1).single(),
        client.from('app_menu_publication').select('revision,published_at').eq('id',1).single(),
        client.from('app_menu_history').select('revision,published_at').order('revision',{ascending:false}).limit(30),
      ]);
      for (const r of results) if (r.error) throw r.error;
      config = results[0].data.config; revision = results[0].data.revision; publication = results[1].data; history = results[2].data;
      const errors = validateMenu(config); if (errors.length) throw Error(errors.join(' '));
      dirty = false; loaded = true; render();
    } catch(e) { error(e); }
    finally { busy = false; if (loaded) status(); }
  }
  function render() {
    const previewPlan = root.querySelector('#menu-preview-plan')?.value || 'free';
    const previewLanguage = root.querySelector('#menu-preview-language')?.value || 'nl';
    root.innerHTML = `<div class="page-heading"><div><h1>Appmenu</h1><p>Deel je instellingen in, vul teksten en links in en bekijk het resultaat voor Gratis en Plus.</p></div></div>
      <div class="permission-note"><strong>Account blijft bovenaan</strong><span>Accountbeheer en verwijderen blijven altijd bereikbaar. Privacy blijft beschikbaar voor iedereen. Deze indeling verandert geen Plus-rechten of persoonlijke instellingen.</span></div>
      <div class="menu-toolbar"><button class="secondary" data-command="reload">Concept herladen</button><button class="secondary" data-command="save">Concept opslaan</button><button class="primary" data-command="publish">Publiceren</button><select id="menu-history" aria-label="Vorige menuversie">${history.filter(h=>h.revision!==publication.revision).map(h=>`<option value="${h.revision}">Versie ${h.revision} · ${esc(new Date(h.published_at).toLocaleString('nl-NL'))}</option>`).join('')}</select><button class="secondary" data-command="revert">Versie terugzetten</button></div>
      <p id="menu-status" role="status"></p>
      <div class="menu-workspace"><div><article class="panel menu-share"><h2>Deel PasKluis</h2><label>Deellink (HTTPS)<input id="menu-share-url" type="url" maxlength="2048" value="${esc(config.share.url)}"></label><div class="menu-fields"><label>Deeltekst Nederlands<textarea id="menu-share-nl" maxlength="2000">${esc(config.share.text.nl)}</textarea></label><label>Share text English<textarea id="menu-share-en" maxlength="2000">${esc(config.share.text.en)}</textarea></label></div></article>
      <p>Sleep via ⠿ om te ordenen. Met ↑ en ↓ kan het ook. Verplaats een item via het categoriemenu. Lege itemteksten gebruiken de standaard apptekst.</p>
      <div id="menu-sections">${config.sections.map(sectionMarkup).join('')}</div><button class="secondary" data-command="add-section">Categorie toevoegen</button></div>
      <aside class="panel menu-preview-panel"><h2>Voorbeeld</h2><label>Versie<select id="menu-preview-plan"><option value="free">Gratis</option><option value="plus">Plus</option></select></label><label>Taal<select id="menu-preview-language"><option value="nl">Nederlands</option><option value="en">English</option></select></label><p>Voorbeeld van indeling en teksten. Persoonlijke waarden verschillen per gebruiker.</p><div id="menu-preview"></div></aside></div>`;
    root.querySelector('#menu-preview-plan').value=previewPlan;
    root.querySelector('#menu-preview-language').value=previewLanguage;
    status(); preview();
  }
  function sectionMarkup(s, index) {
    return `<article class="panel menu-section" data-section="${esc(s.id)}"><div class="menu-section-heading"><button type="button" draggable="true" data-drag-section="${esc(s.id)}" aria-label="Categorie slepen">⠿</button><strong>${esc(s.title.nl)}</strong><button type="button" data-move-section="-1" ${index===0?'disabled':''} aria-label="Categorie omhoog">↑</button><button type="button" data-move-section="1" ${index===config.sections.length-1?'disabled':''} aria-label="Categorie omlaag">↓</button></div>
      <details><summary>Categorie bewerken</summary><div class="menu-fields"><label>Titel Nederlands${input('title.nl',s.title.nl)}</label><label>Title English${input('title.en',s.title.en)}</label><label>Beschrijving Nederlands${input('description.nl',s.description.nl,500)}</label><label>Description English${input('description.en',s.description.en,500)}</label><label>Icoon<select data-field="icon">${iconOpts(s.icon)}</select></label><label><input type="checkbox" data-field="collapsed" ${s.collapsed?'checked':''}> Standaard ingeklapt</label><label><input type="checkbox" data-field="hidden" ${s.hidden?'checked':''}> Categorie verbergen</label></div><button type="button" data-remove-section class="text-button">Lege categorie verwijderen</button></details>
      <div class="menu-items">${s.items.map((i,n)=>itemMarkup(s,i,n)).join('')}</div><button type="button" class="secondary small-button" data-add-item>Menu-item toevoegen</button></article>`;
  }
  function itemMarkup(s,i,index) {
    return `<details class="menu-item" data-item="${esc(i.id)}"><summary><span draggable="true" data-drag-item="${esc(i.id)}" role="button" aria-label="Menu-item slepen">⠿</span> ${esc(label(i))} ${i.hidden?'· verborgen':''} ${i.audience!=='all'?`· ${esc(i.audience)}`:''}</summary><div class="menu-fields">
      <label>Functie<select data-field="action">${opts(actions.map(a=>[a,catalog[a].title.nl]),i.action)}</select></label><label>Voor wie<select data-field="audience">${audienceOpts(i.audience)}</select></label>
      <label>Titel Nederlands${input('title.nl',i.title.nl)}</label><label>Title English${input('title.en',i.title.en)}</label><label>Beschrijving Nederlands${input('description.nl',i.description.nl,500)}</label><label>Description English${input('description.en',i.description.en,500)}</label><label>Icoon<select data-field="icon">${iconOpts(i.icon)}</select></label><label>Categorie<select data-move-item>${opts(config.sections.map(c=>[c.id,c.title.nl]),s.id)}</select></label><label>Weblink (alleen bij Website)${input('url',i.url || '',2048)}</label><label><input type="checkbox" data-field="hidden" ${i.hidden?'checked':''}> Verbergen</label></div>
      <div class="menu-toolbar"><button type="button" data-move-item-offset="-1" ${index===0?'disabled':''}>↑ Omhoog</button><button type="button" data-move-item-offset="1" ${index===s.items.length-1?'disabled':''}>↓ Omlaag</button><button type="button" data-remove-item class="text-button">Item verwijderen</button></div></details>`;
  }
  function preview() {
    const box = root.querySelector('#menu-preview'); if (!box || !config) return;
    const plus = root.querySelector('#menu-preview-plan').value === 'plus'; const lang = root.querySelector('#menu-preview-language').value;
    box.innerHTML = `<div class="menu-preview-account"><strong>${lang==='nl'?'Mijn account':'My account'}</strong><small>${plus?'PasKluis Plus':lang==='nl'?'Gratis':'Free'} · ${lang==='nl'?'laatste back-up':'last backup'}</small></div>` + config.sections.map(s => {
      const items = visibleItems(s,plus); if (!items.length) return '';
      return `<details ${s.collapsed?'':'open'}><summary>${esc(s.title[lang])}</summary>${s.description[lang]?`<small>${esc(s.description[lang])}</small>`:''}${items.map(i=>`<div class="menu-preview-item"><strong>${i.audience==='locked'&&!plus?'🔒 ':''}${esc(i.title[lang]||catalog[i.action]?.title[lang]||i.action)}</strong>${i.description[lang]?`<small>${esc(i.description[lang])}</small>`:''}${i.action==='external'?`<small>${esc(i.url)}</small>`:''}</div>`).join('')}</details>`;
    }).join('') + '<small>PasKluis · versie (build)</small>';
  }
  async function save() {
    const errors=validateMenu(config); if(errors.length) { toast(errors.join(' ')); return false; }
    const {data,error:e}=await client.rpc('save_app_menu',{p_config:config,p_expected_revision:revision}); if(e) throw e;
    revision=data; dirty=false; toast('Concept opgeslagen. De app gebruikt nog de gepubliceerde versie.'); return true;
  }
  root.addEventListener('input', e => {
    if (!loaded || busy) return;
    if (e.target.id==='menu-share-url') config.share.url=e.target.value;
    else if(e.target.id==='menu-share-nl') config.share.text.nl=e.target.value;
    else if(e.target.id==='menu-share-en') config.share.text.en=e.target.value;
    else if(e.target.dataset.field) {
      const section=config.sections.find(s=>s.id===e.target.closest('[data-section]')?.dataset.section);
      const itemId=e.target.closest('[data-item]')?.dataset.item; const target=itemId?section.items.find(i=>i.id===itemId):section;
      const [key,lang]=e.target.dataset.field.split('.'); const value=e.target.type==='checkbox'?e.target.checked:e.target.value;
      if(lang)target[key][lang]=value;else target[key]=value;
    } else return;
    mark();
  });
  root.addEventListener('change', e => {
    if (e.target.id.startsWith('menu-preview-')) return preview();
    if (e.target.hasAttribute('data-move-item') && !busy) {
      moveItem(config,e.target.closest('[data-section]').dataset.section,e.target.closest('[data-item]').dataset.item,e.target.value); dirty=true; render();
    }
  });
  root.addEventListener('click', async e => {
    const button=e.target.closest('button'); if(!button || busy || !loaded) return;
    const command=button.dataset.command, section=config.sections.find(s=>s.id===button.closest('[data-section]')?.dataset.section), itemId=button.closest('[data-item]')?.dataset.item;
    if(command==='reload') return load(true);
    if(['save','publish','revert'].includes(command)) {
      if(command==='publish' && dirty) return toast('Sla het concept eerst op en controleer het voorbeeld.');
      if(command==='publish' && !await confirmAction('Appmenu publiceren?', 'De opgeslagen indeling wordt actief wanneer gebruikers de app of instellingen opnieuw openen.')) return;
      if(command==='revert' && !await confirmAction('Vorige versie terugzetten?', 'Deze versie wordt opnieuw gepubliceerd en vervangt ook je huidige concept.')) return;
      busy=true; status();
      try {
        if(command==='save') await save();
        else {
          const {error:e}=await client.rpc('publish_app_menu',{p_expected_revision:revision,p_restore_revision:command==='revert'?Number(root.querySelector('#menu-history').value):null}); if(e) throw e;
          dirty=false; loaded=false; toast(command==='revert'?'Vorige versie teruggezet.':'Appmenu gepubliceerd.');
        }
      } catch(e){error(e);} finally{busy=false; if(!loaded)await load();else status();} return;
    }
    if(command==='add-section') config.sections.push({id:id(),title:localized('Nieuwe categorie','New category'),description:localized(),icon:'cards',collapsed:true,hidden:false,items:[]});
    else if(button.hasAttribute('data-add-item')) {
      const used=new Set(config.sections.flatMap(s=>s.items.map(i=>i.action))); const action=actions.find(a=>!used.has(a))||'external';
      section.items.push({id:id(),action,title:localized(),description:localized(),icon:'',audience:'all',hidden:false,url:''});
    } else if(button.hasAttribute('data-remove-item')) {
      if(section.items.find(i=>i.id===itemId)?.action==='privacy') return toast('Privacy blijft bereikbaar. Je kunt dit item wel verplaatsen.');
      section.items=section.items.filter(i=>i.id!==itemId);
    } else if(button.hasAttribute('data-remove-section')) {
      if(section.items.length) return toast('Verplaats of verwijder eerst de items in deze categorie.');
      config.sections=config.sections.filter(s=>s!==section);
    } else if(button.dataset.moveSection) {
      const a=config.sections.indexOf(section),b=a+Number(button.dataset.moveSection); if(b<0||b>=config.sections.length)return;
      [config.sections[a],config.sections[b]]=[config.sections[b],config.sections[a]];
    } else if(button.dataset.moveItemOffset) {
      const a=section.items.findIndex(i=>i.id===itemId),b=a+Number(button.dataset.moveItemOffset); if(b<0||b>=section.items.length)return;
      [section.items[a],section.items[b]]=[section.items[b],section.items[a]];
    } else return;
    dirty=true;render();
  });
  root.addEventListener('dragstart',e=>{
    if(busy)return e.preventDefault();
    const item=e.target.closest('[data-drag-item]'), section=e.target.closest('[data-drag-section]');
    if(!item&&!section)return;
    drag={section:e.target.closest('[data-section]').dataset.section,item:item?.dataset.dragItem};
    e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain','PasKluis menu');
  });
  root.addEventListener('dragover',e=>{if(drag&&e.target.closest('[data-section]'))e.preventDefault();});
  root.addEventListener('drop',e=>{
    const target=e.target.closest('[data-section]');if(!drag||!target)return;e.preventDefault();
    if(drag.item)moveItem(config,drag.section,drag.item,target.dataset.section,e.target.closest('[data-item]')?.dataset.item);
    else {const a=config.sections.findIndex(s=>s.id===drag.section),b=config.sections.findIndex(s=>s.id===target.dataset.section);const [s]=config.sections.splice(a,1);config.sections.splice(b,0,s);}
    drag=null;dirty=true;render();
  });
  root.addEventListener('dragend',()=>drag=null);
  window.addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
  return {load};
}
