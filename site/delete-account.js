import {createClient} from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
const client=createClient('https://ajldblvvlbvmgejrmhyj.supabase.co','sb_publishable_D22GtKy7nDvnLv7LeBL1SA_1_ZGbN7d',{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
const form=document.querySelector('#delete-form'),button=document.querySelector('#delete-button'),status=document.querySelector('#status'),password=document.querySelector('#password');
form.addEventListener('submit',async event=>{
 event.preventDefault();if(!form.reportValidity())return;
 button.disabled=true;status.className='';status.textContent='Je identiteit wordt gecontroleerd…';
 try{
  const login=await client.auth.signInWithPassword({email:document.querySelector('#email').value.trim(),password:password.value});
  if(login.error)throw new Error('Inloggen is niet gelukt. Controleer je gegevens of vraag hulp via info@paskluis.nl.');
  const result=await client.functions.invoke('delete-account',{body:{confirm:'DELETE_MY_ACCOUNT',password:password.value}});
  if(result.error||result.data?.deleted!==true)throw new Error('Het verwijderen is niet afgerond. Vraag hulp via info@paskluis.nl.');
  password.value='';form.replaceChildren(Object.assign(document.createElement('p'),{textContent:'Je PasKluis-account is verwijderd. Je eigen lokale kaarten staan eventueel nog op je toestel; verwijder die daar als je dat wilt.'}));
 }catch(error){status.className='error';status.textContent=error.message;button.disabled=false;}
 finally{password.value='';await client.auth.signOut({scope:'local'}).catch(()=>{});}
});
