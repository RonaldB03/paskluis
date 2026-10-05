import {test} from 'node:test';
import assert from 'node:assert/strict';
import {purchaseLedgerMarkup} from '../purchase-ledger.js';
test('guest and linked receipts are distinct and proofs are never displayed',()=>{
 const html=purchaseLedgerMarkup([{id:'guest',platform:'apple',environment:'production',verified_at:new Date().toISOString(),proof:'secret-token'},{id:'linked',platform:'google',environment:'sandbox',user_id:'u',revoked_at:'2026-01-01',verified_at:'2026-01-01'}],[{id:'u',email:'<script>alert(1)</script>'}]);
 assert.match(html,/Zonder account/);assert.match(html,/Ingetrokken/);assert.match(html,/&lt;script&gt;/);assert.ok(!html.includes('<script>'));assert.ok(!html.includes('secret-token'));
});
