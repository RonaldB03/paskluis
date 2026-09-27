import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validateMenu,visibleItems,moveItem,safeUrl} from '../app-menu-model.js';
const source=JSON.parse(readFileSync(new URL('../app-menu-default.json',import.meta.url),'utf8'));
const copy=()=>structuredClone(source);
test('built-in config is valid and identical on app and admin',()=>{
 assert.deepEqual(validateMenu(source),[]);
 assert.deepEqual(source,JSON.parse(readFileSync(new URL('../../assets/config/app_menu.json',import.meta.url),'utf8')));
});
test('privacy cannot disappear through category, item or audience settings',()=>{
 for(const change of [s=>s.hidden=true,s=>s.items.find(i=>i.action==='privacy').hidden=true,s=>s.items.find(i=>i.action==='privacy').audience='plus',s=>s.items=s.items.filter(i=>i.action!=='privacy')]){
  const c=copy();change(c.sections.find(s=>s.id==='security'));assert.ok(validateMenu(c).length);
 }
});
test('audiences distinguish hidden, free, plus and locked previews',()=>{
 const s={hidden:false,items:['all','free','plus','locked'].map(audience=>({audience,hidden:false}))};
 assert.deepEqual(visibleItems(s,false).map(i=>i.audience),['all','free','locked']);
 assert.deepEqual(visibleItems(s,true).map(i=>i.audience),['all','plus','locked']);
 s.hidden=true;assert.deepEqual(visibleItems(s,true),[]);
});
test('only explicit HTTPS links without embedded credentials are allowed',()=>{
 for(const url of ['javascript:alert(1)','data:text/html,hi','http://example.com','https://name:secret@example.com','https://example.com/ unsafe','https://localhost'])assert.equal(safeUrl(url),false,url);
 assert.equal(safeUrl('https://paskluis.com/testen?platform=ios'),true);
});
test('unknown executable actions, duplicate settings and unsupported schema fail closed',()=>{
 const c=copy();c.sections[0].items[0].action='runCode';assert.ok(validateMenu(c).length);
 const d=copy();d.sections[0].items.push({...d.sections[0].items[0],id:'duplicate'});assert.ok(validateMenu(d).length);
 const e=copy();e.schemaVersion=2;assert.ok(validateMenu(e).length);
});
test('moving settings preserves action and moves exactly one copy',()=>{
 const c=copy();assert.equal(moveItem(c,'security','privacy','help','help'),true);
 assert.equal(c.sections[0].items[0].action,'privacy');assert.deepEqual(validateMenu(c),[]);
 assert.equal(moveItem(c,'help','privacy','help','privacy'),false);
 assert.equal(moveItem(c,'help','privacy','missing'),false);
});
