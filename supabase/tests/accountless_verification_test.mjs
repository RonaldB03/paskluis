import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
const source=stripTypeScriptTypes((await readFile(new URL('../functions/verify-store-purchase/index.ts',import.meta.url),'utf8')).replace(/^import .*;\r?\n/gm,''));
function setup({proofValid=true,user=null,session=true,revoked=false,saveError=false,environment='production',signedEnvironment='Production'}={}){
 let handler;const calls=[];const saved=[];
 const admin={rpc:async(name,args)=>{if(name==='has_active_device_session')return {data:session};saved.push(args);return saveError?{error:{message:'PURCHASE_LINKED_TO_ANOTHER_ACCOUNT'}}:{data:{active:!revoked,linkedUserId:user?.id||null}}},auth:{getUser:async()=>({data:{user},error:null})}};
 const ctx={Deno:{env:{get:k=>k==='ALLOW_SANDBOX_PURCHASES'?'true':'fake'},serve:fn=>handler=fn},createClient:()=>admin,Response,AbortSignal,console:{error:()=>{}},fetch:async()=>{calls.push('signed-proof');return Response.json({transactionId:'tx',originalTransactionId:'original',appAccountToken:'correlation',environment:signedEnvironment},{status:proofValid?200:400})},apple:async()=>{calls.push('apple-api');return {id:'original',environment,revoked,accountToken:'correlation'}},google:async()=>{calls.push('google-api');return {id:'hash',environment,revoked,accountToken:'correlation'}}};
 vm.runInNewContext(source,ctx);
 return {calls,saved,run:(body={})=>handler(new Request('https://example.invalid',{method:'POST',body:JSON.stringify({productId:'paskluis_plus',platform:'apple',proof:'signed-proof-long-enough',linkAccount:false,...body})}))};
}
test('verified guest receipt grants access without app authentication',async()=>{const s=setup();const r=await s.run();assert.equal(r.status,200);assert.equal((await r.json()).active,true);assert.equal(s.saved[0].p_user_id,null);assert.deepEqual(s.calls,['signed-proof','apple-api']);});
test('a forged signed receipt never reaches store lookup or persistence',async()=>{const s=setup({proofValid:false});assert.equal((await s.run()).status,400);assert.equal(s.saved.length,0);assert.deepEqual(s.calls,['signed-proof']);});
test('guessable transaction ID alone is rejected',async()=>{const s=setup();assert.equal((await s.run({proof:'12345'})).status,400);assert.equal(s.calls.length,0);});
test('account linking requires authenticated active session',async()=>{for(const options of [{},{user:{id:'u'},session:false}]){const s=setup(options);assert.ok([401,403].includes((await s.run({linkAccount:true})).status));assert.equal(s.calls.length,0);}});
test('linking uses authenticated identity and ignores supplied user ID',async()=>{const s=setup({user:{id:'real'}});await s.run({linkAccount:true,userId:'attacker'});assert.equal(s.saved[0].p_user_id,'real');});
test('a receipt already claimed by another account cannot be transferred',async()=>{const s=setup({user:{id:'other'},saveError:true});assert.equal((await s.run({linkAccount:true})).status,400);});
test('fresh refund state overrides the old signed receipt',async()=>{const s=setup({revoked:true});const r=await s.run();const body=await r.json();assert.equal(body.verified,true);assert.equal(body.active,false);assert.equal(s.saved[0].p_revoked,true);});
test('sandbox proof cannot masquerade as production',async()=>{const s=setup({signedEnvironment:'Sandbox'});assert.equal((await s.run()).status,400);assert.equal(s.saved.length,0);});
test('Google receipt works without obfuscated app account identity',async()=>{const s=setup();assert.equal((await s.run({platform:'google'})).status,200);assert.deepEqual(s.calls,['google-api']);});
test('other products and oversized proofs fail before external calls',async()=>{for(const body of [{productId:'other'},{proof:'x'.repeat(25000)}]){const s=setup();assert.equal((await s.run(body)).status,400);assert.equal(s.calls.length,0);}});
