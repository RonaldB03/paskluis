import {test} from 'node:test';
import assert from 'node:assert/strict';
import {openObject,hash,validateManifest,LIMIT} from '../functions/card-backups/protocol.ts';
test('AES GCM binds backup object to authenticated account and content digest',async()=>{
 const key=await crypto.subtle.generateKey({name:'AES-GCM',length:256},true,['encrypt','decrypt']);
 const plain=new TextEncoder().encode('00001:pin=0023');const id=await hash(plain);const iv=crypto.getRandomValues(new Uint8Array(12));
 const encrypted=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:new TextEncoder().encode(`paskluis-backup-v1:a:${id}`)},key,plain);
 const data=new Uint8Array([...iv,...new Uint8Array(encrypted)]);
 assert.deepEqual(await openObject(key,'a',id,data),plain);
 await assert.rejects(()=>openObject(key,'b',id,data));
 data[15]^=1;await assert.rejects(()=>openObject(key,'a',id,data));
});
test('manifest cannot restore received sharing permissions, duplicate IDs or missing images',()=>{
 assert.equal(validateManifest({schema:1,cards:[{id:'1',code:'0001',customImage:'image'}]},new Set(['image'])),1);
 for(const cards of [[{id:'1',isShared:true}],[{id:'1'},{id:'1'}],[{id:'1',customImage:'missing'}]])assert.throws(()=>validateManifest({schema:1,cards},new Set()));
 assert.equal(LIMIT,10000000);
});
