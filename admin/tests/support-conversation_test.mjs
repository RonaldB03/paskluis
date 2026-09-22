import {test} from 'node:test';
import assert from 'node:assert/strict';
import {orderedSupportMessages, supportMessageMarkup} from '../support-conversation.js';

test('a newer reply is below the original question across offsets and timestamp ties', () => {
  const rows = [
    {id: 'reply', created_at: '2026-09-22T16:33:00+02:00'},
    {id: 'ack', created_at: '2026-09-22T14:30:00.000002Z'},
    {id: 'question', created_at: '2026-09-22T14:30:00.000001Z'},
  ];
  assert.deepEqual(orderedSupportMessages(rows).map(m => m.id), ['question', 'ack', 'reply']);
  assert.equal(rows[0].id, 'reply');
});

test('all staff have the same role styling and use their saved sender name', () => {
  const html = supportMessageMarkup({id: '1', sender_kind: 'staff', sender_name: 'Ronald',
    message: 'Antwoord', created_at: '2026-09-22T14:33:00Z'}, {staffName: 'New profile name'});
  assert.match(html, /class="message staff"/);
  assert.match(html, /Ronald · PasKluis/);
  assert.doesNotMatch(html, /New profile name/);
  assert.match(supportMessageMarkup({sender_kind: 'staff'}), /Team PasKluis/);
});

test('customer and automatic messages are distinct and untrusted names/text are escaped', () => {
  const html = supportMessageMarkup({sender_kind: 'guest', message: '<img src=x onerror=alert(1)>'},
    {customerName: '<script>test</script>'});
  assert.match(html, /class="message customer"/);
  assert.match(html, /· Klant/);
  assert.doesNotMatch(html, /<script>|<img/);
  const automatic = supportMessageMarkup({sender_kind: 'automatic', message: 'Bedankt'});
  assert.match(automatic, /class="message automatic"/);
  assert.match(automatic, /Automatische ontvangstbevestiging/);
});
