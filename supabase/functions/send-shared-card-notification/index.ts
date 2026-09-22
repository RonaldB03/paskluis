import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info'};
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(request.method!=='POST')return new Response('',{status:405,headers:cors});
 try{
  const url=Deno.env.get('SUPABASE_URL')!;
  const caller=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:request.headers.get('Authorization')||''}},auth:{persistSession:false}});
  const {data:{user},error}=await caller.auth.getUser();
  if(error||!user)return Response.json({error:'SIGN_IN_REQUIRED'},{status:401,headers:cors});
  const active=await caller.rpc('has_active_device_session');
  if(active.data!==true)return Response.json({error:'SESSION_REPLACED'},{status:403,headers:cors});
  const payload=await request.json();
  const member=await caller.from('card_share_members').select('shared_card_id,revoked_at,removed_by_recipient_at').eq('id',String(payload.membership_id||'')).maybeSingle();
  if(!member.data||member.data.revoked_at||member.data.removed_by_recipient_at)throw new Error('ACCESS_DENIED');
  const card=await caller.from('shared_cards').select('owner_id').eq('id',member.data.shared_card_id).maybeSingle();
  if(card.data?.owner_id!==user.id)throw new Error('ACCESS_DENIED');
  // The database transition creates one delivery job. Repeated client calls
  // cannot create duplicate notifications; the scheduled worker retries safely.
  return Response.json({queued:true},{headers:cors});
 }catch(_){return Response.json({error:'NOTIFICATION_UNAVAILABLE'},{status:400,headers:cors});}
});
