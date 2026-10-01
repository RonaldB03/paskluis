-- Support RPCs require authentication; each function enforces its own owner/staff scope.
revoke all on function public.create_support_session(jsonb),public.activate_support_session(text),public.view_support_session(uuid),public.revoke_support_session(uuid) from public,anon;
grant execute on function public.create_support_session(jsonb),public.activate_support_session(text),public.view_support_session(uuid),public.revoke_support_session(uuid) to authenticated;
notify pgrst,'reload schema';
