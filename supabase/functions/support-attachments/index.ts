import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info'};
const MAX_BYTES=5*1024*1024;
async function readBody(request:Request){
 const limit=Math.ceil(MAX_BYTES/3)*4+4096;
 if(Number(request.headers.get('content-length')||0)>limit||!request.body)throw new Error('TOO_LARGE');
 const reader=request.body.getReader(),chunks:Uint8Array[]=[];let size=0;
 try{
  while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;
   if(size>limit){await reader.cancel();throw new Error('TOO_LARGE');}chunks.push(value);
  }
 }finally{reader.releaseLock();}
 const all=new Uint8Array(size);let offset=0;
 for(const chunk of chunks){all.set(chunk,offset);offset+=chunk.byteLength;}
 return JSON.parse(new TextDecoder().decode(all));
}
function imageType(b:Uint8Array){
 if(b.length>8&&b[0]===0xff&&b[1]===0xd8&&b[2]===0xff)return 'image/jpeg';
 if(b.length>8&&b[0]===0x89&&String.fromCharCode(...b.slice(1,8))==='PNG\r\n\x1a\n')return 'image/png';
 if(b.length>12&&String.fromCharCode(...b.slice(0,4))==='RIFF'&&String.fromCharCode(...b.slice(8,12))==='WEBP')return 'image/webp';
 throw new Error('INVALID_IMAGE');
}
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(request.method!=='POST')return new Response('',{status:405,headers:cors});
 try{
  const body=await readBody(request),id=String(body.thread_id||'');
  if(!/^[0-9a-f-]{36}$/i.test(id))throw new Error('ACCESS_DENIED');
  const url=Deno.env.get('SUPABASE_URL')!;
  const caller=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:request.headers.get('Authorization')||''}},auth:{persistSession:false}});
  const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const auth=await caller.auth.getUser();const user=auth.data.user;
  const thread=(await admin.from('support_threads').select('id,user_id,guest_token_hash,status,locale').eq('id',id).maybeSingle()).data;
  if(!thread)throw new Error('ACCESS_DENIED');
  const profile=user?(await admin.from('profiles').select('role').eq('id',user.id).maybeSingle()).data:null;
  const staff=profile&&['support','admin'].includes(profile.role);
  let guest=false;
  if(!thread.user_id&&typeof body.guest_token==='string'&&body.guest_token.length>=32&&body.guest_token.length<=256){
   const hash=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(body.guest_token));
   guest=Array.from(new Uint8Array(hash)).map(b=>b.toString(16).padStart(2,'0')).join('')===thread.guest_token_hash;
  }
  if(!staff&&!guest&&(!user||thread.user_id!==user.id))throw new Error('ACCESS_DENIED');
  if(!staff&&!guest){const active=await caller.rpc('has_active_device_session');if(active.data!==true)throw new Error('ACCESS_DENIED');}
  if(body.action==='list'){
   const rows=await admin.from('support_attachments').select('id,message_id,storage_path').eq('thread_id',id).order('created_at').limit(100);
   if(rows.error)throw new Error('UNAVAILABLE');
   const attachments=[];
   for(const row of rows.data){
    const signed=await admin.storage.from('support-attachments').createSignedUrl(row.storage_path,300);
    if(signed.data)attachments.push({id:row.id,message_id:row.message_id,url:signed.data.signedUrl});
   }
   return Response.json({attachments},{headers:cors});
  }
  if(body.action!=='upload'||thread.status==='closed'||typeof body.image!=='string'||body.image.length>Math.ceil(MAX_BYTES/3)*4)throw new Error('INVALID_IMAGE');
  const count=await admin.from('support_attachments').select('id',{head:true,count:'exact'}).eq('thread_id',id).gte('created_at',new Date(Date.now()-86400000).toISOString());
  if(count.error||(count.count||0)>=6)throw new Error('UPLOAD_LIMIT');
  const binary=atob(body.image);if(binary.length>MAX_BYTES)throw new Error('TOO_LARGE');
  const bytes=Uint8Array.from(binary,c=>c.charCodeAt(0)),mime=imageType(bytes);
  const path=`${id}/${crypto.randomUUID()}.${mime==='image/jpeg'?'jpg':mime==='image/png'?'png':'webp'}`;
  const uploaded=await admin.storage.from('support-attachments').upload(path,bytes,{contentType:mime,upsert:false});
  if(uploaded.error)throw new Error('UPLOAD_FAILED');
  try{
   const text=thread.locale==='en'?'Screenshot attached':'Screenshot bijgevoegd';
   let messageId:string;
   if(guest){
    const sent=await admin.rpc('guest_support_attachment_message',{p_token:body.guest_token,p_thread_id:id});
    if(sent.error)throw new Error('MESSAGE_FAILED');
    // Guest RPC returns the inserted message ID.
    messageId=String(sent.data);
   }else{
    const sent=await caller.from('support_messages').insert({thread_id:id,sender_id:user!.id,message:text}).select('id').single();
    if(sent.error)throw new Error('MESSAGE_FAILED');messageId=sent.data.id;
   }
   const record=await admin.from('support_attachments').insert({thread_id:id,message_id:messageId,storage_path:path,mime_type:mime,size_bytes:bytes.length});
   if(record.error)throw new Error('RECORD_FAILED');
  }catch(error){await admin.storage.from('support-attachments').remove([path]);throw error;}
  return Response.json({uploaded:true},{headers:cors});
 }catch(error){const code=error instanceof Error&&['UPLOAD_LIMIT','TOO_LARGE','INVALID_IMAGE','ACCESS_DENIED'].includes(error.message)?error.message:'ATTACHMENT_UNAVAILABLE';return Response.json({error:code},{status:400,headers:cors});}
});
