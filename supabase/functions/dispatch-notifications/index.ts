import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import nodemailer from 'npm:nodemailer@6.10.1';
function base64Url(value: Uint8Array | string) {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

async function createGoogleAccessToken(serviceAccount: Record<string, string>) {
  const pem = serviceAccount.private_key
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replaceAll(/\s/g, '');
  const privateKey = Uint8Array.from(
    atob(pem),
    (character) => character.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    'pkcs8',
    privateKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const now = Math.floor(Date.now() / 1000);
  const tokenUri = serviceAccount.token_uri || 'https://oauth2.googleapis.com/token';
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claim}`;
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetch(tokenUri, {
    signal: AbortSignal.timeout(10000),
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || !result.access_token) {
    throw new Error('Firebase-toegang kon niet worden aangemaakt.');
  }
  return String(result.access_token);
}

const escape=(s:string)=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
async function sendMail(to:string,title:string,copy:string,staff:boolean,eventId:string,en:boolean){
 const config=JSON.parse(Deno.env.get('SUPPORT_SMTP_JSON')||'{}');
 if(!config.host||!config.user||!config.password||!config.from)throw new Error('MAIL_NOT_CONFIGURED');
 const transport=nodemailer.createTransport({host:config.host,port:Number(config.port||465),secure:Number(config.port||465)===465,requireTLS:true,disableFileAccess:true,disableUrlAccess:true,auth:{user:config.user,pass:config.password},tls:{rejectUnauthorized:true},connectionTimeout:10000,socketTimeout:15000});
 const link=staff?'https://ronaldb03.github.io/paskluis/':'https://ronaldb03.github.io/paskluis/support.html';
 await transport.sendMail({from:{name:'PasKluis',address:config.from},to,subject:title,
  messageId:`<paskluis-notification-${eventId}@${String(config.from).split('@')[1]}>`,
  text:`${copy}\n\n${link}\n\nTeam PasKluis`,
  html:`<!doctype html><html><body style="margin:0;background:#f5f3f6;font-family:Arial,sans-serif;color:#26242b"><table role="presentation" style="max-width:560px;width:100%;margin:32px auto;background:white;border-radius:24px"><tr><td style="padding:32px"><div style="font-weight:900;color:#d51b46;font-size:26px">PasKluis</div><h1 style="font-size:24px;margin-top:28px">${escape(title)}</h1><p style="line-height:1.6">${escape(copy)}</p><a href="${link}" style="display:inline-block;padding:15px 24px;background:#d51b46;color:white;text-decoration:none;border-radius:24px;margin:16px 0">${staff?'Open beheer':en?'Open PasKluis':'Open PasKluis'}</a><p style="color:#777;font-size:13px">Team PasKluis · ${staff?'Beantwoord de vraag in het beheer.':en?'Read and reply in the app. Never share PINs by email.':'Lees en beantwoord het bericht in de app. Deel geen pincodes via e-mail.'}</p></td></tr></table></body></html>`});
 transport.close();
}
Deno.serve(async request=>{
 // Only our scheduled worker or server-side notification entry point can claim jobs.
 const secret=Deno.env.get('NOTIFICATION_WORKER_SECRET');
 if(!secret||request.headers.get('x-job-secret')!==secret)return Response.json({error:'UNAUTHORIZED'},{status:401});
 if(request.method!=='POST')return new Response('',{status:405});
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 const claimed=await admin.rpc('claim_notification_jobs');
 if(claimed.error)return Response.json({error:'QUEUE_UNAVAILABLE'},{status:500});
 let completed=0;let googleAccess:string|undefined;
 const firebase=JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')||'{}');
 for(const job of claimed.data||[]){
  let pushDone=job.push_done,emailDone=job.email_done;
  try{
   let guestHash:string|null=null;
   let title='PasKluis',copy='',email='',locale='nl',staff=job.event_type==='support_question';
   if(job.event_type==='card_shared'){
    const membership=await admin.from('card_share_members').select('revoked_at,removed_by_recipient_at').eq('id',job.membership_id).maybeSingle();
    if(!membership.data||membership.data.revoked_at||membership.data.removed_by_recipient_at){pushDone=true;emailDone=true;}
   }else{
    const thread=await admin.from('support_threads').select('user_id,guest_email,guest_token_hash,locale').eq('id',job.thread_id).maybeSingle();
    if(!thread.data){pushDone=true;emailDone=true;}
    else{email=thread.data.guest_email||'';locale=thread.data.locale||'nl';guestHash=thread.data.guest_token_hash;}
   }
   if(job.recipient_id){const profile=await admin.from('profiles').select('email').eq('id',job.recipient_id).maybeSingle();email=profile.data?.email||email;}
   const en=locale==='en';
   if(staff){title='Nieuwe klantvraag in PasKluis';copy='Er staat een nieuwe vraag of reactie klaar. We streven naar een persoonlijk antwoord binnen 12 uur. Open het beheer om te antwoorden.';email=Deno.env.get('SUPPORT_INBOX_EMAIL')||'info@paskluis.nl';pushDone=true;}
   else if(job.event_type==='card_shared'){title=en?'New card in PasKluis':'Nieuwe kaart in PasKluis';copy=en?'A card has been shared with you. Open PasKluis to view it.':'Er is een kaart met je gedeeld. Open PasKluis om de kaart te bekijken.';emailDone=true;}
   else {title=en?'A reply from PasKluis':'Antwoord van PasKluis';copy=en?'We have replied to your question. Read and reply in Customer support in the app.':'We hebben je vraag beantwoord. Lees en beantwoord het bericht bij Klantenservice in de app.';}
   let pushError:unknown=null;
   try{if(!pushDone){
    if(!job.recipient_id&&!guestHash){pushDone=true;}
    else{
     const active=job.recipient_id?await admin.from('account_device_sessions').select('device_id').eq('user_id',job.recipient_id).maybeSingle():{data:null};
     let devices=active.data?(await admin.from('push_device_tokens').select('id,token,locale').eq('user_id',job.recipient_id).eq('device_id',active.data.device_id)).data||[]:[];
     if(guestHash){const guest=await admin.from('guest_support_push_tokens').select('token,locale').eq('guest_token_hash',guestHash).maybeSingle();if(guest.data)devices=[{id:'guest',...guest.data}];}
     if(devices.length===0){if(job.event_type==='card_shared')throw new Error('NO_REGISTERED_DEVICE');pushDone=true;}
     else{
      googleAccess??=await createGoogleAccessToken(firebase);
      let accepted=0;
      for(const device of devices){
       const deviceEn=device.locale==='en';
       const shared=job.event_type==='card_shared';
       const notification=shared?{title:deviceEn?'New card in PasKluis':'Nieuwe kaart in PasKluis',body:deviceEn?'A card has been shared with you.':'Er is een kaart met je gedeeld.'}:{title:deviceEn?'A reply from PasKluis':'Antwoord van PasKluis',body:deviceEn?'Your reply is ready in Customer support.':'Je antwoord staat klaar bij Klantenservice.'};
       const result=await fetch(`https://fcm.googleapis.com/v1/projects/${firebase.project_id}/messages:send`,{method:'POST',signal:AbortSignal.timeout(10000),headers:{Authorization:`Bearer ${googleAccess}`,'Content-Type':'application/json'},body:JSON.stringify({message:{token:device.token,notification,data:{event:shared?'shared_card':'support_reply',...(shared?{membership_id:job.membership_id}:{thread_id:job.thread_id})},android:{priority:'high',notification:{channel_id:shared?'shared_cards':'support_replies',tag:`paskluis-${job.id}`,sound:'default'}},apns:{headers:{'apns-collapse-id':`paskluis-${job.id}`},payload:{aps:{sound:'default'}}}}})});
       if(!result.ok){const error=await result.text();if(error.includes('UNREGISTERED')){if(device.id==='guest'){await admin.from('guest_support_push_tokens').delete().eq('guest_token_hash',guestHash);}else{await admin.from('push_device_tokens').delete().eq('id',device.id);}}else throw new Error(`PUSH_${result.status}`);}else accepted++;
      }
      if(accepted===0&&job.event_type==='card_shared')throw new Error('NO_REGISTERED_DEVICE');
      pushDone=true;
     }
    }
   }}catch(error){pushError=error;}
   // Persist channel completion before a potentially unavailable mail provider.
   await admin.from('notification_outbox').update({push_done:pushDone}).eq('id',job.id);
   if(!emailDone){if(email)await sendMail(email,title,copy,staff,String(job.id),en);emailDone=true;}
   // A push-provider failure must not suppress an otherwise deliverable email.
   if(pushError)throw pushError;
   await admin.from('notification_outbox').update({push_done:pushDone,email_done:emailDone,delivered_at:new Date().toISOString(),locked_until:null,last_error:null}).eq('id',job.id);
   completed++;
  }catch(error){const reason=error instanceof Error&&/^(MAIL_NOT_CONFIGURED|NO_REGISTERED_DEVICE|PUSH_\d+)$/.test(error.message)?error.message:'DELIVERY_FAILED';await admin.from('notification_outbox').update({push_done:pushDone,email_done:emailDone,locked_until:null,last_error:reason,available_at:new Date(Date.now()+Math.min(3600,30*2**job.attempts)*1000).toISOString()}).eq('id',job.id);}
 }
 return Response.json({processed:claimed.data?.length||0,completed});
});
