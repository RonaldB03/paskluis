import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { test } from 'node:test';
import assert from 'node:assert/strict';

// Exercise the actual endpoint with mocked database/Places boundaries. No
// credentials, network requests or paid lookups are used by these tests.
const source = stripTypeScriptTypes(readFileSync(
  new URL('../supabase/functions/nearest-brand-stores/index.ts', import.meta.url), 'utf8',
).replace(/^import .*createClient.*;\n/, ''));

async function run({ brands, cached = [], denied = false, failed = '' }) {
  let handler;
  const stats = { reads: 0, reservations: 0, lookups: 0, active: 0, peak: 0, writes: 0 };
  const admin = {
    from(table) {
      if (table === 'brands') return { select: () => ({ eq: async () => ({
        data: brands.map(name => ({ name, aliases: [] })),
      }) }) };
      assert.equal(table, 'nearby_store_cache');
      return {
        select: () => ({ in: (column, keys) => ({ gt: async () => {
          assert.equal(column, 'cache_key');
          stats.reads++;
          return { data: cached.filter(row => keys.includes(row.cache_key)) };
        } }) }),
        upsert: async () => { stats.writes++; return {}; },
      };
    },
    rpc: async name => {
      assert.equal(name, 'reserve_places_request'); stats.reservations++;
      return { data: !denied };
    },
  };
  const fetch = async (url, options) => {
    assert.equal(url, 'https://places.googleapis.com/v1/places:searchText');
    assert.ok(options.signal instanceof AbortSignal);
    stats.lookups++; stats.active++;
    stats.peak = Math.max(stats.peak, stats.active);
    await new Promise(resolve => setImmediate(resolve));
    stats.active--;
    const name = JSON.parse(options.body).textQuery.replace(/ winkel$/, '');
    if (name === failed) throw new Error('network failure');
    return Response.json({ places: [{ displayName: { text: name },
      formattedAddress: 'Test address', location: { latitude: 52, longitude: 5 } }] });
  };
  new Function('createClient', 'Deno', 'fetch', source)(() => admin, {
    serve: callback => { handler = callback; }, env: { get: () => 'test-only' },
  }, fetch);
  const response = await handler(new Request('https://example.test', {
    method: 'POST', body: JSON.stringify({ latitude: 52, longitude: 5, brands }),
  }));
  assert.equal(response.status, 200);
  return { stats, body: await response.json() };
}

test('cached stores use one database read and no paid requests', async () => {
  const brands = ['Shop A', 'Shop B'];
  const cached = brands.map((name, i) => ({
    cache_key: `shop-${i === 0 ? 'a' : 'b'}:52.00:5.00`,
    candidates: [{ latitude: 52, longitude: 5, name, address: 'Test' }],
  }));
  const { stats, body } = await run({ brands, cached });
  assert.equal(stats.reads, 1);
  assert.equal(stats.lookups, 0);
  assert.equal(stats.reservations, 0);
  assert.equal(Object.keys(body.matches).length, 2);
  assert.equal(body.matches['Shop A'].distance_meters, 0);
});

test('cold lookups run concurrently with a maximum of four', async () => {
  const brands = Array.from({ length: 11 }, (_, i) => `Shop ${i}`);
  const { stats, body } = await run({ brands });
  assert.equal(stats.reads, 1);
  assert.equal(stats.peak, 4);
  assert.equal(stats.reservations, 11);
  assert.equal(stats.writes, 11);
  assert.equal(Object.keys(body.matches).length, 11);
});

test('budget denial prevents Places calls', async () => {
  const { stats, body } = await run({ brands: ['Shop A'], denied: true });
  assert.equal(stats.lookups, 0);
  assert.deepEqual(body.matches, {});
});

test('a failed store lookup does not discard successful stores', async () => {
  const { body } = await run({ brands: ['Shop A', 'Shop B'], failed: 'Shop A' });
  assert.deepEqual(Object.keys(body.matches), ['Shop B']);
});
