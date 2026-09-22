import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const cacheHours = 24;

function normalize(value: string) {
  return value.trim().toLocaleLowerCase('nl-NL').replaceAll(/[^a-z0-9]+/g, '-');
}

function radians(value: number) {
  return value * Math.PI / 180;
}

function distanceMeters(lat1: number, lon1: number, lat2: number, lon2: number) {
  const earthRadius = 6371000;
  const dLat = radians(lat2 - lat1);
  const dLon = radians(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(dLon / 2) ** 2;
  return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const body = await request.json();
    const latitude = Number(body.latitude);
    const longitude = Number(body.longitude);
    const brands = [...new Set((Array.isArray(body.brands) ? body.brands : [])
      .map((value) => String(value).trim()).filter(Boolean))].slice(0, 20);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude)>90 || Math.abs(longitude)>180 || brands.length === 0 || brands.some(b=>b.length>100)) {
      throw new Error('Ongeldige locatie of winkels.');
    }

    const apiKey = Deno.env.get('GOOGLE_PLACES_API_KEY') || '';
    if (!apiKey) throw new Error('Google Places is nog niet geconfigureerd.');
    const admin = createClient(
      Deno.env.get('SUPABASE_URL') || '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '',
      { auth: { autoRefreshToken: false, persistSession: false } },
    );
    const {data:catalog,error:catalogError}=await admin.from('brands').select('name,aliases').eq('is_active',true);
    if(catalogError)throw new Error('Store catalog unavailable');
    const allowedNames=new Set((catalog||[]).flatMap(b=>[b.name,...(b.aliases||[])]).map(normalize));
    // Roughly 1.1 km cells: accurate enough for cache reuse while preventing
    // every small GPS movement from causing a billable lookup.
    const gridLat = latitude.toFixed(2);
    const gridLon = longitude.toFixed(2);
    const now = new Date();
    const matches: Record<string, unknown> = {};

    for (const brand of brands) {
      if(!allowedNames.has(normalize(brand)))continue;
      const cacheKey = `${normalize(brand)}:${gridLat}:${gridLon}`;
      const { data: cached } = await admin.from('nearby_store_cache').select('*')
        .eq('cache_key', cacheKey).gt('expires_at', now.toISOString()).maybeSingle();
      if (cached && Array.isArray(cached.candidates) && cached.candidates.length) {
        const nearest=[...cached.candidates].sort((a,b)=>distanceMeters(latitude,longitude,a.latitude,a.longitude)-distanceMeters(latitude,longitude,b.latitude,b.longitude))[0];
        cached.store_latitude=nearest.latitude;cached.store_longitude=nearest.longitude;
        cached.store_name=nearest.name;cached.store_address=nearest.address;
        const actualDistance = distanceMeters(
          latitude, longitude, cached.store_latitude, cached.store_longitude,
        );
        matches[brand] = {
          store_name: cached.store_name,
          address: cached.store_address,
          distance_meters: Math.round(actualDistance),
          cached: true,
        };
        continue;
      }

      const budget=await admin.rpc('reserve_places_request');
      if(budget.error||budget.data!==true)continue;

      const placesResponse = await fetch('https://places.googleapis.com/v1/places:searchText', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,places.location',
        },
        body: JSON.stringify({
          textQuery: `${brand} winkel`,
          languageCode: 'nl',
          regionCode: 'NL',
          pageSize: 10,
          rankPreference: 'DISTANCE',
          locationBias: {
            circle: { center: { latitude, longitude }, radius: 50000 },
          },
        }),
      });
      if (!placesResponse.ok) {
        console.error('[places]', placesResponse.status);
        continue;
      }
      const result = await placesResponse.json();
      const candidates=(result.places||[]).filter(p=>Number.isFinite(p.location?.latitude)&&Number.isFinite(p.location?.longitude)).map(p=>({latitude:p.location.latitude,longitude:p.location.longitude,name:String(p.displayName?.text||brand),address:String(p.formattedAddress||'')}));
      candidates.sort((a,b)=>distanceMeters(latitude,longitude,a.latitude,a.longitude)-distanceMeters(latitude,longitude,b.latitude,b.longitude));
      const nearest=candidates[0];
      const place=nearest?{location:{latitude:nearest.latitude,longitude:nearest.longitude},displayName:{text:nearest.name},formattedAddress:nearest.address}:null;
      const storeLat = Number(place?.location?.latitude);
      const storeLon = Number(place?.location?.longitude);
      if (!Number.isFinite(storeLat) || !Number.isFinite(storeLon)) continue;
      const distance = distanceMeters(latitude, longitude, storeLat, storeLon);
      const row = {
        cache_key: cacheKey,
        candidates,
        brand_name: brand,
        origin_latitude: Number(gridLat),
        origin_longitude: Number(gridLon),
        store_name: String(place.displayName?.text || brand),
        store_address: String(place.formattedAddress || ''),
        store_latitude: storeLat,
        store_longitude: storeLon,
        distance_meters: Math.round(distance),
        expires_at: new Date(now.getTime() + cacheHours * 3600000).toISOString(),
        updated_at: now.toISOString(),
      };
      await admin.from('nearby_store_cache').upsert(row);
      matches[brand] = {
        store_name: row.store_name,
        address: row.store_address,
        distance_meters: row.distance_meters,
        cached: false,
      };
    }
    return Response.json({ matches }, { headers: corsHeaders });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('[nearest-brand-stores]', message);
    return Response.json({ error: message }, { status: 400, headers: corsHeaders });
  }
});
