import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';

const source=(await readFile(new URL('../app.js',import.meta.url),'utf8')).match(/^async function inviteStaff\(\).*$/m)[0];
async function run(result) {
  let closed=false,reset=false,refreshes=0;const messages=[];
  const nodes={'#staff-email':{value:'existing@example.invalid'},'#staff-role':{value:'support'},'#staff-name':{value:'Test'},'#staff-error':{textContent:''},'#staff-dialog':{close(){closed=true}},'#staff-form':{reset(){reset=true}}};
  const context=vm.createContext({$:selector=>nodes[selector],supabase:{functions:{invoke:async()=>result},rpc:async()=>{throw new Error('Invitation failure must not silently change a role.')}},location:{href:'https://beheer.paskluis.com/'},URL,getFunctionErrorMessage:async(error,data)=>data?.error||error?.message,toast:message=>messages.push(message),refreshAll:async()=>{refreshes++}});
  vm.runInContext(source,context);await context.inviteStaff();
  return {closed,reset,refreshes,messages,error:nodes['#staff-error'].textContent};
}
test('existing account access never claims an invitation email was sent',async()=>{
  const result=await run({data:{existing:true}});
  assert.equal(result.closed,true);assert.equal(result.refreshes,1);
  assert.match(result.messages[0],/geen uitnodigingsmail/);
});
test('confirmed new invitation reports an email',async()=>{
  const result=await run({data:{invited:true}});assert.equal(result.closed,true);
  assert.equal(result.messages[0],'Uitnodigingsmail is verstuurd.');
});
test('MFA and delivery errors keep the dialog open and never grant fallback access',async()=>{
  for(const error of ['MFA_REQUIRED','Email delivery failed']) {
    const result=await run({data:{error},error:{message:error}});
    assert.equal(result.closed,false);assert.equal(result.reset,false);assert.equal(result.refreshes,0);
    assert.equal(result.messages.length,0);assert.ok(result.error);
  }
});
test('empty server reply cannot claim that an email was sent',async()=>{
  const result=await run({data:null});assert.equal(result.closed,false);assert.equal(result.messages.length,0);
});
