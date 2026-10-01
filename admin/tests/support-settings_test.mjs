import test from 'node:test';
import assert from 'node:assert/strict';
import {JSDOM} from 'jsdom';
import {supportMenuMarkup,settingPatch} from '../support-settings.js';
const data={revision:0,appliedRevision:0,settings:{language:'system',nearbyRadiusMeters:1000,showCardDistances:true},diagnostics:{appLockEnabled:true},menu:[{id:'language',title:'Taal',collapsed:true,items:[{action:'language',title:'Taal'}]},{id:'location',title:'Locatie en winkels',items:[{action:'radius',title:'Afstand'},{action:'distances',title:'Afstanden'},{action:'lock',title:'Slot'}]}]};
test('mirrors section order, current values and device-only lock',()=>{
 const doc=new JSDOM(supportMenuMarkup(data)).window.document;
 assert.deepEqual([...doc.querySelectorAll('summary strong')].map(x=>x.textContent),['Taal','Locatie en winkels']);
 assert.equal(doc.querySelector('[data-support-setting=language]').value,'system');
 assert.equal(doc.querySelector('[data-support-setting=nearbyRadiusMeters]').value,'1000');
 assert.equal(doc.querySelector('[data-support-setting=showCardDistances]').checked,true);
 assert.equal(doc.querySelector('[data-support-setting=appLockEnabled]'),null);
});
test('pending changes and Plus locks cannot be edited',()=>{
 const doc=new JSDOM(supportMenuMarkup({...data,revision:1})).window.document;
 assert.ok([...doc.querySelectorAll('input,select')].every(x=>x.disabled));
 const locked=new JSDOM(supportMenuMarkup({...data,menu:[{items:[{action:'language',locked:true}]}]})).window.document;
 assert.equal(locked.querySelector('select').disabled,true);
});
test('escapes menu text and accepts only valid setting keys and values',()=>{
 assert.ok(!supportMenuMarkup({...data,menu:[{title:'<img src=x>',items:[]}]}).includes('<img'));
 assert.deepEqual(settingPatch({dataset:{supportSetting:'nearbyRadiusMeters'},type:'select',value:'250'}),{nearbyRadiusMeters:250});
 assert.deepEqual(settingPatch({dataset:{supportSetting:'showCardDistances'},type:'checkbox',checked:false}),{showCardDistances:false});
 assert.throws(()=>settingPatch({dataset:{supportSetting:'cardCodes'}}));
 assert.throws(()=>settingPatch({dataset:{supportSetting:'language'},value:'bad'}));
});
