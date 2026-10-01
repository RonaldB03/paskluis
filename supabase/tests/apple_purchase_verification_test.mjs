import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
const source=stripTypeScriptTypes((await readFile(new URL('../functions/verify-purchase/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,''));
class JWT{setProtectedHeader(){return this}setIssuer(){return this}setAudience(){return this}setIssuedAt(){return this}setExpirationTime(){return this}async sign(){return 'fake'}}
function setup({status=401,allow=true,sandboxStatus=200,mismatch=false,wrongEnvironment=false}={}){
 const calls=[];const diag={stage:''};
 const env={APPLE_IAP_KEY_JSON:JSON.stringify({privateKey:'fake',keyId:'fake',issuerId:'fake'}),ALLOW_SANDBOX_PURCHASES:String(allow)};
 const ctx=vm.createContext({Deno:{env:{get:k=>env[k]},serve:()=>{}},SignJWT:JWT,importPKCS8:async()=>({}),decodeJwt:JSON.parse,Response,console,
 fetch:async(url)=>{calls.push(url);if(calls.length===1)return new Response('',{status});if(sandboxStatus!==200)return new Response('',{status:sandboxStatus});return Response.json({signedTransactionInfo:JSON.stringify({bundleId:'nl.paskluis.app',productId:'paskluis_plus',type:'Non-Consumable',appAccountToken:mismatch?'other':'owner',environment:wrongEnvironment?'Production':'Sandbox',transactionId:'test'})});}});
 vm.runInContext(source,ctx);return {run:()=>ctx.apple('test','owner',diag),calls,diag};
}
for(const status of [401,404])test(`production ${status} can verify sandbox purchase`,async()=>{const s=setup({status});assert.equal((await s.run()).environment,'sandbox');assert.equal(s.calls.length,2);assert.ok(s.calls[1].startsWith('https://api.storekit-sandbox.itunes.apple.com/'));});
test('sandbox remains disabled without explicit setting',async()=>{const s=setup({allow:false});await assert.rejects(s.run());assert.equal(s.calls.length,1);});
test('failed sandbox authentication never grants access',async()=>{const s=setup({sandboxStatus:401});await assert.rejects(s.run());assert.equal(s.diag.stage,'apple_sandbox_lookup');assert.equal(s.diag.status,401);});
test('sandbox still requires same account',async()=>{await assert.rejects(setup({mismatch:true}).run(),/PURCHASE_ACCOUNT_MISMATCH/);});
test('sandbox still requires matching environment',async()=>{await assert.rejects(setup({wrongEnvironment:true}).run(),/INVALID_ENVIRONMENT/);});
test('production outage does not cause sandbox fallback',async()=>{const s=setup({status:500});await assert.rejects(s.run());assert.equal(s.calls.length,1);});
