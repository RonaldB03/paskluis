import {JSDOM} from 'jsdom';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {createMenuEditor} from '../app-menu.js';
const base=new URL('../',import.meta.url);
const config=JSON.parse(readFileSync(new URL('app-menu-default.json',base)));
const catalog=JSON.parse(readFileSync(new URL('app-menu-catalog.json',base)));
const dom=new JSDOM('<main id="root"></main>',{url:'https://example.test/'});
global.window=dom.window;
global.fetch=async()=>({ok:true,json:async()=>catalog});
const root=dom.window.document.querySelector('#root');
const calls=[],toasts=[];
let draft={config:structuredClone(config),revision:1},publication={revision:1,published_at:new Date().toISOString()},history=[{revision:1,published_at:publication.published_at}];
const client={
 from(table){const result={data:table==='app_menu_draft'?structuredClone(draft):table==='app_menu_publication'?publication:history};return {select:()=>({eq:()=>({single:async()=>result}),order:()=>({limit:async()=>result})})};},
 async rpc(name,args){calls.push({name,args:structuredClone(args)});if(name==='save_app_menu'){assert.equal(args.p_expected_revision,draft.revision);draft={config:structuredClone(args.p_config),revision:draft.revision+1};return {data:draft.revision};}assert.equal(name,'publish_app_menu');assert.equal(args.p_expected_revision,draft.revision);draft.revision++;publication={...publication,revision:publication.revision+1};history=[publication,...history];return {data:publication.revision};}
};
const editor=createMenuEditor({client,root,toast:m=>toasts.push(m),confirmAction:async()=>true});
const settle=()=>new Promise(r=>setImmediate(r));
await editor.load();
assert.equal(root.querySelectorAll('.menu-section').length,9);
assert.equal(root.querySelector('#menu-preview').textContent.includes('Ontdek PasKluis Plus'),true);
const plan=root.querySelector('#menu-preview-plan');plan.value='plus';plan.dispatchEvent(new dom.window.Event('change',{bubbles:true}));
assert.equal(root.querySelector('#menu-preview').textContent.includes('Ontdek PasKluis Plus'),false);
// Editing a title updates preview and blocks accidental publication of unsaved work.
const title=root.querySelector('[data-section="help"] [data-field="title.nl"]');title.value='Vraag en antwoord';title.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
assert.equal(root.querySelector('#menu-preview').textContent.includes('Vraag en antwoord'),true);
assert.equal(root.querySelector('[data-command="publish"]').disabled,true);
root.querySelector('[data-command="save"]').click();await settle();await settle();
assert.equal(calls[0].args.p_config.sections[0].title.nl,'Vraag en antwoord');
assert.equal(root.querySelector('[data-command="publish"]').disabled,false);
root.querySelector('[data-command="publish"]').click();await settle();await settle();
assert.equal(publication.revision,2);
assert.ok(root.querySelector('#menu-status').textContent.includes('versie 2'));
assert.equal(root.querySelector('[data-command="revert"]').disabled,false);
// A protected privacy item cannot be removed.
root.querySelector('[data-item="privacy"] [data-remove-item]').click();
assert.ok(root.querySelector('[data-item="privacy"]'));
assert.ok(toasts.at(-1).includes('Privacy'));
// Select-based move remains usable without drag-and-drop.
const move=root.querySelector('[data-item="privacy"] [data-move-item]');move.value='help';move.dispatchEvent(new dom.window.Event('change',{bubbles:true}));
assert.ok(root.querySelector('[data-section="help"] [data-item="privacy"]'));
// Unsafe external content is rendered as text, never HTML.
const external=root.querySelector('[data-section="share"] [data-add-item]');external.click();
const last=root.querySelector('[data-section="share"] .menu-item:last-child [data-field="title.nl"]');last.value='<img src=x onerror=alert(1)>';last.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
assert.equal(root.querySelectorAll('#menu-preview img').length,0);
console.log('Editor integration passed: Free/Plus preview, edit/save/publish, history, privacy protection, move and HTML escaping.');
