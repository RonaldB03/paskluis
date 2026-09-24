import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
import * as protocol from '../functions/card-backups/protocol.ts';
const source=stripTypeScriptTypes((await readFile(new URL('../functions/card-backups/index.ts',import.meta.url),'utf8')).replace(/^import .*;\n/gm,''));
function setup(){
 const key=crypto.getRandomValues(new Uint8Array(32));const files=new Map();let handler,versions=[],failUpload=false,session=true;
 const client={auth:{getUser:async()=>({data:{user:{id:'a'}}})},rpc:async(_,{p_action,p_data})=>{
  if(!session)return {error:{message:'SESSION_REPLACED'}};
  if(p_action==='lock')return {data:{available:true,key:protocol.base64(key),lease:'lease',generation:'gen',versions:structuredClone(versions)}};
  if(p_action==='commit')versions=[{id:p_data.id,manifest:p_data.manifest,card_count:p_data.cardCount,objects:p_data.objects,created_at:'2026-09-24'},...versions].slice(0,3);
  if(p_action==='delete')versions=[];
  return {data:{ok:true}};
 },storage:{from:()=>({list:async(_,{offset,limit})=>({data:[...files.keys()].sort().slice(offset,offset+limit).map(k=>({name:k.slice(2)}))}),remove:async paths=>{paths.forEach(p=>files.delete(p));return {};},upload:async(path,data)=>{if(failUpload)return {error:{message:'disk'}};files.set(path,data);return {};},download:async path=>files.has(path)?{data:new Blob([files.get(path)])}:{error:{message:'missing'}}})}};
 vm.runInNewContext(source,{...protocol,createClient:()=>client,Deno:{env:{get:()=> 'test'},serve:fn=>handler=fn},crypto,TextEncoder,TextDecoder,Uint8Array,Response,Set,Map});
 return {key,files,get versions(){return versions;},set failUpload(v){failUpload=v;},set session(v){session=v;},run:async body=>{
  const response=await handler(new Request('https://example.invalid',{method:'POST',headers:{Authorization:`Bearer a.${btoa(JSON.stringify({session_id:'session'}))}.b`},body:JSON.stringify(body)}));return {status:response.status,body:await response.json()};
 }};
}
async function object(key,data){const plain=new TextEncoder().encode(JSON.stringify(data));const id=await protocol.hash(plain);const iv=crypto.getRandomValues(new Uint8Array(12));const cryptoKey=await crypto.subtle.importKey('raw',key,{name:'AES-GCM'},false,['encrypt']);const encrypted=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:new TextEncoder().encode(`paskluis-backup-v1:a:${id}`)},cryptoKey,plain);return {id,data:protocol.base64(new Uint8Array([...iv,...new Uint8Array(encrypted)]))};}
test('function uploads encrypted cards, restores, deduplicates and deletes',async()=>{
 const s=setup();const o=await object(s.key,{schema:1,cards:[{id:'card',code:'000123',pinCode:'0002'}]});
 const upload={action:'upload',generation:'gen',manifest:o.id,objects:[o]};
 assert.equal((await s.run(upload)).status,200);assert.equal(s.versions.length,1);
 assert.equal((await s.run(upload)).body.unchanged,true);assert.equal(s.versions.length,1);
 const restore=await s.run({action:'restore',id:s.versions[0].id});assert.equal(restore.status,200);assert.equal(restore.body.objects[0].data,o.data);
 assert.equal((await s.run({action:'delete',confirm:'DELETE_BACKUPS'})).status,200);assert.equal(s.versions.length,0);assert.equal(s.files.size,0);
});
test('failed upload preserves old backup and revoked sessions cannot restore',async()=>{
 const s=setup();const o=await object(s.key,{schema:1,cards:[{id:'card',code:'old'}]});
 await s.run({action:'upload',generation:'gen',manifest:o.id,objects:[o]});const old=s.versions[0].id;
 s.failUpload=true;const newer=await object(s.key,{schema:1,cards:[{id:'card',code:'new'}]});
 assert.equal((await s.run({action:'upload',generation:'gen',manifest:newer.id,objects:[newer]})).status,409);
 assert.equal(s.versions[0].id,old);assert.equal((await s.run({action:'restore',id:old})).status,200);
 s.session=false;assert.equal((await s.run({action:'restore',id:old})).status,403);
});
