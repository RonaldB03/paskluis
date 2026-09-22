import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import {webcrypto} from 'node:crypto';
import vm from 'node:vm';

const source=stripTypeScriptTypes((await readFile(new URL('../functions/reconcile-purchases/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,''));
const workerSecret='isolated-test-worker-secret-32-characters';
const tokenHash=Buffer.from(await webcrypto.subtle.digest('SHA-256',new TextEncoder().encode('google-purchase'))).toString('hex');
function setup({appleError=false,mismatch=false,googlePages=false,saveError=false,claimed=true}={}) {
 let handler;const records=[],updates=[],calls=[];
 const apple={id:'apple-row',platform:'apple',user_id:'owner',transaction_id:'apple-original',environment:'production',revoked_at:null};
 const google={id:'google-row',platform:'google',user_id:'owner',transaction_id:tokenHash,environment:'production',revoked_at:null};
 const client={rpc:async(name,args)=>{
  if(name==='claim_purchase_reconciliation')return {data:claimed};
  records.push(args);return saveError?{error:{message:'Unavailable'}}:{data:false};
 },from:table=>{
  let platform,mutation,hashes;
  const chain={select:()=>chain,eq:(key,value)=>{if(key==='platform')platform=value;return chain;},
   not:()=>chain,is:()=>chain,lte:()=>chain,order:()=>chain,limit:()=>chain,
   in:(_key,value)=>{hashes=value;return chain;},update:value=>{mutation=value;return chain;},
   single:async()=>({data:{page_token:null}}),then:resolve=>{
    if(mutation)updates.push({table,platform,...mutation});
    const data=table==='store_purchases'?(platform==='apple'?[apple]:(hashes?.includes(tokenHash)?[google]:[])):null;
    return Promise.resolve(resolve({data}));
   }};return chain;
 }};
 class Jwt {setProtectedHeader(){return this;}setIssuer(){return this;}setAudience(){return this;}setIssuedAt(){return this;}setExpirationTime(){return this;}async sign(){return 'fake-jwt';}}
 const env={NOTIFICATION_WORKER_SECRET:workerSecret,SUPABASE_URL:'https://example.invalid',SUPABASE_SERVICE_ROLE_KEY:'fake',
  APPLE_IAP_KEY_JSON:JSON.stringify({privateKey:'fake',keyId:'fake',issuerId:'fake'}),
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:JSON.stringify({private_key:'fake',client_email:'fake@example.invalid'})};
 vm.runInNewContext(source,{Deno:{env:{get:key=>env[key]},serve:fn=>handler=fn},createClient:()=>client,
  importPKCS8:async()=>({}),SignJWT:Jwt,decodeJwt:JSON.parse,crypto:webcrypto,TextEncoder,Uint8Array,
  URLSearchParams,AbortSignal,Response,Date,
  fetch:async(url)=>{
   calls.push(url);
   if(url.includes('storekit.itunes.apple.com'))return appleError?Response.json({}, {status:503}):Response.json({signedTransactionInfo:JSON.stringify({bundleId:'nl.paskluis.app',productId:'paskluis_plus',type:'Non-Consumable',environment:'Production',appAccountToken:mismatch?'other':'owner',originalTransactionId:'apple-original',revocationDate:123456})});
   if(url==='https://oauth2.googleapis.com/token')return Response.json({access_token:'fake-access'});
   assert.match(url,/^https:\/\/androidpublisher.googleapis.com\/androidpublisher\/v3\/applications\/nl.paskluis.app\/purchases\/voidedpurchases\?/);
   if(googlePages&&!url.includes('token=next'))return Response.json({voidedPurchases:[{purchaseToken:'unknown-purchase'}],tokenPagination:{nextPageToken:'next'}});
   return Response.json({voidedPurchases:[{purchaseToken:'google-purchase'}]});
  }});
 return {records,updates,calls,run:secret=>handler(new Request('https://example.invalid/worker',{method:'POST',headers:{'x-job-secret':secret??workerSecret}}))};
}

test('only the server worker can claim or reconcile purchases',async()=>{
 const ctx=setup();assert.equal((await ctx.run('wrong')).status,401);assert.equal(ctx.calls.length,0);assert.equal(ctx.records.length,0);
});
test('verified Apple and hashed Google refunds reconcile the account ledger',async()=>{
 const ctx=setup();assert.equal((await ctx.run()).status,200);
 assert.equal(ctx.records.length,2);assert.ok(ctx.records.every(r=>r.p_revoked===true&&r.p_user_id==='owner'));
 assert.equal(ctx.records.find(r=>r.p_platform==='google').p_transaction_id,tokenHash);
 assert.ok(!JSON.stringify(ctx.updates).includes('google-purchase'));
});
test('Apple downtime preserves access while Google can still reconcile',async()=>{
 const ctx=setup({appleError:true});assert.equal((await ctx.run()).status,503);
 assert.equal(ctx.records.length,1);assert.equal(ctx.records[0].p_platform,'google');
 assert.ok(ctx.updates.some(r=>r.platform==='apple'&&r.last_error==='APPLE_RECONCILIATION_INCOMPLETE'));
});
test('an Apple result for a different account is never applied',async()=>{
 const ctx=setup({mismatch:true});await ctx.run();assert.ok(ctx.records.every(r=>r.p_platform!=='apple'));
});
test('Google follows pagination and ignores refunds absent from our purchase ledger',async()=>{
 const ctx=setup({googlePages:true});assert.equal((await ctx.run()).status,200);
 assert.ok(ctx.calls.some(url=>url.includes('token=next')));assert.equal(ctx.records.filter(r=>r.p_platform==='google').length,1);
});
test('failed ledger writes do not advance a successful reconciliation checkpoint',async()=>{
 const ctx=setup({saveError:true});assert.equal((await ctx.run()).status,503);
 assert.ok(!ctx.updates.some(r=>r.last_success_at));
});
test('an overlapping worker does not contact the stores',async()=>{
 const ctx=setup({claimed:false});assert.equal((await ctx.run()).status,200);assert.equal(ctx.calls.length,0);
});
