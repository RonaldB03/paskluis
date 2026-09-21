import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function base64Url(value: Uint8Array | string) {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

async function createGoogleAccessToken(serviceAccount: Record<string, string>) {
  const pem = serviceAccount.private_key
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replaceAll(/\s/g, '');
  const privateKey = Uint8Array.from(
    atob(pem),
    (character) => character.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    'pkcs8',
    privateKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const now = Math.floor(Date.now() / 1000);
  const tokenUri = serviceAccount.token_uri || 'https://oauth2.googleapis.com/token';
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claim}`;
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || !result.access_token) {
    throw new Error('Firebase-toegang kon niet worden aangemaakt.');
  }
  return String(result.access_token);
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) throw new Error('Niet ingelogd.');

    const url = Deno.env.get('SUPABASE_URL') || '';
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') || '';
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
    const firebaseJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') || '';
    const serviceAccount = JSON.parse(firebaseJson) as Record<string, string>;
    const caller = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const admin = createClient(url, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: userData, error: userError } = await caller.auth.getUser();
    if (userError || !userData.user) throw new Error('Sessie is verlopen.');
    const payload = await request.json();
    const membershipId = String(payload.membership_id || '').trim();
    if (!membershipId) throw new Error('De gedeelde kaart ontbreekt.');

    const { data: membership, error: membershipError } = await admin
      .from('card_share_members')
      .select('id, recipient_id, revoked_at, removed_by_recipient_at, shared_cards!inner(id, owner_id, card_type, card_payload)')
      .eq('id', membershipId)
      .maybeSingle();
    if (membershipError || !membership) {
      throw membershipError || new Error('Gedeelde toegang niet gevonden.');
    }

    const relation = membership.shared_cards;
    const card = Array.isArray(relation) ? relation[0] : relation;
    if (!card || card.owner_id !== userData.user.id) {
      throw new Error('Je mag deze melding niet versturen.');
    }
    if (membership.revoked_at || membership.removed_by_recipient_at) {
      throw new Error('De gedeelde toegang is niet actief.');
    }

    const { data: tokens, error: tokensError } = await admin
      .from('push_device_tokens')
      .select('id, token')
      .eq('user_id', membership.recipient_id);
    if (tokensError) throw tokensError;
    if (!tokens || tokens.length === 0) {
      return Response.json({ sent: 0, reason: 'no_registered_device' }, { headers: corsHeaders });
    }

    const cardName = String(card.card_payload?.name || '').trim();
    const fallback = card.card_type === 'Cadeaukaart'
      ? 'Een cadeaukaart'
      : 'Een klantenkaart';
    const accessToken = await createGoogleAccessToken(serviceAccount);
    let sent = 0;

    for (const device of tokens) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: {
                title: 'Nieuwe kaart in PasKluis',
                body: `${cardName || fallback} is met jou gedeeld.`,
              },
              data: {
                event: 'shared_card',
                membership_id: membership.id,
                shared_card_id: card.id,
                card_type: String(card.card_type),
              },
              android: {
                priority: 'high',
                notification: { channel_id: 'shared_cards', sound: 'default' },
              },
              apns: { payload: { aps: { sound: 'default' } } },
            },
          }),
        },
      );
      if (response.ok) {
        sent++;
      } else {
        const errorText = await response.text();
        if (errorText.includes('UNREGISTERED')) {
          await admin.from('push_device_tokens').delete().eq('id', device.id);
        } else {
          console.error('[fcm]', response.status, errorText);
        }
      }
    }

    return Response.json({ sent }, { headers: corsHeaders });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('[send-shared-card-notification]', message);
    return Response.json(
      { error: message || 'De melding kon niet worden verstuurd.' },
      { status: 400, headers: corsHeaders },
    );
  }
});
