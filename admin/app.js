import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const SUPABASE_URL = 'https://ajldblvvlbvmgejrmhyj.supabase.co';
const SUPABASE_KEY = 'sb_publishable_D22GtKy7nDvnLv7LeBL1SA_1_ZGbN7d';
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const state = { user:null, profile:null, profiles:[], entitlements:[], threads:[], messages:[], brands:[], selectedThread:null };
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

function openBrandDialog(brand=null) {
  $('#brand-form-title').textContent=brand?'Winkel bewerken':'Nieuwe winkel'; $('#brand-id').value=brand?.id||''; $('#brand-name').value=brand?.name||''; $('#brand-slug').value=brand?.slug||''; $('#brand-logo').value=brand?.logo_path||''; $('#brand-color').value=brand?.brand_color||'#D51B46'; $('#brand-loyalty').checked=brand?.supports_loyalty_card??true; $('#brand-gift').checked=brand?.supports_gift_card??false; $('#brand-active').checked=brand?.is_active??true; $('#brand-error').textContent=''; $('#brand-dialog').showModal();
}

async function saveBrand() {
  const id=$('#brand-id').value; const payload={name:$('#brand-name').value.trim(),slug:$('#brand-slug').value.trim(),logo_path:$('#brand-logo').value.trim()||null,brand_color:$('#brand-color').value,supports_loyalty_card:$('#brand-loyalty').checked,supports_gift_card:$('#brand-gift').checked,is_active:$('#brand-active').checked,updated_at:new Date().toISOString()};
  const result=id?await supabase.from('brands').update(payload).eq('id',id):await supabase.from('brands').insert(payload); if(result.error){ $('#brand-error').textContent=result.error.message; return; } $('#brand-dialog').close(); toast('Winkel opgeslagen.'); await refreshAll();
}

function showPage(page) { $$('.page').forEach((node)=>node.classList.remove('active-page')); $$('.nav-button').forEach((node)=>node.classList.toggle('active',node.dataset.page===page)); $(`#page-${page}`).classList.add('active-page'); $('#mobile-nav').value=page; }

$('#login-form').addEventListener('submit',async(event)=>{ event.preventDefault(); $('#login-error').textContent=''; const { data,error }=await supabase.auth.signInWithPassword({email:$('#login-email').value.trim(),password:$('#login-password').value}); if(error) return $('#login-error').textContent='E-mailadres of wachtwoord klopt niet.'; await authorize(data.user); });
$('#logout-button').addEventListener('click',async()=>{ await supabase.auth.signOut(); location.reload(); }); $('#denied-logout').addEventListener('click',async()=>{ await supabase.auth.signOut(); location.reload(); });
$$('.nav-button').forEach((button)=>button.addEventListener('click',()=>showPage(button.dataset.page))); $('#mobile-nav').addEventListener('change',(e)=>showPage(e.target.value)); $$('.refresh-all').forEach((button)=>button.addEventListener('click',refreshAll));
$('#user-search').addEventListener('input',renderUsers); $('#users-body').addEventListener('click',(event)=>{ const button=event.target.closest('[data-plus-user]'); if(button) changePlus(button.dataset.plusUser,button.dataset.plusAction); });
$('#refresh-support').addEventListener('click',refreshAll); $('#thread-list').addEventListener('click',(event)=>{ const button=event.target.closest('[data-thread]'); if(button) openThread(button.dataset.thread); });
$('#reply-form').addEventListener('submit',(event)=>{ event.preventDefault(); const text=$('#reply-message').value.trim(); if(text) sendReply(text); }); $('#toggle-thread-status').addEventListener('click',toggleThreadStatus);
$('#new-brand').addEventListener('click',()=>openBrandDialog()); $('#brands-body').addEventListener('click',(event)=>{ const button=event.target.closest('[data-edit-brand]'); if(button) openBrandDialog(state.brands.find((b)=>b.id===button.dataset.editBrand)); }); $('#cancel-brand').addEventListener('click',()=>$('#brand-dialog').close()); $('#brand-form').addEventListener('submit',(event)=>{ event.preventDefault(); saveBrand(); });

boot();
