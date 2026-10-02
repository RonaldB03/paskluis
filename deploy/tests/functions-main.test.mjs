import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const protectedSlugs=['clever-endpoint','invite-staff','nearest-brand-stores'];
const ownAuthSlugs=['send-shared-card-notification','dispatch-notifications','support-attachments','delete-account','verify-purchase','reconcile-purchases','card-backups'];
function router() {
  let handler; const dispatched=[];
  const source=readFileSync(new URL('../functions-main.ts',import.meta.url),'utf8').replace(/^import .*$/m,'').replace(/^export /gm,'');
  const errors=Object.fromEntries(['NotFound','InvalidWorkerCreation','WorkerRequestCancelled','WorkerRequestIdleTimeout','InvalidWorkerResponse','WorkerAlreadyRetired'].map(k=>[k,class extends Error{}]));
  const context={Request,Response,Headers,URL,TextEncoder,console:{log(){},warn(){},error(){}},
    jose:{decodeProtectedHeader(token){if(token==='malformed')throw Error();return {alg:token==='unsigned'?'none':'HS256'};},async jwtVerify(token){if(token!=='valid')throw Error('Invalid signature');}},
    Deno:{errors,env:{get(k){return k==='JWT_SECRET'?'test-secret':undefined;},toObject(){return {JWT_SECRET:'test-secret'};}},serve(fn){handler=fn;},async stat(){return {isDirectory:true};}},
    EdgeRuntime:{applySupabaseTag(){},userWorkers:{async create(options){return {async fetch(req){dispatched.push({options,req});return new Response('ok');}};}}}};
  vm.runInNewContext(stripTypeScriptTypes(source,{mode:'transform'}),context);
  return {dispatched,request(slug,token,method='POST',extra={}){return handler(new Request('http://edge/'+slug,{method,headers:{...(token?{Authorization:'Bearer '+token}:{}),...extra}}));}};
}
test('protected functions reject absent, forged, malformed and unsigned JWTs before dispatch',async()=>{
  const r=router();
  for(const slug of protectedSlugs)for(const token of [undefined,'forged','malformed','unsigned'])assert.equal((await r.request(slug,token)).status,401);
  assert.equal(r.dispatched.length,0);
});
test('valid JWTs reach protected functions and CORS preflight remains available',async()=>{
  const r=router();
  for(const slug of protectedSlugs){assert.equal((await r.request(slug,'valid')).status,200);assert.equal((await r.request(slug,undefined,'OPTIONS')).status,200);}
  assert.equal(r.dispatched.length,6);
});
test('functions with their own authentication receive unauthenticated requests for their own checks',async()=>{
  const r=router();
  for(const slug of ownAuthSlugs)assert.equal((await r.request(slug)).status,200);
  assert.equal(r.dispatched.length,7);
});
test('unknown functions and inherited object properties never dispatch',async()=>{
  const r=router();
  for(const slug of ['hello','main','unknown','toString','constructor','__proto__',''])assert.equal((await r.request(slug,'valid')).status,404);
  assert.equal(r.dispatched.length,0);
});
test('gateway compatibility tokens are verified and removed before user function dispatch',async()=>{
  const r=router();
  assert.equal((await r.request('clever-endpoint',undefined,'POST',{'sb-api-key':'forged'})).status,401);
  assert.equal((await r.request('clever-endpoint',undefined,'POST',{'sb-api-key':'valid'})).status,200);
  assert.equal(r.dispatched[0].req.headers.get('sb-api-key'),null);
  assert.equal(r.dispatched[0].options.envVars.find(([k])=>k==='SUPABASE_FUNCTION_SLUG')[1],'clever-endpoint');
});
test('attachment URL conversion preserves signed token and only rewrites internal Storage origin',()=>{
  const installer=readFileSync(new URL('../install-supabase-functions.py',import.meta.url),'utf8');
  const helper=installer.split('helper="""')[1].split('"""')[0].replaceAll('\\\\','\\');
  let external='https://api.paskluis.com/';
  const context={Deno:{env:{get(k){return k==='SUPABASE_URL'?'http://api-gw:8000/':external;}}}};
  vm.createContext(context);vm.runInContext(stripTypeScriptTypes(helper,{mode:'transform'}),context);
  const suffix='/storage/v1/object/sign/support-attachments/a/b.png?token=abc%2Fdef';
  assert.equal(context.publicStorageUrl('http://api-gw:8000'+suffix),'https://api.paskluis.com'+suffix);
  const cloud='https://cloud.supabase.co'+suffix;
  assert.equal(context.publicStorageUrl(cloud),cloud);
  assert.equal(context.publicStorageUrl('http://api-gw:8000/rest/v1/private'),'http://api-gw:8000/rest/v1/private');
  external=undefined;assert.equal(context.publicStorageUrl('http://api-gw:8000'+suffix),'http://api-gw:8000'+suffix);
});
