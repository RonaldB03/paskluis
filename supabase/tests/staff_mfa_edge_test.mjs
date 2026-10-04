import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {stripTypeScriptTypes} from 'node:module';

async function setup(slug,{allowed=false,rpcError=false,ownThread=false}={}) {
  const source=stripTypeScriptTypes((await readFile(new URL(`../functions/${slug}/index.ts`,import.meta.url),'utf8')).replace(/^import .*;\r?\n/gm,''));
  const writes=[],checks=[],signed=[];let handler;
  const threadId='ee330000-0000-4000-8000-000000000090';
  function chain(table,isService) {
    let mutation=null;
    const result=()=>({data:table==='support_threads'?{id:threadId,user_id:ownThread?'caller':'other',status:'open',locale:'nl'}:
      table==='support_attachments'?[{id:'attachment',message_id:'message',storage_path:'private-image'}]:{id:'target',email:'target@example.invalid',role:'admin'}});
    const q={select:()=>q,eq:()=>q,ilike:()=>q,order:()=>q,limit:()=>q,
      maybeSingle:async()=>result(),single:async()=>result(),
      update:value=>{mutation=value;return q},
      then:resolve=>{if(mutation)writes.push({table,isService,mutation});return Promise.resolve(resolve(result()))}};
    return q;
  }
  const caller={auth:{getUser:async()=>({data:{user:{id:'caller'}}})},
    rpc:async name=>{checks.push(name);return {data:name==='has_active_device_session'?ownThread:allowed,error:rpcError?{message:'unavailable'}:null}},
    from:table=>chain(table,false)};
  const admin={from:table=>chain(table,true),auth:{admin:{inviteUserByEmail:async()=>{writes.push('invited');return {data:{user:{id:'new'}}}}}},
    storage:{from:()=>({createSignedUrl:async path=>{signed.push(path);return {data:{signedUrl:'https://example.invalid/test'}}}})}};
  vm.runInNewContext(source,{Deno:{env:{get:key=>key==='SUPABASE_SERVICE_ROLE_KEY'?'service':'anon'},serve:fn=>handler=fn},createClient:(_url,key)=>key==='service'?admin:caller,
    Response,TextEncoder,TextDecoder,Uint8Array,atob,crypto:globalThis.crypto,console:{error:()=>{}}});
  return {writes,checks,signed,run:()=>handler(new Request('https://example.invalid/'+slug,{method:'POST',headers:{Authorization:'Bearer synthetic-token'},body:JSON.stringify(slug==='support-attachments'?{action:'list',thread_id:threadId}:{email:'target@example.invalid',role:'support'})}))};
}
for(const slug of ['invite-staff','clever-endpoint']) {
  test(`${slug}: denied or failed caller MFA check cannot change staff`,async()=>{
    for(const opts of [{allowed:false},{allowed:true,rpcError:true}]) {
      const ctx=await setup(slug,opts);const response=await ctx.run();
      assert.equal(response.status,403);assert.equal(ctx.writes.length,0);assert.deepEqual(ctx.checks,['is_admin']);
    }
  });
  test(`${slug}: verified admin continues through caller authorization`,async()=>{
    const ctx=await setup(slug,{allowed:true});assert.equal((await ctx.run()).status,200);
    assert.equal(ctx.writes.length,1);assert.deepEqual(ctx.checks,['is_admin']);
  });
}
test('support attachment URLs require verified staff for someone else’s thread',async()=>{
  for(const opts of [{allowed:false},{allowed:true,rpcError:true}]) {
    const ctx=await setup('support-attachments',opts);assert.equal((await ctx.run()).status,400);assert.equal(ctx.signed.length,0);
  }
  const ctx=await setup('support-attachments',{allowed:true});assert.equal((await ctx.run()).status,200);assert.equal(ctx.signed.length,1);assert.deepEqual(ctx.checks,['is_staff']);
});
test('customers retain attachment access to their own thread with an active device session',async()=>{
  const ctx=await setup('support-attachments',{ownThread:true});assert.equal((await ctx.run()).status,200);assert.equal(ctx.signed.length,1);
  assert.deepEqual(ctx.checks,['is_staff','has_active_device_session']);
});
