// Mirrors the menu snapshot from this installation. No card payloads are read.
export const settingActions = {
 clarity:'extraClearEnabled',location:'locationCardsEnabled',radius:'nearbyRadiusMeters',
 favoritesFirst:'favoritesFirst',favoritesHome:'showFavoritesSection',nearbyHome:'showNearbySection',
 distances:'showCardDistances',nearbyFirst:'nearbyLoyaltyCardsFirst',sorting:'cardSortOrder',start:'defaultStartTab',
 brightness:'autoBrightnessEnabled',awake:'keepScreenAwakeEnabled',hidePins:'hideSensitiveCodes',
 notifications:'giftExpiryNotificationsEnabled',language:'language',
};
const escape = v => String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const englishLabels = {'100 m':'100 m','250 m':'250 m','500 m':'500 m','1 km':'1 km','Laatst gebruikt':'Last used','Recent toegevoegd':'Recently added','Alfabetisch':'Alphabetical','Home':'Home','Klantenkaarten':'Loyalty cards','QR-codes':'QR codes','Cadeaukaarten':'Gift cards','Taal van de telefoon volgen':'Follow phone language','Nederlands':'Nederlands','English':'English'};
const options = {
 nearbyRadiusMeters:[[100,'100 m'],[250,'250 m'],[500,'500 m'],[1000,'1 km']],
 cardSortOrder:[['recent','Laatst gebruikt'],['added','Recent toegevoegd'],['alphabetical','Alfabetisch']],
 defaultStartTab:[['home','Home'],['cards','Klantenkaarten'],['qr','QR-codes'],['gift','Cadeaukaarten']],
 language:[['system','Taal van de telefoon volgen'],['nl','Nederlands'],['en','English']],
};
export function supportMenuMarkup(data) {
 const pending = data.revision > data.appliedRevision;
 const settings = data.settings || {};
 const d = data.diagnostics || {};
 const readonly = {lock:d.appLockEnabled,backupAuto:d.backupEnabled,device:d.platform};
 return (data.menu||[]).filter(s=>s.items?.length).map(s=>`<details class="support-settings-section" data-section="${escape(s.id)}" ${s.collapsed?'':'open'}><summary><strong>${escape(s.title)}</strong>${s.description?`<small>${escape(s.description)}</small>`:''}</summary>${s.items.map(item=>{
  const key = settingActions[item.action];
  const value = settings[key];
  const disabled = pending || item.locked || value === undefined || (['distances','nearbyFirst','nearbyHome'].includes(item.action) && settings.locationCardsEnabled === false);
  let control;
  if (key && options[key]) control=`<select aria-label="${escape(item.title)}" data-support-setting="${key}" ${disabled?'disabled':''}>${options[key].map(([v,label])=>`<option value="${v}" ${String(value)===String(v)?'selected':''}>${escape(data.diagnostics?.locale==='en'?englishLabels[label]:label)}</option>`).join('')}</select>`;
  else if(key) control=`<input type="checkbox" role="switch" aria-label="${escape(item.title)}" data-support-setting="${key}" ${value===true?'checked':''} ${disabled?'disabled':''}/>`;
  else control=`<span class="pill">${readonly[item.action]===true?'Aan':readonly[item.action]===false?'Uit':escape(readonly[item.action]||'Op toestel')}</span>`;
  return `<div class="support-setting-row"><div><strong>${escape(item.title)}</strong>${item.description?`<small>${escape(item.description)}</small>`:''}${item.locked?'<small>Beschikbaar met Plus</small>':''}${!key?'<small>Dit onderdeel wordt op de telefoon bediend.</small>':''}</div>${control}</div>`;
 }).join('')}</details>`).join('');
}
export function settingPatch(target) {
 const key=target.dataset.supportSetting;
 if(!Object.values(settingActions).includes(key))throw new Error('Instelling niet toegestaan');
 let value=target.type==='checkbox'?target.checked:target.value;
 if(key==='nearbyRadiusMeters')value=Number(value);
 if(options[key]&&!options[key].some(([v])=>v===value))throw new Error('Waarde niet toegestaan');
 return {[key]:value};
}
