import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) throw new Error('Niet ingelogd.');

    const url = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const callerClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const adminClient = createClient(url, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: { user }, error: userError } = await callerClient.auth.getUser();
    if (userError || !user) throw new Error('Sessie is verlopen.');

    // Staff access is verified with the caller JWT, including MFA and session validity.
    const permission = await callerClient.rpc('is_admin');
    if (permission.error || permission.data !== true) {
      return Response.json({error:'MFA_REQUIRED'}, {status:403,headers:corsHeaders});
    }

    const body = await request.json();
    const email = String(body.email || '').trim().toLowerCase();
    const role = String(body.role || 'support');
    const displayName = String(body.displayName || '').trim();
    const redirectTo = String(body.redirectTo || '').trim() || undefined;
    if (!email || !email.includes('@')) throw new Error('Vul een geldig e-mailadres in.');
    if (!['admin', 'support'].includes(role)) throw new Error('Ongeldige medewerkersrol.');

    const { data: existing } = await adminClient
      .from('profiles')
      .select('id,email')
      .ilike('email', email)
      .maybeSingle();

    if (existing) {
      const { error } = await adminClient
        .from('profiles')
        .update({ role, display_name: displayName || undefined, updated_at: new Date().toISOString() })
        .eq('id', existing.id);
      if (error) throw error;
      return Response.json({ existing: true, email, role }, { headers: corsHeaders });
    }

    const { data: invited, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(email, {
      redirectTo,
      data: { name: displayName, invited_as_staff: true },
    });
    if (inviteError) throw inviteError;
    if (!invited.user) throw new Error('De uitnodiging kon niet worden aangemaakt.');

    const { error: profileError } = await adminClient
      .from('profiles')
      .update({ role, display_name: displayName || null, email, updated_at: new Date().toISOString() })
      .eq('id', invited.user.id);
    if (profileError) throw profileError;

    return Response.json({ invited: true, email, role }, { headers: corsHeaders });
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : 'Uitnodigen is niet gelukt.' },
      { status: 400, headers: corsHeaders },
    );
  }
});
