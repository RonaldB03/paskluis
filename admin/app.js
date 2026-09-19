import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const SUPABASE_URL = 'https://ajldblvvlbvmgejrmhyj.supabase.co';
const SUPABASE_KEY = 'sb_publishable_D22GtKy7nDvnLv7LeBL1SA_1_ZGbN7d';
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const state = { user:null, profile:null, profiles:[], entitlements:[], threads:[], messages:[], brands:[], selectedThread:null };
const logoContexts = [
  ['home','Home'],
  ['loyalty','Klantenkaarten'],
  ['gift','Cadeaukaarten'],
  ['detail','Detailkaart'],
  ['picker','Winkelkeuze']
];
let activeLogoContext='home';
let logoLayouts={};
let previewLogoSource='';
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];

function toast(message) { const node=$('#toast'); node.textContent=message; node.classList.add('show'); setTimeout(()=>node.classList.remove('show'),2600); }
function escapeHtml(value='') { return String(value).replace(/[&<>'"]/g,(char)=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char])); }
function formatDate(value) { if(!value) return '–'; return new Intl.DateTimeFormat('nl-NL',{dateStyle:'short',timeStyle:'short'}).format(new Date(value)); }
function activeEntitlement(userId) { const now=Date.now(); return state.entitlements.find((item)=>item.user_id===userId && item.product_id==='paskluis_plus' && !item.revoked_at && (!item.expires_at || new Date(item.expires_at).getTime()>now)); }
function profileFor(id) { return state.profiles.find((profile)=>profile.id===id); }

async function boot() {
  const { data:{ session } } = await supabase.auth.getSession();
  if (!session) return showLogin();
  await authorize(session.user);
}

async function authorize(user) {
  state.user=user;
  const { data:profile, error }=await supabase.from('profiles').select('id,display_name,email,role').eq('id',user.id).single();
  if(error || !['admin','support'].includes(profile?.role)) { await supabase.auth.signOut(); return showDenied(); }
  state.profile=profile;
  $('#admin-email').textContent=profile.email || user.email;
  $('#login-view').classList.add('hidden'); $('#denied-view').classList.add('hidden'); $('#app-view').classList.remove('hidden');
  await refreshAll();
}

function showLogin() { $('#login-view').classList.remove('hidden'); $('#app-view').classList.add('hidden'); $('#denied-view').classList.add('hidden'); }
function showDenied() { $('#denied-view').classList.remove('hidden'); $('#login-view').classList.add('hidden'); $('#app-view').classList.add('hidden'); }

async function refreshAll() {
  const [profiles,entitlements,threads,brands]=await Promise.all([
    supabase.from('profiles').select('id,display_name,email,role,created_at').order('created_at',{ascending:false}),
    supabase.from('entitlements').select('*').order('created_at',{ascending:false}),
    supabase.from('support_threads').select('*').order('updated_at',{ascending:false}),
    supabase.from('brands').select('*').order('sort_order').order('name')
  ]);
  if(profiles.error) return toast('Gegevens konden niet worden geladen.');
  state.profiles=profiles.data||[]; state.entitlements=entitlements.data||[]; state.threads=threads.data||[]; state.brands=brands.data||[];
  renderAll();
}

function renderAll() { renderStats(); renderUsers(); renderThreads(); renderBrands(); }
function renderStats() {
  const plusUsers=new Set(state.entitlements.filter((e)=>activeEntitlement(e.user_id)).map((e)=>e.user_id));
  const open=state.threads.filter((t)=>t.status!=='closed').length;
  $('#stat-users').textContent=state.profiles.length; $('#stat-plus').textContent=plusUsers.size; $('#stat-support').textContent=open; $('#stat-brands').textContent=state.brands.filter((b)=>b.is_active).length; $('#open-count').textContent=open;
}

function renderUsers() {
  const query=$('#user-search').value.trim().toLowerCase();
  const rows=state.profiles.filter((p)=>`${p.display_name||''} ${p.email||''}`.toLowerCase().includes(query));
  $('#users-body').innerHTML=rows.map((p)=>{ const plus=activeEntitlement(p.id); const canManage=state.profile.role==='admin' && p.id!==state.user.id; return `<tr><td><div class="user-cell"><strong>${escapeHtml(p.display_name||'Naamloos account')}</strong><span>${escapeHtml(p.email||p.id)}</span></div></td><td><span class="pill">${escapeHtml(p.role)}</span></td><td><span class="pill ${plus?'active':''}">${plus?'Plus actief':'Gratis'}</span></td><td>${canManage?`<button class="${plus?'secondary':'primary'} small-button" data-plus-user="${p.id}" data-plus-action="${plus?'revoke':'grant'}">${plus?'Plus intrekken':'Gratis Plus geven'}</button>`:'–'}</td></tr>`; }).join('') || '<tr><td colspan="4">Geen gebruikers gevonden.</td></tr>';
}

async function changePlus(userId,action) {
  if(state.profile.role!=='admin') return;
  if(action==='grant') {
    const { error }=await supabase.from('entitlements').insert({user_id:userId,product_id:'paskluis_plus',source:'complimentary',created_by:state.user.id,note:'Toegekend via PasKluis Beheer'});
    if(error) return toast(error.message.includes('duplicate')?'Plus is al actief.':'Plus kon niet worden toegekend.');
    toast('Gratis Plus is toegekend.');
  } else {
    const { error }=await supabase.from('entitlements').update({revoked_at:new Date().toISOString()}).eq('user_id',userId).eq('product_id','paskluis_plus').is('revoked_at',null);
    if(error) return toast('Plus kon niet worden ingetrokken.');
    toast('Plus is ingetrokken.');
  }
  await refreshAll();
}

function renderThreads() {
  $('#thread-list').innerHTML=state.threads.map((t)=>{ const user=profileFor(t.user_id); return `<button class="thread-item ${state.selectedThread?.id===t.id?'active':''}" data-thread="${t.id}"><strong>${escapeHtml(t.subject)}</strong><span>${escapeHtml(user?.display_name||user?.email||'Onbekende gebruiker')} · ${formatDate(t.updated_at)}</span><span class="pill ${t.status==='open'?'open':''}">${statusLabel(t.status)}</span></button>`; }).join('') || '<div class="empty-panel" style="padding:30px">Geen gesprekken.</div>';
}
function statusLabel(status) { return status==='closed'?'Gesloten':status==='waiting_for_user'?'Wacht op gebruiker':'Open'; }

async function openThread(id) {
  state.selectedThread=state.threads.find((t)=>t.id===id); renderThreads();
  const { data,error }=await supabase.from('support_messages').select('*').eq('thread_id',id).order('created_at');
  if(error) return toast('Berichten konden niet worden geladen.');
  state.messages=data||[]; const user=profileFor(state.selectedThread.user_id);
  $('#conversation-empty').classList.add('hidden'); $('#conversation').classList.remove('hidden'); $('#conversation-subject').textContent=state.selectedThread.subject; $('#conversation-user').textContent=user?.email||user?.display_name||state.selectedThread.user_id;
  $('#toggle-thread-status').textContent=state.selectedThread.status==='closed'?'Heropenen':'Sluiten'; $('#reply-form').classList.toggle('hidden',state.selectedThread.status==='closed');
  const list=$('#message-list'); list.innerHTML=state.messages.map((m)=>`<div class="message ${m.sender_id===state.user.id?'mine':''}">${escapeHtml(m.message)}<small>${formatDate(m.created_at)}</small></div>`).join(''); list.scrollTop=list.scrollHeight;
}

async function sendReply(text) {
  const thread=state.selectedThread; if(!thread) return;
  const { error }=await supabase.from('support_messages').insert({thread_id:thread.id,sender_id:state.user.id,message:text});
  if(error) return toast('Antwoord kon niet worden verzonden.');
  await supabase.from('support_threads').update({status:'waiting_for_user',assigned_to:state.user.id,updated_at:new Date().toISOString()}).eq('id',thread.id);
  $('#reply-message').value=''; await refreshAll(); await openThread(thread.id); toast('Antwoord verzonden.');
}

async function toggleThreadStatus() {
  const thread=state.selectedThread; if(!thread) return; const next=thread.status==='closed'?'open':'closed';
  const { error }=await supabase.from('support_threads').update({status:next,updated_at:new Date().toISOString()}).eq('id',thread.id);
  if(error) return toast('Status kon niet worden aangepast.');
  await refreshAll(); await openThread(thread.id);
}

function renderBrands() {
  $('#brands-body').innerHTML=state.brands.map((b)=>`<tr><td><div class="user-cell"><strong>${escapeHtml(b.name)}</strong><span>${escapeHtml(b.slug)}</span></div></td><td><span style="display:inline-block;width:24px;height:24px;border-radius:7px;background:${escapeHtml(b.brand_color)};border:1px solid #ddd"></span></td><td>${b.supports_loyalty_card?'Klantenkaart':''}${b.supports_loyalty_card&&b.supports_gift_card?' · ':''}${b.supports_gift_card?'Cadeaukaart':''}</td><td><span class="pill ${b.is_active?'active':''}">${b.is_active?'Actief':'Verborgen'}</span></td><td><button class="secondary small-button" data-edit-brand="${b.id}">Bewerken</button></td></tr>`).join('') || '<tr><td colspan="5">Nog geen winkels toegevoegd.</td></tr>';
}

function renderLogoPreview(source='') {
  previewLogoSource=source.startsWith('assets/')?`../${source}`:source;
  const preview=$('#brand-logo-preview');
  preview.innerHTML=previewLogoSource?`<img src="${escapeHtml(previewLogoSource)}" alt="Logo voorbeeld" onerror="this.parentElement.innerHTML='<span>Voorbeeld kon niet worden geladen</span>'" />`:'<span>Nog geen logo gekozen</span>';
  renderLayoutEditor();
}

function defaultLogoLayout() { return {scale:1,x:0,y:0}; }
function readLogoLayouts(brand) {
  logoLayouts=Object.fromEntries(logoContexts.map(([key])=>[key,{
    scale:Number(brand?.[`logo_${key}_scale`]??1),
    x:Number(brand?.[`logo_${key}_x`]??0),
    y:Number(brand?.[`logo_${key}_y`]??0)
  }]));
}
function renderLayoutEditor() {
  const tabs=$('#logo-layout-tabs'); if(!tabs) return;
  tabs.innerHTML=logoContexts.map(([key,label])=>`<button type="button" class="layout-tab ${key===activeLogoContext?'active':''}" data-logo-context="${key}">${label}</button>`).join('');
  const values=logoLayouts[activeLogoContext]||defaultLogoLayout();
  $('#layout-scale').value=Math.round(values.scale*100);
  $('#layout-x').value=values.x;
  $('#layout-y').value=values.y;
  $('#layout-scale-output').textContent=`${Math.round(values.scale*100)}%`;
  $('#layout-x-output').textContent=`${values.x}%`;
  $('#layout-y-output').textContent=`${values.y}%`;
  const preview=$('#layout-card-preview');
  preview.className=`layout-card-preview context-${activeLogoContext}`;
  preview.innerHTML=buildScreenPreview(activeLogoContext);
  preview.querySelectorAll('.live-brand-logo').forEach((image)=>{
    image.style.transform=`translate(${values.x}%,${values.y}%) scale(${values.scale})`;
  });
}

function liveLogo(className='') {
  if(!previewLogoSource) return '<span class="preview-no-logo">Kies eerst een logo</span>';
  return `<img class="live-brand-logo ${className}" src="${escapeHtml(previewLogoSource)}" alt="Live logo voorbeeld" />`;
}

function previewHeader(title,actions='＋') {
  return `<div class="mock-status"><b>15:50</b><span>▮▮▮ ◉ 82%</span></div><div class="mock-header"><strong>${title}</strong><span>${actions}</span></div>`;
}

function previewNav(active) {
  return `<div class="mock-nav"><span class="${active==='home'?'active':''}">⌂<small>Home</small></span><span class="${active==='loyalty'?'active':''}">▣<small>Klantenkaarten</small></span><span>▦<small>QR-codes</small></span><span class="${active==='gift'?'active':''}">♙<small>Cadeaukaarten</small></span></div>`;
}

function mockBarcode() {
  return '<div class="mock-barcode"></div><b class="mock-code">2620 2120 0000 1</b>';
}

function buildScreenPreview(context) {
  const color=$('#brand-color').value||'#D51B46';
  const name=escapeHtml($('#brand-name').value.trim()||'Voorbeeldwinkel');
  if(context==='home') return `<div class="mock-phone">${previewHeader('PasKluis','⚙ ＋')}<div class="mock-scroll"><div class="mock-search">⌕ &nbsp; Zoek in PasKluis</div><h4>★ &nbsp;Favorieten</h4><div class="mock-grid"><div class="mock-tile logo-tile" style="background:${color}">${liveLogo()}</div><div class="mock-tile pink-tile">▦<b>Al je kaarten</b></div></div><h4>▣ &nbsp;Klantenkaarten</h4><div class="mock-grid"><div class="mock-tile logo-tile">${liveLogo()}</div><div class="mock-tile pink-tile">▦<b>Al je kaarten</b></div></div></div>${previewNav('home')}</div>`;
  if(context==='loyalty') return `<div class="mock-phone">${previewHeader('Klantenkaarten')}<div class="mock-scroll"><div class="mock-grid loyalty-grid"><div class="mock-tile logo-tile">${liveLogo()}<i>★</i></div><div class="mock-tile muted-tile">Andere kaart</div><div class="mock-tile muted-tile">Andere kaart</div><div class="mock-tile muted-tile">Andere kaart</div></div></div>${previewNav('loyalty')}</div>`;
  if(context==='gift') return `<div class="mock-phone">${previewHeader('Cadeaukaarten','↻ ▣ ＋')}<div class="mock-scroll"><div class="mock-grid gift-grid"><div class="mock-gift-tile"><div class="mock-gift-logo">${liveLogo()}</div><b>€ 50</b></div><div class="mock-gift-tile muted-gift"><div>Andere kaart</div><b>€ 25</b></div></div></div>${previewNav('gift')}</div>`;
  if(context==='detail') return `<div class="mock-phone detail-phone"><div class="mock-status"><b>15:50</b><span>▮▮▮ ◉ 82%</span></div><div class="mock-detail-header"><span>‹</span><strong>${name}</strong><span>★ ···</span></div><div class="mock-detail-card"><div class="mock-detail-logo">${liveLogo()}</div>${mockBarcode()}<div class="mock-gift-callout">U heeft een cadeaukaart beschikbaar<br><b>Saldo: € 50</b></div><b class="mock-options">ⓘ Details en opties</b></div><div class="mock-dots">● ○ ○ ○ ○</div></div>`;
  return `<div class="mock-phone picker-phone"><div class="mock-status"><b>15:50</b><span>▮▮▮ ◉ 82%</span></div><div class="mock-detail-header"><span>‹</span><strong>Kaart toevoegen</strong><span>Handmatig</span></div><div class="mock-search">⌕ &nbsp; Zoek winkel</div><h4>Populaire kaarten</h4><div class="mock-picker-list"><div class="mock-picker-row"><div class="mock-picker-logo">${liveLogo()}</div><b>${name}</b><span>›</span></div><div class="mock-picker-row muted-row"><div></div><b>Andere winkel</b><span>›</span></div><div class="mock-picker-row muted-row"><div></div><b>Andere winkel</b><span>›</span></div></div></div>`;
}
function updateActiveLogoLayout() {
  logoLayouts[activeLogoContext]={
    scale:Number($('#layout-scale').value)/100,
    x:Number($('#layout-x').value),
    y:Number($('#layout-y').value)
  };
  renderLayoutEditor();
}

function openBrandDialog(brand=null) {
  activeLogoContext='home'; readLogoLayouts(brand); $('#brand-form-title').textContent=brand?'Winkel bewerken':'Nieuwe winkel'; $('#brand-id').value=brand?.id||''; $('#brand-name').value=brand?.name||''; $('#brand-slug').value=brand?.slug||''; $('#brand-logo').value=brand?.logo_path||''; $('#brand-logo-file').value=''; $('#brand-color').value=brand?.brand_color||'#D51B46'; $('#brand-loyalty').checked=brand?.supports_loyalty_card??true; $('#brand-gift').checked=brand?.supports_gift_card??false; $('#brand-active').checked=brand?.is_active??true; $('#brand-error').textContent=''; renderLogoPreview(brand?.logo_path||''); $('#brand-dialog').showModal();
}

async function uploadBrandLogo(slug) {
  const file=$('#brand-logo-file').files[0];
  if(!file) return $('#brand-logo').value.trim()||null;
  if(file.size>2097152) throw new Error('Het logo is groter dan 2 MB.');
  const extension=(file.name.split('.').pop()||'png').toLowerCase();
  const path=`${slug}/${Date.now()}.${extension}`;
  const { error }=await supabase.storage.from('brand-logos').upload(path,file,{contentType:file.type,upsert:false});
  if(error) throw error;
  return supabase.storage.from('brand-logos').getPublicUrl(path).data.publicUrl;
}

async function saveBrand() {
  const id=$('#brand-id').value; const slug=$('#brand-slug').value.trim();
  try {
    const logoPath=await uploadBrandLogo(slug);
    const layoutPayload=Object.fromEntries(logoContexts.flatMap(([key])=>[
      [`logo_${key}_scale`,logoLayouts[key]?.scale??1],
      [`logo_${key}_x`,logoLayouts[key]?.x??0],
      [`logo_${key}_y`,logoLayouts[key]?.y??0]
    ]));
    const payload={name:$('#brand-name').value.trim(),slug,logo_path:logoPath,brand_color:$('#brand-color').value,supports_loyalty_card:$('#brand-loyalty').checked,supports_gift_card:$('#brand-gift').checked,is_active:$('#brand-active').checked,...layoutPayload,updated_at:new Date().toISOString()};
    const result=id?await supabase.from('brands').update(payload).eq('id',id):await supabase.from('brands').insert(payload);
    if(result.error) throw result.error;
    $('#brand-dialog').close(); toast('Winkel en logo opgeslagen.'); await refreshAll();
  } catch(error) { $('#brand-error').textContent=error.message||'Opslaan is niet gelukt.'; }
}

function showPage(page) { $$('.page').forEach((node)=>node.classList.remove('active-page')); $$('.nav-button').forEach((node)=>node.classList.toggle('active',node.dataset.page===page)); $(`#page-${page}`).classList.add('active-page'); $('#mobile-nav').value=page; }

$('#login-form').addEventListener('submit',async(event)=>{ event.preventDefault(); $('#login-error').textContent=''; const { data,error }=await supabase.auth.signInWithPassword({email:$('#login-email').value.trim(),password:$('#login-password').value}); if(error) return $('#login-error').textContent='E-mailadres of wachtwoord klopt niet.'; await authorize(data.user); });
$('#logout-button').addEventListener('click',async()=>{ await supabase.auth.signOut(); location.reload(); }); $('#denied-logout').addEventListener('click',async()=>{ await supabase.auth.signOut(); location.reload(); });
$$('.nav-button').forEach((button)=>button.addEventListener('click',()=>showPage(button.dataset.page))); $('#mobile-nav').addEventListener('change',(e)=>showPage(e.target.value)); $$('.refresh-all').forEach((button)=>button.addEventListener('click',refreshAll));
$('#user-search').addEventListener('input',renderUsers); $('#users-body').addEventListener('click',(event)=>{ const button=event.target.closest('[data-plus-user]'); if(button) changePlus(button.dataset.plusUser,button.dataset.plusAction); });
$('#refresh-support').addEventListener('click',refreshAll); $('#thread-list').addEventListener('click',(event)=>{ const button=event.target.closest('[data-thread]'); if(button) openThread(button.dataset.thread); });
$('#reply-form').addEventListener('submit',(event)=>{ event.preventDefault(); const text=$('#reply-message').value.trim(); if(text) sendReply(text); }); $('#toggle-thread-status').addEventListener('click',toggleThreadStatus);
$('#new-brand').addEventListener('click',()=>openBrandDialog()); $('#brands-body').addEventListener('click',(event)=>{ const button=event.target.closest('[data-edit-brand]'); if(button) openBrandDialog(state.brands.find((b)=>b.id===button.dataset.editBrand)); }); $('#cancel-brand').addEventListener('click',()=>$('#brand-dialog').close()); $('#brand-form').addEventListener('submit',(event)=>{ event.preventDefault(); saveBrand(); });
$('#brand-logo-file').addEventListener('change',(event)=>{ const file=event.target.files[0]; if(file) renderLogoPreview(URL.createObjectURL(file)); });
$('#brand-logo').addEventListener('input',(event)=>renderLogoPreview(event.target.value.trim()));
$('#brand-color').addEventListener('input',renderLayoutEditor);
$('#brand-name').addEventListener('input',renderLayoutEditor);
$('#logo-layout-tabs').addEventListener('click',(event)=>{ const button=event.target.closest('[data-logo-context]'); if(button){ activeLogoContext=button.dataset.logoContext; renderLayoutEditor(); } });
['layout-scale','layout-x','layout-y'].forEach((id)=>$(`#${id}`).addEventListener('input',updateActiveLogoLayout));
$('#reset-logo-layout').addEventListener('click',()=>{ logoLayouts[activeLogoContext]=defaultLogoLayout(); renderLayoutEditor(); });

boot();

