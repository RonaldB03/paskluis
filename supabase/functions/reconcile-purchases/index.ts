import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {SignJWT,importPKCS8,decodeJwt} from 'https://esm.sh/jose@5.9.6';

const PACKAGE='nl.paskluis.app', PRODUCT='paskluis_plus';
const later=(minutes:number)=>new Date(Date.now()+minutes*60000).toISOString();
async function json(url:string,options:RequestInit={}) {
 const response=await fetch(url,{...options,signal:AbortSignal.timeout(10000)});
 if(!response.ok)throw new Error(`STORE_HTTP_${response.status}`);
 return await response.json();
}
async function applyRefund(admin:any,row:any,revoked:boolean) {
 if(Boolean(row.revoked_at)===revoked)return;
 const saved=await admin.rpc('record_verified_purchase',{p_user_id:row.user_id,p_platform:row.platform,
  p_transaction_id:row.transaction_id,p_environment:row.environment,p_revoked:revoked});
 if(saved.error)throw new Error('PURCHASE_SAVE_FAILED');
}
async function apple(admin:any) {
 const cfg=JSON.parse(Deno.env.get('APPLE_IAP_KEY_JSON')||'{}');
 if(!cfg.privateKey||!cfg.keyId||!cfg.issuerId)throw new Error('STORE_NOT_CONFIGURED');
 const key=await importPKCS8(cfg.privateKey,'ES256');
 const token=await new SignJWT({bid:PACKAGE}).setProtectedHeader({alg:'ES256',kid:cfg.keyId,typ:'JWT'})
  .setIssuer(cfg.issuerId).setAudience('appstoreconnect-v1').setIssuedAt().setExpirationTime('5m').sign(key);
 const purchases=await admin.from('store_purchases').select('*').eq('platform','apple')
  .eq('environment','production').not('user_id','is',null).lte('reconcile_after',new Date().toISOString())
  .order('reconcile_after').limit(10);
 if(purchases.error)throw new Error('PURCHASE_READ_FAILED');
 // Two bounded batches: one slow store request cannot exhaust the worker lease.
 let failures=0;
 for(let offset=0;offset<(purchases.data||[]).length;offset+=5) {
  await Promise.all(purchases.data.slice(offset,offset+5).map(async(row:any)=>{
   let failed=false;
   try {
    const result=await json(`https://api.storekit.itunes.apple.com/inApps/v1/transactions/${encodeURIComponent(row.transaction_id)}`,{headers:{Authorization:`Bearer ${token}`}});
    // Decode only Apple's authenticated HTTPS response, never client-supplied JWS.
    const tx=decodeJwt(result.signedTransactionInfo);
    if(tx.bundleId!==PACKAGE||tx.productId!==PRODUCT||tx.type!=='Non-Consumable'||tx.environment!=='Production'
     ||tx.appAccountToken!==row.user_id||String(tx.originalTransactionId||tx.transactionId)!==row.transaction_id)
     throw new Error('PURCHASE_IDENTITY_MISMATCH');
    await applyRefund(admin,row,Boolean(tx.revocationDate));
   } catch {failed=true;failures++;}
   const saved=await admin.from('store_purchases').update({reconcile_after:later(failed?15:1440)}).eq('id',row.id);
   if(saved.error)failures++;
  }));
 }
 if(failures)throw new Error('APPLE_RECONCILIATION_INCOMPLETE');
 return {page_token:null,next_check:later(10),last_success_at:new Date().toISOString()};
}
async function google(admin:any,state:any) {
 const cfg=JSON.parse(Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON')||'{}');
 if(!cfg.private_key||!cfg.client_email)throw new Error('STORE_NOT_CONFIGURED');
 const key=await importPKCS8(cfg.private_key,'RS256');
 const assertion=await new SignJWT({scope:'https://www.googleapis.com/auth/androidpublisher'})
  .setProtectedHeader({alg:'RS256',typ:'JWT'}).setIssuer(cfg.client_email).setAudience('https://oauth2.googleapis.com/token')
  .setIssuedAt().setExpirationTime('5m').sign(key);
 const auth=await json('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},
  body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})});
 if(!auth.access_token)throw new Error('STORE_AUTH_FAILED');
 let pageToken=state.page_token;
 // Always cover the provider's complete 30-day refund window. Hashed tokens
 // match our verified ledger; raw purchase tokens are never persisted or logged.
 for(let page=0;page<3;page++) {
  const query=new URLSearchParams({type:'0',maxResults:'1000'});
  if(pageToken)query.set('token',pageToken);
  const result=await json(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/voidedpurchases?${query}`,
   {headers:{Authorization:`Bearer ${auth.access_token}`}});
  const hashes=[];
  for(const item of result.voidedPurchases||[]) {
   if(typeof item.purchaseToken!=='string'||!item.purchaseToken)continue;
   const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(item.purchaseToken));
   hashes.push(Array.from(new Uint8Array(digest)).map(b=>b.toString(16).padStart(2,'0')).join(''));
  }
  // Keep REST URLs bounded even if Google returns a large page.
  for(let offset=0;offset<hashes.length;offset+=50) {
   const rows=await admin.from('store_purchases').select('*').eq('platform','google')
    .not('user_id','is',null).is('revoked_at',null).in('transaction_id',hashes.slice(offset,offset+50));
   if(rows.error)throw new Error('PURCHASE_READ_FAILED');
   for(const row of rows.data||[])await applyRefund(admin,row,true);
  }
  pageToken=result.tokenPagination?.nextPageToken||null;
  if(!pageToken)break;
 }
 return {page_token:pageToken,next_check:later(pageToken?10:360),
  ...(pageToken?{}:{last_success_at:new Date().toISOString()})};
}
Deno.serve(async request=>{
 const secret=Deno.env.get('NOTIFICATION_WORKER_SECRET')||'';
 if(request.method!=='POST'||secret.length<32||request.headers.get('x-job-secret')!==secret)
  return Response.json({error:'UNAUTHORIZED'},{status:401});
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
 const results:Record<string,string>={};
 for(const platform of ['apple','google']) {
  const claimed=await admin.rpc('claim_purchase_reconciliation',{p_platform:platform});
  if(claimed.error){results[platform]='CLAIM_FAILED';continue;}
  if(claimed.data!==true){results[platform]='not_due';continue;}
  try {
   const state=await admin.from('purchase_reconciliation_state').select('*').eq('platform',platform).single();
   if(state.error)throw new Error('STATE_READ_FAILED');
   const checkpoint=platform==='apple'?await apple(admin):await google(admin,state.data);
   const saved=await admin.from('purchase_reconciliation_state').update({...checkpoint,last_error:null,locked_until:null}).eq('platform',platform);
   if(saved.error)throw new Error('STATE_SAVE_FAILED');
   results[platform]='checked';
  } catch(error) {
   const message=error instanceof Error?error.message:'';
   const code=/^(STORE_NOT_CONFIGURED|STORE_HTTP_\d{3}|STORE_AUTH_FAILED|PURCHASE_READ_FAILED|PURCHASE_SAVE_FAILED|STATE_READ_FAILED|STATE_SAVE_FAILED|APPLE_RECONCILIATION_INCOMPLETE)$/.test(message)?message:'STORE_CHECK_FAILED';
   await admin.from('purchase_reconciliation_state').update({locked_until:null,next_check:later(15),last_error:code,
    ...(code==='STORE_HTTP_400'?{page_token:null}:{})}).eq('platform',platform);
   results[platform]=code;
  }
 }
 return Response.json(results,{status:Object.values(results).some(v=>!['checked','not_due'].includes(v))?503:200});
});
