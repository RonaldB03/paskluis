export function purchaseLedgerMarkup(rows,profiles=[]){
 const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const date=value=>value?new Intl.DateTimeFormat('nl-NL',{dateStyle:'short',timeStyle:'short'}).format(new Date(value)):'–';
 return `<h2>Winkelaankopen</h2><p>De laatste 100 gecontroleerde aankopen, ook zonder PasKluis-account. Terugbetalingen beheer je bij Apple of Google. Aankoopbewijzen worden hier niet getoond.</p><div class="table-wrap"><table><thead><tr><th>Referentie</th><th>Winkel</th><th>Omgeving</th><th>Koppeling</th><th>Status</th><th>Gecontroleerd</th></tr></thead><tbody>${rows.map(row=>{
 const user=profiles.find(p=>p.id===row.user_id);
 const link=row.user_id?(user?.email||'Gekoppeld account'):row.account_linked?'Voormalig account':'Zonder account';
 return `<tr><td>${escape(row.id)}</td><td>${row.platform==='apple'?'Apple':'Google'}</td><td>${row.environment==='production'?'Echt':'Test'}</td><td>${escape(link)}</td><td>${row.revoked_at?'Ingetrokken':row.environment==='sandbox'&&Date.now()-new Date(row.verified_at).getTime()>7*86400000?'Test verlopen':'Actief'}</td><td>${escape(date(row.verified_at))}</td></tr>`;
 }).join('')||'<tr><td colspan="6">Nog geen gecontroleerde aankopen.</td></tr>'}</tbody></table></div>`;
}
