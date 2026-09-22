import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info'};
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(request.method!=='POST')return Response.json({error:'METHOD_NOT_ALLOWED'},{status:405,headers:cors});
 try {
  const url=Deno.env.get('SUPABASE_URL')!;
  const caller=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:request.headers.get('Authorization')||''}},auth:{persistSession:false}});
  const {data:{user},error}=await caller.auth.getUser();
  if(error||!user?.email)return Response.json({error:'SIGN_IN_REQUIRED'},{status:401,headers:cors});
  const body=await request.json();
  if(body.confirm!=='DELETE_MY_ACCOUNT'||typeof body.password!=='string'||body.password.length>1024)return Response.json({error:'CONFIRMATION_REQUIRED'},{status:400,headers:cors});
  // Verify the password through Auth; never read or compare password hashes ourselves.
  const verifier=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const check=await verifier.auth.signInWithPassword({email:user.email,password:body.password});
  if(check.error||check.data.user?.id!==user.id)return Response.json({error:'PASSWORD_NOT_ACCEPTED'},{status:403,headers:cors});
  await verifier.auth.signOut({scope:'local'});
  const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const profile=await admin.from('profiles').select('role').eq('id',user.id).single();
  if(profile.error)throw new Error('PROFILE_UNAVAILABLE');
  if(profile.data.role!=='user')return Response.json({error:'STAFF_ROLE_MUST_BE_REMOVED_FIRST'},{status:409,headers:cors});
  // Remove private support files before their database references are cascaded.
  const ownThreads=await admin.from('support_threads').select('id').eq('user_id',user.id);
  const guestThreads=await admin.from('support_threads').select('id').is('user_id',null).eq('guest_email',user.email.toLowerCase());
  if(ownThreads.error||guestThreads.error)throw new Error('ATTACHMENT_LOOKUP_FAILED');
  const threadIds=[...ownThreads.data,...guestThreads.data].map(t=>t.id);
  for(const threadId of threadIds){
   let offset=0;
   while(true){
    const files=await admin.from('support_attachments').select('storage_path').eq('thread_id',threadId).range(offset,offset+99);
    if(files.error)throw new Error('ATTACHMENT_LOOKUP_FAILED');
    if(!files.data.length)break;
    const removed=await admin.storage.from('support-attachments').remove(files.data.map(f=>f.storage_path));
    if(removed.error)throw new Error('ATTACHMENT_CLEANUP_FAILED');offset+=100;
   }
  }
  const cleanup=await admin.rpc('prepare_account_deletion',{p_user_id:user.id});
  if(cleanup.error)throw new Error('CLEANUP_FAILED');
  const deleted=await admin.auth.admin.deleteUser(user.id);
  if(deleted.error)throw new Error('DELETE_FAILED');
  return Response.json({deleted:true},{headers:cors});
 }catch(_){return Response.json({error:'ACCOUNT_DELETION_FAILED'},{status:500,headers:cors});}
});
