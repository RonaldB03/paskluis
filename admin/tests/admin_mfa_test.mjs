import test from 'node:test';
import assert from 'node:assert/strict';
import {JSDOM} from 'jsdom';
import {createAdminMfa} from '../admin-mfa.js';
function setup({verified=false, level='aal1', fail=false, qr='<svg xmlns="http://www.w3.org/2000/svg"></svg>'}={}) {
  const dom=new JSDOM('<!doctype html><body></body>');
  dom.window.HTMLDialogElement.prototype.showModal=function(){this.open=true};
  dom.window.HTMLDialogElement.prototype.close=function(){this.open=false};
  let all=verified?[{id:'existing',status:'verified'}]:[];
  const calls=[];
  const mfa={
    listFactors:async()=>({data:{totp:all.filter(f=>f.status==='verified'),all}}),
    getAuthenticatorAssuranceLevel:async()=>({data:{currentLevel:level}}),
    enroll:async()=>{all=[{id:'new',status:'unverified'}];return {data:{id:'new',totp:{qr_code:qr,secret:'test-only-secret'}}}},
    challengeAndVerify:async args=>{calls.push(args);if(fail)return {error:{message:'wrong'}};level='aal2';all=all.map(f=>({...f,status:'verified'}));return {data:{}}},
    unenroll:async args=>{calls.push({unenroll:args.factorId});all=[];return {data:{}}},
  };
  return {dom,calls,flow:createAdminMfa({client:{auth:{mfa}},document:dom.window.document})};
}
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function submit(dom,code='123456') {
  const form=dom.window.document.querySelector('form');
  form.querySelector('input').value=code;
  form.dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
}
test('unenrolled staff can enroll before server enforcement',async()=>{
  const {flow,dom}=setup();assert.equal(await flow.requireExistingFactor(),false);
  assert.equal(dom.window.document.querySelector('dialog'),null);
});
test('existing factor blocks continuation until successful challenge',async()=>{
  const {flow,dom,calls}=setup({verified:true});
  let done=false;const promise=flow.requireExistingFactor().then(v=>{done=true;return v});await tick();
  assert.equal(done,false);submit(dom);assert.equal(await promise,true);
  assert.equal(calls[0].factorId,'existing');assert.equal(dom.window.document.querySelector('dialog'),null);
});
test('aal2 requires no further challenge',async()=>{
  const {flow,dom}=setup({verified:true,level:'aal2'});assert.equal(await flow.requireExistingFactor(),true);
  assert.equal(dom.window.document.querySelector('dialog'),null);
});
test('enrollment displays QR as image, verifies and removes secrets from DOM',async()=>{
  const {flow,dom}=setup({qr:'data:image/svg+xml;base64,PHN2Zy8+'});
  const promise=flow.enroll();await tick();
  assert.equal(dom.window.document.querySelector('img').getAttribute('src'),'data:image/svg+xml;base64,PHN2Zy8+');
  assert.equal(dom.window.document.querySelector('svg'),null);
  submit(dom);await promise;assert.equal(dom.window.document.body.textContent.includes('test-only-secret'),false);
});
test('cancel deletes only the newly created unverified factor',async()=>{
  const {flow,dom,calls}=setup();const promise=flow.enroll();const rejected=assert.rejects(promise,/geannuleerd/);await tick();
  dom.window.document.querySelector('.mfa-cancel').click();await rejected;
  assert.deepEqual(calls,[{unenroll:'new'}]);
});
test('wrong code keeps gate closed, clears input, cancellation rejects',async()=>{
  const {flow,dom}=setup({verified:true,fail:true});
  const promise=flow.requireExistingFactor();const rejected=assert.rejects(promise,/geannuleerd/);await tick();submit(dom);await tick();
  assert.ok(dom.window.document.querySelector('dialog').open);
  assert.equal(dom.window.document.querySelector('input').value,'');
  assert.match(dom.window.document.querySelector('.error').textContent,/niet worden bevestigd/);
  dom.window.document.querySelector('.mfa-cancel').click();await rejected;
});
