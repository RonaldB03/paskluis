import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.117.2';
import {apple,google,type Diagnostic} from './providers.ts';

const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info'};

Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(request.method!=='POST')return Response.json({error:'METHOD_NOT_ALLOWED'},{status:405,headers:cors});
 const diagnostic:Diagnostic={stage:'request_validation'};
 try {
  const text=await request.text();
  if(text.length>24000)throw new Error('INVALID_PURCHASE');
  const body=JSON.parse(text);
  if(body.productId!=='paskluis_plus'||!['apple','google'].includes(body.platform)||typeof body.proof!=='string'||body.proof.length<20||body.proof.length>20000||typeof body.linkAccount!=='boolean')throw new Error('INVALID_PURCHASE');
  const url=Deno.env.get('SUPABASE_URL')!;
  let userId:string|null=null;
  if(body.linkAccount){
   const caller=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:request.headers.get('Authorization')||''}},auth:{persistSession:false}});
   const {data:{user},error}=await caller.auth.getUser();
   if(error||!user)return Response.json({error:'SIGN_IN_REQUIRED'},{status:401,headers:cors});
   const active=await caller.rpc('has_active_device_session');
   if(active.data!==true)return Response.json({error:'SESSION_REPLACED'},{status:403,headers:cors});
   userId=user.id;
  }
  let verified;
  if(body.platform==='apple'){
   diagnostic.stage='apple_signed_proof';
   // Transaction IDs alone are not proof of ownership. Verify Apple's certificate
   // chain and JWS signature before any lookup or access grant.
   const checked=await fetch('http://store-verifier:8080/verify',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({proof:body.proof,allowSandbox:Deno.env.get('ALLOW_SANDBOX_PURCHASES')==='true'}),signal:AbortSignal.timeout(20000)});
   if(!checked.ok)throw new Error('INVALID_PURCHASE');
   const tx=await checked.json();
   verified=await apple(tx.transactionId,tx.appAccountToken,diagnostic);
   // The signed proof may predate a refund. The fresh authenticated lookup wins.
   if(verified.id!==String(tx.originalTransactionId||tx.transactionId)||(verified.environment==='sandbox')!==(tx.environment==='Sandbox'))throw new Error('INVALID_PURCHASE');
  }else{
   // Google's unguessable token is the receipt; all state comes from Google.
   verified=await google(body.proof,undefined,diagnostic);
  }
  diagnostic.stage='purchase_persistence';
  const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const saved=await admin.rpc('record_store_purchase_v2',{
   p_user_id:userId,p_platform:body.platform,p_transaction_id:verified.id,
   p_environment:verified.environment,p_revoked:verified.revoked,p_store_account_token:verified.accountToken||null,
  });
  if(saved.error)throw new Error(saved.error.message.includes('PURCHASE_LINKED')?'PURCHASE_LINKED_TO_ANOTHER_ACCOUNT':'PURCHASE_SAVE_FAILED');
  return Response.json({verified:true,...saved.data},{headers:cors});
 }catch(error){
  const message=error instanceof Error?error.message:'';
  const code=['PURCHASE_PENDING','PURCHASE_LINKED_TO_ANOTHER_ACCOUNT','TEST_PURCHASE_NOT_ALLOWED'].includes(message)?message:'PURCHASE_VERIFICATION_FAILED';
  console.error(JSON.stringify({event:'store_verification_failed',stage:diagnostic.stage,status:diagnostic.status,code}));
  return Response.json({error:code},{status:400,headers:cors});
 }
});
