// Exercises the actual Edge handler with isolated provider/database adapters.
// Node 24: node --test supabase/tests/notification_worker_test.mjs
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {stripTypeScriptTypes} from 'node:module';

const source = stripTypeScriptTypes((await readFile(new URL('../functions/dispatch-notifications/index.ts', import.meta.url),'utf8'))
  .replace(/^import .*;\n/gm,''));

function setup({pushFails=false,mailFails=false,mailErrorCode=null,invalidMailConfig=false,mailbox=null,inbox=null,jobPatch={},membershipRevoked=false,readFails=false}={}) {
  const updates=[],mail=[],push=[],transports=[];
  const job={id:'test-event',recipient_id:'test-user',thread_id:'test-thread',membership_id:'test-membership',
    event_type:'support_reply',attempts:1,push_done:false,email_done:false,...jobPatch};
  const rows={support_threads:{user_id:'test-user',guest_email:null,locale:'nl'},profiles:{email:'test@example.invalid'},
    account_device_sessions:{device_id:'test-device'},push_device_tokens:[{id:'test-push',token:'fake-push-token',locale:'nl'}],
    card_share_members:{revoked_at:membershipRevoked?'2026-01-01':null,removed_by_recipient_at:null}};
  let handler,claims=0,mailClosed=0;
  const client={
    rpc:async()=>{claims++;return {data:[structuredClone(job)]};},
    from:table=>{
      let mutation;
      const chain={select:()=>chain,eq:()=>chain,maybeSingle:async()=>readFails?({data:null,error:{message:'Database unavailable'}}):({data:rows[table]}),
        update:value=>{mutation=value;return chain;},delete:()=>chain,
        then:resolve=>{if(mutation)updates.push(structuredClone(mutation));return Promise.resolve(resolve({data:rows[table]}));}};
      return chain;
    },
  };
  const env={NOTIFICATION_WORKER_SECRET:'test-worker-secret',SUPABASE_URL:'https://example.invalid',SUPABASE_SERVICE_ROLE_KEY:'fake',
    FIREBASE_SERVICE_ACCOUNT_JSON:JSON.stringify({private_key:'-----BEGIN PRIVATE KEY-----\nYQ==\n-----END PRIVATE KEY-----',client_email:'test@example.invalid',project_id:'test'}),
    SUPPORT_SMTP_JSON:invalidMailConfig?'invalid-json':JSON.stringify({host:'example.invalid',user:'test',password:'fake',from:'test@example.invalid'})};
  if(mailbox)env.SUPPORT_MAILBOX=mailbox;
  if(inbox)env.SUPPORT_INBOX_EMAIL=inbox;
  vm.runInNewContext(source,{
    Deno:{env:{get:key=>env[key]},serve:callback=>handler=callback},createClient:()=>client,
    nodemailer:{createTransport:config=>{transports.push(config);return {sendMail:async data=>{mail.push(data);if(mailFails)throw Object.assign(new Error('Do not expose credentials or provider response'),{code:mailErrorCode});},close:()=>{mailClosed++;}};}},
    crypto:{subtle:{importKey:async()=>({}),sign:async()=>new Uint8Array([1,2,3])}},
    fetch:async(url,options)=>{
      if(url==='https://oauth2.googleapis.com/token')return Response.json({access_token:'fake-access'});
      assert.match(url,/^https:\/\/fcm.googleapis.com\/v1\/projects\/test\/messages:send$/);
      push.push(JSON.parse(options.body));
      return Response.json(pushFails?{error:'Unavailable'}:{name:'accepted'},{status:pushFails?503:200});
    },Response,TextEncoder,URLSearchParams,Uint8Array,AbortSignal,btoa,atob,
  });
  return {updates,mail,push,transports,claims:()=>claims,mailClosed:()=>mailClosed,run:secret=>handler(new Request('https://example.invalid/worker',{
    method:'POST',headers:{'x-job-secret':secret??env.NOTIFICATION_WORKER_SECRET},body:'{}'}))};
}

test('a push failure still delivers email and retries only the incomplete channel',async()=>{
  const ctx=setup({pushFails:true});await ctx.run();
  assert.equal(ctx.mail.length,1);assert.equal(ctx.push.length,1);
  assert.equal(ctx.updates.at(-1).email_done,true);
  assert.equal(ctx.updates.at(-1).push_done,false);
  assert.equal(ctx.updates.at(-1).last_error,'PUSH_503');
  assert.equal(ctx.updates.at(-1).delivered_at,undefined);
  const retry=setup({jobPatch:{email_done:true}});await retry.run();
  assert.equal(retry.mail.length,0);assert.ok(retry.updates.at(-1).delivered_at);
});

test('mail failure preserves successful push to prevent a duplicate on retry',async()=>{
  const ctx=setup({mailFails:true});await ctx.run();
  assert.equal(ctx.updates.at(-1).push_done,true);assert.equal(ctx.updates.at(-1).email_done,false);
  const retry=setup({jobPatch:{push_done:true}});await retry.run();
  assert.equal(retry.push.length,0);assert.equal(retry.mail.length,1);assert.ok(retry.updates.at(-1).delivered_at);
});

test('revoked shared access sends neither a stale push nor an email',async()=>{
  const ctx=setup({membershipRevoked:true,jobPatch:{event_type:'card_shared'}});await ctx.run();
  assert.equal(ctx.push.length,0);assert.equal(ctx.mail.length,0);assert.ok(ctx.updates.at(-1).delivered_at);
});

test('unauthorized requests cannot claim work or contact providers',async()=>{
  const ctx=setup();const result=await ctx.run('wrong-secret');
  assert.equal(result.status,401);assert.equal(ctx.claims(),0);assert.equal(ctx.mail.length,0);assert.equal(ctx.push.length,0);
});

test('database lookup failure retains the job for retry instead of marking it delivered',async()=>{
  const ctx=setup({readFails:true,jobPatch:{event_type:'card_shared'}});await ctx.run();
  assert.equal(ctx.mail.length,0);assert.equal(ctx.push.length,0);
  assert.equal(ctx.updates.at(-1).delivered_at,undefined);
  assert.equal(ctx.updates.at(-1).push_done,false);
  assert.ok(ctx.updates.at(-1).available_at);
});

test('SMTP diagnostics expose only bounded codes and close failed connections',async()=>{
  for(const code of ['EAUTH','ETIMEDOUT','credential-bearing-arbitrary-code']){
    const ctx=setup({mailFails:true,mailErrorCode:code});await ctx.run();
    assert.equal(ctx.updates.at(-1).last_error,code==='credential-bearing-arbitrary-code'?'MAIL_SEND_FAILED':`MAIL_${code}`);
    assert.equal(ctx.updates.at(-1).email_done,false);
    assert.equal(ctx.mailClosed(),1);
  }
  const malformed=setup({invalidMailConfig:true});await malformed.run();
  assert.equal(malformed.updates.at(-1).last_error,'MAIL_INVALID_CONFIG');
  assert.equal(malformed.mail.length,0);
});

test('a mailbox correction preserves the password and aligns login, sender and staff recipient',async()=>{
  const ctx=setup({mailbox:' info@paskluis.com ',jobPatch:{event_type:'support_question'}});await ctx.run();
  assert.equal(ctx.transports[0].auth.user,'info@paskluis.com');
  assert.equal(ctx.transports[0].auth.pass,'fake');
  assert.equal(ctx.mail[0].from.address,'info@paskluis.com');
  assert.equal(ctx.mail[0].to,'info@paskluis.com');
  assert.equal(ctx.updates.at(-1).email_done,true);
  const override=setup({mailbox:'info@paskluis.com',inbox:'staff@example.invalid',jobPatch:{event_type:'support_question'}});await override.run();
  assert.equal(override.mail[0].to,'staff@example.invalid');
});
