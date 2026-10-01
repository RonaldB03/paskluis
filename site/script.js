const screens={
  loyalty:{src:'assets/loyalty.png',alt:'Klantenkaarten in PasKluis'},
  giftcards:{src:'assets/giftcards.png',alt:'Cadeaukaarten in PasKluis'},
  qr:{src:'assets/qr.png',alt:'QR-codes in PasKluis'}
};

function activateScreen(button){
  const screen=screens[button.dataset.screen];if(!screen)return;
  const image=document.querySelector('#screen-image');
  document.querySelectorAll('[data-screen]').forEach(item=>item.classList.toggle('active',item===button));
  image.parentElement.classList.add('swap');
  setTimeout(()=>{image.src=screen.src;image.alt=screen.alt;image.parentElement.classList.remove('swap')},180);
}
document.querySelectorAll('[data-screen]').forEach(button=>button.addEventListener('click',()=>activateScreen(button)));

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
function safeUrl(value,{allowHash=true}={}){
  if(typeof value!=='string'||!value.trim())return null;
  const trimmed=value.trim();if(allowHash&&trimmed.startsWith('#'))return trimmed;
  try{const url=new URL(trimmed,window.location.href);return ['http:','https:'].includes(url.protocol)?url.href:null;}catch(_){return null;}
}
function applyContent(content){
  document.querySelectorAll('[data-cms]').forEach(node=>{
    const value=valueAt(content,node.dataset.cms);if(typeof value==='string')node.textContent=value;
  });
  document.querySelectorAll('[data-cms-href]').forEach(node=>{
    const href=safeUrl(valueAt(content,node.dataset.cmsHref));if(href)node.setAttribute('href',href);
  });
  document.querySelectorAll('[data-cms-image]').forEach(node=>{
    const imageUrl=safeUrl(valueAt(content,`images.${node.dataset.cmsImage}`),{allowHash:false});if(imageUrl)node.src=imageUrl;
  });
  document.querySelectorAll('[data-cms-alt]').forEach(node=>{
    const alt=valueAt(content,node.dataset.cmsAlt);if(typeof alt==='string')node.alt=alt;
  });
  const title=valueAt(content,'meta.title');if(typeof title==='string'&&title.trim())document.title=title;
  const description=valueAt(content,'meta.description');if(typeof description==='string')document.querySelector('meta[name="description"]')?.setAttribute('content',description);
  const imageKeys={loyalty:'loyaltyScreen',giftcards:'giftcardsScreen',qr:'qrScreen'};
  Object.entries(imageKeys).forEach(([screen,key])=>{const src=safeUrl(valueAt(content,`images.${key}`),{allowHash:false});if(src)screens[screen].src=src;});
  screens.loyalty.alt=valueAt(content,'showcase.tabs.0.label')||screens.loyalty.alt;
  screens.giftcards.alt=valueAt(content,'showcase.tabs.1.label')||screens.giftcards.alt;
  screens.qr.alt=valueAt(content,'showcase.tabs.2.label')||screens.qr.alt;
  const active=document.querySelector('[data-screen].active');if(active){const screen=screens[active.dataset.screen];document.querySelector('#screen-image').src=screen.src;document.querySelector('#screen-image').alt=screen.alt;}
}
async function loadPublishedContent(){
  try{
    const response=await fetch(CMS_URL,{method:'POST',headers:{apikey:CMS_KEY,'Content-Type':'application/json'},body:JSON.stringify({p_key:'site.home'})});
    if(!response.ok)throw new Error('CONTENT_UNAVAILABLE');
    const payload=await response.json();const content=payload?.content;
    if(content&&typeof content==='object')applyContent(content);
  }catch(_){/* De ingebouwde inhoud blijft beschikbaar wanneer de CMS-service offline is. */}
}
loadPublishedContent();
