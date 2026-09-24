export const LIMIT=10_000_000;
export const MAX_OBJECTS=301;
export function unbase64(value:string):Uint8Array {
 if(typeof value!=='string'||value.length>15_000_000)throw Error('INVALID_BACKUP');
 return Uint8Array.from(atob(value),c=>c.charCodeAt(0));
}
export function base64(bytes:Uint8Array):string {
 let s='';for(let i=0;i<bytes.length;i+=8192)s+=String.fromCharCode(...bytes.subarray(i,i+8192));return btoa(s);
}
export async function hash(bytes:Uint8Array):Promise<string>{
 return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(x=>x.toString(16).padStart(2,'0')).join('');
}
export async function openObject(key:CryptoKey,user:string,id:string,data:Uint8Array):Promise<Uint8Array>{
 if(!/^[a-f0-9]{64}$/.test(id)||data.length<29||data.length>LIMIT)throw Error('INVALID_BACKUP');
 const plain=new Uint8Array(await crypto.subtle.decrypt({name:'AES-GCM',iv:data.subarray(0,12),additionalData:new TextEncoder().encode(`paskluis-backup-v1:${user}:${id}`)},key,data.subarray(12)));
 if(await hash(plain)!==id)throw Error('INVALID_BACKUP');return plain;
}
export function validateManifest(m:any,ids:Set<string>):number {
 if(m?.schema!==1||!Array.isArray(m.cards)||m.cards.length>5000)throw Error('INVALID_BACKUP');
 const seen=new Set();
 for(const c of m.cards){
  if(!c||typeof c.id!=='string'||!c.id||seen.has(c.id)||c.isShared===true||c.isShared==='true')throw Error('INVALID_BACKUP');
  seen.add(c.id);
  if(c.customImage&&!ids.has(c.customImage))throw Error('INVALID_BACKUP');
 }
 return m.cards.length;
}
