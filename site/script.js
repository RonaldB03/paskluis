const screens={
  loyalty:{src:'assets/loyalty.png',alt:'Klantenkaarten in PasKluis'},
  giftcards:{src:'assets/giftcards.png',alt:'Cadeaukaarten in PasKluis'},
  qr:{src:'assets/qr.png',alt:'QR-codes in PasKluis'}
};
document.querySelectorAll('[data-screen]').forEach(button=>button.addEventListener('click',()=>{
  const image=document.querySelector('#screen-image');
  document.querySelectorAll('[data-screen]').forEach(item=>item.classList.toggle('active',item===button));
  image.parentElement.classList.add('swap');
  setTimeout(()=>{image.src=screens[button.dataset.screen].src;image.alt=screens[button.dataset.screen].alt;image.parentElement.classList.remove('swap')},180);
}));
const header=document.querySelector('.site-header');
document.querySelector('.menu-toggle').addEventListener('click',event=>{
  const open=header.classList.toggle('open');
  event.currentTarget.setAttribute('aria-expanded',String(open));
});
document.querySelectorAll('#nav a').forEach(link=>link.addEventListener('click',()=>{
  header.classList.remove('open');
  document.querySelector('.menu-toggle').setAttribute('aria-expanded','false');
}));

const CMS_URL='https://ajldblvvlbvmgejrmhyj.supabase.co/rest/v1/rpc/get_published_content';
const CMS_KEY='sb_publishable_D22GtKy7nDvnLv7LeBL1SA_1_ZGbN7d';
function valueAt(object,path){return path.split('.').reduce((value,key)=>value?.[key],object)}
async function loadPublishedContent(){
  try{
    const response=await fetch(CMS_URL,{method:'POST',headers:{apikey:CMS_KEY,'Content-Type':'application/json'},body:JSON.stringify({p_key:'site.home'})});
    if(!response.ok)throw new Error('CONTENT_UNAVAILABLE');
    const payload=await response.json();const content=payload?.content;
    if(!content||typeof content!=='object')return;
    document.querySelectorAll('[data-cms]').forEach(node=>{
      const value=valueAt(content,node.dataset.cms);
      if(typeof value==='string'&&value.trim())node.textContent=value;
    });
    document.querySelectorAll('.feature-card').forEach((card,index)=>{
      const feature=content.features?.[index];if(!feature)return;
      if(typeof feature.title==='string')card.querySelector('h3').textContent=feature.title;
      if(typeof feature.body==='string')card.querySelector('p').textContent=feature.body;
    });
    const images=content.images||{};
    for(const [selector,url] of Object.entries(images)){
      if(typeof url!=='string'||!url.startsWith('https://'))continue;
      const image=document.querySelector(`[data-cms-image="${CSS.escape(selector)}"]`);if(image)image.src=url;
    }
  }catch(_){/* De ingebouwde inhoud blijft beschikbaar wanneer de CMS-service offline is. */}
}
loadPublishedContent();
