import subprocess,os,json,urllib.request,urllib.error,base64,time
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
from cryptography.hazmat.primitives import hashes
os.chdir('/opt/paskluis-supabase')
def run(args):return subprocess.run(args,capture_output=True,text=True,check=True).stdout.strip()
cid=run(['docker','compose','ps','-q','functions'])
e=dict(v.split('=',1) for v in json.loads(run(['docker','inspect',cid]))[0]['Config']['Env'])
cfg=json.loads(e['APPLE_IAP_KEY_JSON']);enc=lambda b:base64.urlsafe_b64encode(b).rstrip(b'=')
payload=b'.'.join(enc(json.dumps(p).encode()) for p in [{'alg':'ES256','kid':cfg['keyId'],'typ':'JWT'},{'bid':'nl.paskluis.app','iss':cfg['issuerId'],'aud':'appstoreconnect-v1','iat':int(time.time()),'exp':int(time.time())+300}])
r,s=decode_dss_signature(load_pem_private_key(cfg['privateKey'].encode(),password=None).sign(payload,ec.ECDSA(hashes.SHA256())))
jwt=(payload+b'.'+enc(r.to_bytes(32,'big')+s.to_bytes(32,'big'))).decode()
q="select jsonb_build_object('id',transaction_id,'environment',environment) from public.store_purchases where platform='apple' order by created_at desc limit 1;"
row=json.loads(run(['docker','compose','exec','-T','db','psql','-X','-U','supabase_admin','-d','postgres','-At','-c',q]))
domain='api.storekit-sandbox.itunes.apple.com' if row['environment']=='sandbox' else 'api.storekit.itunes.apple.com'
with urllib.request.urlopen(urllib.request.Request('https://'+domain+'/inApps/v1/transactions/'+row['id'],headers={'Authorization':'Bearer '+jwt}),timeout=20) as response:proof=json.load(response)['signedTransactionInfo']
k=e['SUPABASE_ANON_KEY']
req=urllib.request.Request('https://api.paskluis.com/functions/v1/verify-store-purchase',data=json.dumps({'productId':'paskluis_plus','platform':'apple','proof':proof,'linkAccount':False}).encode(),headers={'apikey':k,'Authorization':'Bearer '+k,'Content-Type':'application/json'})
try:
 with urllib.request.urlopen(req,timeout=50) as response:
  result=json.load(response);print(json.dumps({'http':response.status,'environment':row['environment'],'verified':result.get('verified'),'active':result.get('active'),'existing_account_link_preserved':bool(result.get('linkedUserId'))}))
except urllib.error.HTTPError as ex:print('verification probe',ex.code,ex.read().decode()[:300])
p=subprocess.run(['docker','logs','--since','30s',cid],capture_output=True,text=True)
print('\n'.join(l for l in (p.stdout+p.stderr).splitlines() if 'store_verification_failed' in l))
