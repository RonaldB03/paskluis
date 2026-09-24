import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.99.3';
import {LIMIT,MAX_OBJECTS,unbase64,base64,openObject,validateManifest} from './protocol.ts';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Cache-Control':'no-store'};
const output=(body:unknown,status=200)=>Response.json(body,{status,headers:cors});
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(request.method!=='POST')return output({error:'METHOD_NOT_ALLOWED'},405);
 let admin:any,userId='',session='',lease='';
 const rpc=async(action:string,data:any={})=>{
  const r=await admin.rpc('backup_service',{p_user:userId,p_session:session,p_action:action,p_data:{...data,lease}});
  if(r.error){const code=['SESSION_REPLACED','BACKUP_BUSY','BACKUP_QUOTA'].find(c=>r.error.message.includes(c));throw Error(code||'BACKUP_FAILED');}return r.data;
 };
 try {
  const authorization=request.headers.get('Authorization')||'';
  const url=Deno.env.get('SUPABASE_URL')!;
  const caller=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}},auth:{persistSession:false}});
  const auth=await caller.auth.getUser();
  if(auth.error||!auth.data.user)return output({error:'SIGN_IN_REQUIRED'},401);
  userId=auth.data.user.id;
  // Decode only after Auth has validated this exact JWT.
  session=JSON.parse(new TextDecoder().decode(unbase64(authorization.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')))).session_id;
  if(!session)return output({error:'SIGN_IN_REQUIRED'},401);
  if(Number(request.headers.get('content-length')||0)>15_000_000)return output({error:'BACKUP_QUOTA'},413);
  const reader=request.body?.getReader();if(!reader)throw Error('INVALID_BACKUP');
  const chunks:Uint8Array[]=[];let size=0;
  while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>15_000_000){await reader.cancel();throw Error('BACKUP_QUOTA');}chunks.push(value);}
  const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}
  const body=JSON.parse(new TextDecoder().decode(bytes));
  if(!['status','upload','restore','delete'].includes(body.action))throw Error('INVALID_BACKUP');
  admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const state=await rpc('lock');
  if(!state.available)return output({available:false});
  lease=state.lease;
  const bucket=admin.storage.from('card-backups');
  const prefix=`${userId}/`;
  const path=(id:string)=>`${prefix}${state.generation}_${id}`;
  const versions=state.versions as any[];
  const known=new Map<string,number>();for(const v of versions)for(const o of v.objects)known.set(o.id,o.size);
  // Remove only unreferenced objects, under this account's exclusive lease.
  // Covers interrupted uploads and old generations after a deletion.
  const cleanup=async(keep:Set<string>)=>{
   let page=0;const remove:string[]=[];
   while(true){const r=await bucket.list(userId,{limit:100,offset:page,sortBy:{column:'name',order:'asc'}});if(r.error)throw Error('BACKUP_FAILED');
    for(const f of r.data)if(!keep.has(f.name))remove.push(prefix+f.name);
    if(r.data.length<100)break;page+=100;if(page>2000)throw Error('BACKUP_FAILED');}
   for(let i=0;i<remove.length;i+=100){const r=await bucket.remove(remove.slice(i,i+100));if(r.error)throw Error('BACKUP_FAILED');}
  };
  const keepNames=(vs:any[])=>new Set<string>(vs.flatMap(v=>v.objects.map((o:any)=>`${state.generation}_${o.id}`)));
  await cleanup(keepNames(versions));
  let result:any;
  if(body.action==='status'){
   result={available:true,key:state.key,generation:state.generation,versions:versions.map(v=>({id:v.id,createdAt:v.created_at,cardCount:v.card_count})),usedBytes:[...known.values()].reduce((a,b)=>a+b,0),limitBytes:LIMIT};
  }else if(body.action==='upload'){
   if(body.generation!==state.generation)throw Error('BACKUP_CHANGED');
   if(!Array.isArray(body.objects)||body.objects.length>MAX_OBJECTS||!body.objects.length)throw Error('INVALID_BACKUP');
   const key=await crypto.subtle.importKey('raw',unbase64(state.key),{name:'AES-GCM'},false,['decrypt']);
   const objects=new Map<string,{id:string,size:number,data:Uint8Array}>();let total=0;let manifest:any;
   for(const o of body.objects){
    if(objects.has(o.id))throw Error('INVALID_BACKUP');
    const data=unbase64(o.data);total+=data.length;if(total>LIMIT)throw Error('BACKUP_QUOTA');
    const plain=await openObject(key,userId,o.id,data);
    if(o.id===body.manifest)manifest=JSON.parse(new TextDecoder().decode(plain));
    objects.set(o.id,{id:o.id,size:data.length,data});
   }
   const count=validateManifest(manifest,new Set(objects.keys()));
   if(versions[0]?.manifest===body.manifest){result={saved:true,unchanged:true};}
   else{
    const proposed=new Map<string,number>();for(const v of versions.slice(0,2))for(const o of v.objects)proposed.set(o.id,o.size);
    for(const o of objects.values())proposed.set(o.id,known.get(o.id)??o.size);
    if([...proposed.values()].reduce((a,b)=>a+b,0)>LIMIT)throw Error('BACKUP_QUOTA');
    for(const o of objects.values())if(!known.has(o.id)){
     const r=await bucket.upload(path(o.id),o.data,{contentType:'application/octet-stream',upsert:false});if(r.error)throw Error('BACKUP_FAILED');
    }
    const id=crypto.randomUUID();const descriptors=[...objects.values()].map(o=>({id:o.id,size:known.get(o.id)??o.size}));
    await rpc('commit',{id,cardCount:count,manifest:body.manifest,objects:descriptors});
    await cleanup(keepNames([{objects:descriptors},...versions.slice(0,2)]));result={saved:true};
   }
  }else if(body.action==='restore'){
   const version=versions.find(v=>v.id===body.id);if(!version)throw Error('BACKUP_NOT_FOUND');
   const objects=[];
   for(const o of version.objects){const r=await bucket.download(path(o.id));if(r.error)throw Error('BACKUP_FAILED');objects.push({id:o.id,data:base64(new Uint8Array(await r.data.arrayBuffer()))});}
   result={key:state.key,generation:state.generation,manifest:version.manifest,objects};
  }else{
   if(body.confirm!=='DELETE_BACKUPS')throw Error('INVALID_BACKUP');
   await rpc('delete');await cleanup(new Set());result={deleted:true};
  }
  await rpc('finish');lease='';return output(result);
 }catch(error){
  const text=error instanceof Error?error.message:'';
  const code=['SESSION_REPLACED','BACKUP_BUSY','BACKUP_QUOTA','BACKUP_CHANGED','BACKUP_NOT_FOUND','INVALID_BACKUP'].includes(text)?text:'BACKUP_FAILED';
  if(lease)try{await rpc('finish',{error:code});}catch{/* Lease expires; no sensitive data logged. */}
  return output({error:code},code==='SESSION_REPLACED'?403:409);
 }
});
