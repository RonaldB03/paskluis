import http from 'node:http';
import {readFileSync} from 'node:fs';
import {SignedDataVerifier,Environment} from '@apple/app-store-server-library';
const roots=JSON.parse(readFileSync(new URL('./apple-roots.json',import.meta.url),'utf8')).map(value=>Buffer.from(value,'base64'));
const production=new SignedDataVerifier(roots,true,Environment.PRODUCTION,'nl.paskluis.app',6764876159);
const sandbox=new SignedDataVerifier(roots,true,Environment.SANDBOX,'nl.paskluis.app');
// Private Docker network only; no host port, store credentials or database keys.
http.createServer({requestTimeout:20000,headersTimeout:10000},async(req,res)=>{
 const reply=(status,body)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(body));};
 if(req.method!=='POST'||req.url!=='/verify')return reply(404,{error:'NOT_FOUND'});
 try {
  let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>24000)return reply(413,{error:'TOO_LARGE'});}
  const body=JSON.parse(raw);
  if(typeof body.proof!=='string'||body.proof.length>20000)return reply(400,{error:'INVALID_PROOF'});
  let tx;
  try{tx=await production.verifyAndDecodeTransaction(body.proof);}
  catch(error){if(body.allowSandbox!==true)throw error;tx=await sandbox.verifyAndDecodeTransaction(body.proof);}
  if(tx.productId!=='paskluis_plus'||tx.type!=='Non-Consumable'||tx.inAppOwnershipType==='FAMILY_SHARED'||!tx.transactionId)throw new Error('INVALID_PRODUCT');
  reply(200,{transactionId:tx.transactionId,originalTransactionId:tx.originalTransactionId,appAccountToken:tx.appAccountToken,environment:tx.environment});
 }catch(error){console.error(JSON.stringify({event:'apple_proof_rejected',status:Number.isInteger(error?.status)?error.status:null}));reply(400,{error:'INVALID_PROOF'});}
}).listen(8080,'0.0.0.0');
