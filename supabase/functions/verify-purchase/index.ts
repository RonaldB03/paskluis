import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {SignJWT,importPKCS8,decodeJwt} from 'https://esm.sh/jose@5.9.6';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info'};
const PRODUCT='paskluis_plus', PACKAGE='nl.paskluis.app';
async function apple(transactionId:string,userId:string,diagnostic:Diagnostic){
 diagnostic.stage='apple_configuration';
 const cfg=JSON.parse(Deno.env.get('APPLE_IAP_KEY_JSON')||'{}');
 if(!cfg.privateKey||!cfg.keyId||!cfg.issuerId)throw new Error('STORE_NOT_CONFIGURED');
 diagnostic.stage='apple_signing';
 const key=await importPKCS8(cfg.privateKey,'ES256');
 const jwt=await new SignJWT({bid:PACKAGE}).setProtectedHeader({alg:'ES256',kid:cfg.keyId,typ:'JWT'}).setIssuer(cfg.issuerId).setAudience('appstoreconnect-v1').setIssuedAt().setExpirationTime('5m').sign(key);
 let environment='production';
 diagnostic.stage='apple_production_lookup';
 let response=await fetch(`https://api.storekit.itunes.apple.com/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,{headers:{Authorization:`Bearer ${jwt}`}});
 // Some apps not yet released return 401 from production even for sandbox purchases.
 // A fallback is only a second authenticated lookup: all identity checks below remain mandatory.
 if([401,404].includes(response.status)&&Deno.env.get('ALLOW_SANDBOX_PURCHASES')==='true'){
  environment='sandbox';
  diagnostic.stage='apple_sandbox_lookup';
  response=await fetch(`https://api.storekit-sandbox.itunes.apple.com/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,{headers:{Authorization:`Bearer ${jwt}`}});
 }
 if(!response.ok){
  diagnostic.status=response.status;
  const failure=await response.json().catch(()=>null);
  if(Number.isSafeInteger(failure?.errorCode))diagnostic.storeCode=failure.errorCode;
  throw new Error('STORE_VERIFICATION_FAILED');
 }
 diagnostic.stage='apple_transaction_payload';
 const result=await response.json();
 // Decode only the transaction obtained directly from Apple's authenticated HTTPS API.
 // Client-supplied signed data is never trusted or decoded here.
 const tx=decodeJwt(result.signedTransactionInfo);
 diagnostic.stage='apple_account_product_check';
 if(tx.bundleId!==PACKAGE||tx.productId!==PRODUCT||tx.type!=='Non-Consumable'||tx.appAccountToken!==userId)throw new Error('PURCHASE_ACCOUNT_MISMATCH');
 if(tx.inAppOwnershipType==='FAMILY_SHARED')throw new Error('PURCHASE_ACCOUNT_MISMATCH');
 diagnostic.stage='apple_environment_check';
 if((tx.environment==='Sandbox')!==(environment==='sandbox'))throw new Error('INVALID_ENVIRONMENT');
 return {id:String(tx.originalTransactionId||tx.transactionId),environment,revoked:!!tx.revocationDate};
}
type Diagnostic={stage:string;status?:number;storeCode?:number};
async function google(purchaseToken:string,userId:string,diagnostic:Diagnostic){
 diagnostic.stage='google_configuration';
 const cfg=JSON.parse(Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON')||'{}');
 if(!cfg.private_key||!cfg.client_email)throw new Error('STORE_NOT_CONFIGURED');
 diagnostic.stage='google_signing';
 const key=await importPKCS8(cfg.private_key,'RS256');
 const assertion=await new SignJWT({scope:'https://www.googleapis.com/auth/androidpublisher'}).setProtectedHeader({alg:'RS256',typ:'JWT'}).setIssuer(cfg.client_email).setAudience('https://oauth2.googleapis.com/token').setIssuedAt().setExpirationTime('5m').sign(key);
 diagnostic.stage='google_oauth';
 const auth=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})});
 if(!auth.ok){diagnostic.status=auth.status;throw new Error('STORE_VERIFICATION_FAILED');}
 const {access_token}=await auth.json();
 diagnostic.stage='google_purchase_lookup';
 const response=await fetch(`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/productsv2/tokens/${encodeURIComponent(purchaseToken)}`,{headers:{Authorization:`Bearer ${access_token}`}});
 if(!response.ok){diagnostic.status=response.status;throw new Error('STORE_VERIFICATION_FAILED');}
 diagnostic.stage='google_purchase_payload';
 const tx=await response.json();
 diagnostic.stage='google_account_product_check';
 if(tx.obfuscatedExternalAccountId!==userId||!tx.productLineItem?.some(p=>p.productId===PRODUCT))throw new Error('PURCHASE_ACCOUNT_MISMATCH');
 diagnostic.stage='google_environment_check';
 const environment=tx.testPurchaseContext?'sandbox':'production';
 if(environment==='sandbox'&&Deno.env.get('ALLOW_SANDBOX_PURCHASES')!=='true')throw new Error('TEST_PURCHASE_NOT_ALLOWED');
 diagnostic.stage='google_purchase_state';
 const state=tx.purchaseStateContext?.purchaseState;
 if(state!=='PURCHASED'&&state!=='CANCELLED')throw new Error('PURCHASE_PENDING');
 // Hash the token before persistence. It never appears in logs or staff views.
 const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(purchaseToken));
 const id=Array.from(new Uint8Array(digest)).map(b=>b.toString(16).padStart(2,'0')).join('');
 return {id,environment,revoked:state==='CANCELLED'};
}
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(request.method!=='POST')return Response.json({error:'METHOD_NOT_ALLOWED'},{status:405,headers:cors});
 const diagnostic:Diagnostic={stage:'authentication'};
 try{
  const url=Deno.env.get('SUPABASE_URL')!;
  const caller=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:request.headers.get('Authorization')||''}},auth:{persistSession:false}});
  const {data:{user},error}=await caller.auth.getUser();
  if(error||!user)return Response.json({error:'SIGN_IN_REQUIRED'},{status:401,headers:cors});
  const active=await caller.rpc('has_active_device_session');
  if(active.data!==true)return Response.json({error:'SESSION_REPLACED'},{status:403,headers:cors});
  diagnostic.stage='request_validation';
  const body=await request.json();
  if(body.productId!==PRODUCT||!['apple','google'].includes(body.platform)||typeof body.proof!=='string'||body.proof.length>12000)throw new Error('INVALID_PURCHASE');
  diagnostic.stage='apple_verification';
  const verified=body.platform==='apple'?await apple(body.proof,user.id,diagnostic):await google(body.proof,user.id,diagnostic);
  diagnostic.stage='purchase_persistence';
  const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const saved=await admin.rpc('record_verified_purchase',{p_user_id:user.id,p_platform:body.platform,p_transaction_id:verified.id,p_environment:verified.environment,p_revoked:verified.revoked});
  if(saved.error)throw new Error(saved.error.message.includes('PURCHASE_LINKED')?'PURCHASE_LINKED_TO_ANOTHER_ACCOUNT':'PURCHASE_SAVE_FAILED');
  return Response.json({verified:saved.data===true},{headers:cors});
 }catch(error){const allowed=['STORE_NOT_CONFIGURED','PURCHASE_PENDING','PURCHASE_ACCOUNT_MISMATCH','PURCHASE_LINKED_TO_ANOTHER_ACCOUNT','TEST_PURCHASE_NOT_ALLOWED'];const code=error instanceof Error&&allowed.includes(error.message)?error.message:'PURCHASE_VERIFICATION_FAILED';
 // Only fixed stage names, HTTP status and allowlisted error codes; never log proofs, keys or user data.
 console.error(JSON.stringify({event:'purchase_verification_failed',stage:diagnostic.stage,status:diagnostic.status,storeCode:diagnostic.storeCode,code}));
 return Response.json({error:code},{status:400,headers:cors});}
});
