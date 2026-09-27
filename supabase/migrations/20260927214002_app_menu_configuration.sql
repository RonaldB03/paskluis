-- A menu changes presentation, never entitlements or feature authorization.
create or replace function public.valid_app_menu(config jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare section jsonb; item jsonb; share jsonb; ids text[] := '{}'; sections text[] := '{}'; actions text[] := '{}';
  count_items int := 0; privacy_ok boolean := false; field jsonb; lang text;
  known_actions constant text[] := array['help','support','share','lock','hidePins','privacy','backupAuto','backupNow','restore','folders','favoritesFirst','favoritesHome','sorting','start','clarity','location','radius','distances','nearbyFirst','nearbyHome','brightness','awake','notifications','language','plus','device','external'];
  known_icons constant text[] := array['','help','share','security','backup','folder','star','cards','home','display','location','notifications','language','link'];
begin
  if config is null or jsonb_typeof(config) <> 'object' or (config->>'schemaVersion') is distinct from '1' or octet_length(config::text)>100000 or jsonb_typeof(config->'sections') is distinct from 'array' then return false; end if;
  if jsonb_array_length(config->'sections') not between 1 and 20 then return false; end if;
  share := config->'share';
  if jsonb_typeof(share) is distinct from 'object' or coalesce(share->>'url','') !~ '^https://[^/@[:space:]]+\.[^/@[:space:]]+([/?#][^[:space:]]*)?$' or length(share->>'url')>2048 then return false; end if;
  foreach lang in array array['nl','en'] loop
    if jsonb_typeof(share->'text'->lang) is distinct from 'string' or length(btrim(share->'text'->>lang)) not between 1 and 2000 then return false; end if;
  end loop;
  for section in select value from jsonb_array_elements(config->'sections') loop
    if coalesce(section->>'id','') !~ '^[a-zA-Z0-9_-]{1,64}$' or section->>'id'=any(sections) or not coalesce(section->>'icon'=any(known_icons),false) or jsonb_typeof(section->'collapsed') is distinct from 'boolean' or jsonb_typeof(section->'hidden') is distinct from 'boolean' or jsonb_typeof(section->'items') is distinct from 'array' then return false; end if;
    sections := array_append(sections,section->>'id');
    foreach lang in array array['nl','en'] loop
      if jsonb_typeof(section->'title'->lang) is distinct from 'string' or length(btrim(section->'title'->>lang)) not between 1 and 120 or jsonb_typeof(section->'description'->lang) is distinct from 'string' or length(section->'description'->>lang)>500 then return false; end if;
    end loop;
    for item in select value from jsonb_array_elements(section->'items') loop
      count_items := count_items+1;
      if count_items>100 or coalesce(item->>'id','') !~ '^[a-zA-Z0-9_-]{1,64}$' or item->>'id'=any(ids) or not coalesce(item->>'action'=any(known_actions),false) or not coalesce(item->>'icon'=any(known_icons),false) or not coalesce(item->>'audience'=any(array['all','free','plus','locked']),false) or jsonb_typeof(item->'hidden') is distinct from 'boolean' then return false; end if;
      ids := array_append(ids,item->>'id');
      if item->>'action'<>'external' then
        if item->>'action'=any(actions) then return false; end if;
        actions:=array_append(actions,item->>'action');
      elsif coalesce(item->>'url','') !~ '^https://[^/@[:space:]]+\.[^/@[:space:]]+([/?#][^[:space:]]*)?$' or length(item->>'url')>2048 then return false;
      end if;
      foreach lang in array array['nl','en'] loop
        if jsonb_typeof(item->'title'->lang) is distinct from 'string' or length(item->'title'->>lang)>120 or jsonb_typeof(item->'description'->lang) is distinct from 'string' or length(item->'description'->>lang)>500 then return false; end if;
        if item->>'action'='external' and btrim(item->'title'->>lang)='' then return false; end if;
      end loop;
      if item->>'action'='privacy' and item->>'audience'='all' and item->>'hidden'='false' and section->>'hidden'='false' then privacy_ok:=true; end if;
    end loop;
  end loop;
  return privacy_ok;
exception when others then return false;
end;
$$;

create table public.app_menu_publication (
  id int primary key check(id=1), revision bigint not null default 1,
  config jsonb not null check(public.valid_app_menu(config)), published_at timestamptz not null default now()
);
create table public.app_menu_draft (
  id int primary key check(id=1), revision bigint not null default 1,
  config jsonb not null check(public.valid_app_menu(config)), updated_at timestamptz not null default now()
);
create table public.app_menu_history (
  revision bigint primary key, config jsonb not null check(public.valid_app_menu(config)),
  published_at timestamptz not null default now(), published_by uuid references public.profiles(id) on delete set null
);
alter table public.app_menu_publication enable row level security;
alter table public.app_menu_draft enable row level security;
alter table public.app_menu_history enable row level security;
revoke all on public.app_menu_publication, public.app_menu_draft, public.app_menu_history from anon, authenticated;
grant select on public.app_menu_publication to anon, authenticated;
grant select on public.app_menu_draft, public.app_menu_history to authenticated;
create policy "Published menu is public" on public.app_menu_publication for select to anon, authenticated using(true);
create policy "Admins read draft" on public.app_menu_draft for select to authenticated using((select public.is_admin()));
create policy "Admins read menu history" on public.app_menu_history for select to authenticated using((select public.is_admin()));

-- The only write route: admin checked, serialized and optimistic locking to
-- prevent one browser silently overwriting another editor's changes.
create or replace function public.save_app_menu(p_config jsonb, p_expected_revision bigint)
returns bigint language plpgsql security definer set search_path = '' as $$
declare current_revision bigint;
begin
  if not public.is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select revision into current_revision from public.app_menu_draft where id=1 for update;
  if current_revision is distinct from p_expected_revision then raise exception 'MENU_CONFLICT'; end if;
  if not public.valid_app_menu(p_config) then raise exception 'INVALID_MENU'; end if;
  update public.app_menu_draft set config=p_config,revision=revision+1,updated_at=now() where id=1 returning revision into current_revision;
  return current_revision;
end; $$;
create or replace function public.publish_app_menu(p_expected_revision bigint, p_restore_revision bigint default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare draft public.app_menu_draft%rowtype; next_revision bigint; selected_config jsonb;
begin
  if not public.is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
  select * into draft from public.app_menu_draft where id=1 for update;
  if draft.revision is distinct from p_expected_revision then raise exception 'MENU_CONFLICT'; end if;
  selected_config:=draft.config;
  if p_restore_revision is not null then
    select config into selected_config from public.app_menu_history where revision=p_restore_revision;
    if selected_config is null then raise exception 'MENU_VERSION_NOT_FOUND'; end if;
  end if;
  if not public.valid_app_menu(selected_config) then raise exception 'INVALID_MENU'; end if;
  update public.app_menu_publication set revision=revision+1,config=selected_config,published_at=now() where id=1 returning revision into next_revision;
  insert into public.app_menu_history(revision,config,published_by) values(next_revision,selected_config,auth.uid());
  update public.app_menu_draft set revision=revision+1,config=selected_config,updated_at=now() where id=1;
  insert into public.admin_audit_log(actor_id,action,entity_type,entity_id,summary)
    values(auth.uid(),'publish','app_menu',next_revision::text,case when p_restore_revision is null then 'Appmenu gepubliceerd' else 'Appmenu teruggezet naar versie '||p_restore_revision end);
  return next_revision;
end; $$;
revoke all on function public.valid_app_menu(jsonb) from public;
revoke all on function public.save_app_menu(jsonb,bigint) from public;
revoke all on function public.publish_app_menu(bigint,bigint) from public;
grant execute on function public.save_app_menu(jsonb,bigint) to authenticated;
grant execute on function public.publish_app_menu(bigint,bigint) to authenticated;

insert into public.app_menu_publication(id,config) values (1, '{
  "schemaVersion": 1,
  "share": {
    "text": {
      "nl": "Ik gebruik PasKluis voor mijn klantenkaarten, QR-codes en cadeaukaarten. Bekijk de app hier:",
      "en": "I use PasKluis for my loyalty cards, QR codes and gift cards. Discover the app here:"
    },
    "url": "https://paskluis.com"
  },
  "sections": [
    {
      "id": "help",
      "title": {
        "nl": "Hulp",
        "en": "Help"
      },
      "description": {
        "nl": "",
        "en": ""
      },
      "icon": "help",
      "collapsed": false,
      "hidden": false,
      "items": [
        {
          "id": "help",
          "action": "help",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "support",
          "action": "support",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        }
      ]
    },
    {
      "id": "share",
      "title": {
        "nl": "Deel PasKluis",
        "en": "Share PasKluis"
      },
      "description": {
        "nl": "",
        "en": ""
      },
      "icon": "share",
      "collapsed": false,
      "hidden": false,
      "items": [
        {
          "id": "share",
          "action": "share",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        }
      ]
    },
    {
      "id": "security",
      "title": {
        "nl": "Beveiliging en privacy",
        "en": "Security and privacy"
      },
      "description": {
        "nl": "",
        "en": ""
      },
      "icon": "security",
      "collapsed": true,
      "hidden": false,
      "items": [
        {
          "id": "lock",
          "action": "lock",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "hidePins",
          "action": "hidePins",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "privacy",
          "action": "privacy",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        }
      ]
    },
    {
      "id": "backup",
      "title": {
        "nl": "Back-up en herstel",
        "en": "Backup and restore"
      },
      "description": {
        "nl": "",
        "en": ""
      },
      "icon": "backup",
      "collapsed": true,
      "hidden": false,
      "items": [
        {
          "id": "backupAuto",
          "action": "backupAuto",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "backupNow",
          "action": "backupNow",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "restore",
          "action": "restore",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        }
      ]
    },
    {
      "id": "cards",
      "title": {
        "nl": "Kaarten en weergave",
        "en": "Cards and display"
      },
      "description": {
        "nl": "",
        "en": ""
      },
      "icon": "cards",
      "collapsed": true,
      "hidden": false,
      "items": [
        {
          "id": "folders",
          "action": "folders",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "favoritesFirst",
          "action": "favoritesFirst",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "favoritesHome",
          "action": "favoritesHome",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "sorting",
          "action": "sorting",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "start",
          "action": "start",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "clarity",
          "action": "clarity",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "device",
          "action": "device",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        }
      ]
    },
    {
      "id": "location",
      "title": {
        "nl": "Locatie en winkels",
        "en": "Location and stores"
      },
      "description": {
        "nl": "",
        "en": ""
      },
      "icon": "location",
      "collapsed": true,
      "hidden": false,
      "items": [
        {
          "id": "location",
          "action": "location",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "radius",
          "action": "radius",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "distances",
          "action": "distances",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "nearbyFirst",
          "action": "nearbyFirst",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "nearbyHome",
          "action": "nearbyHome",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        }
      ]
    },
    {
      "id": "screen",
      "title": {
        "nl": "Scherm en meldingen",
        "en": "Screen and notifications"
      },
      "description": {
        "nl": "",
        "en": ""
      },
      "icon": "display",
      "collapsed": true,
      "hidden": false,
      "items": [
        {
          "id": "brightness",
          "action": "brightness",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "awake",
          "action": "awake",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        },
        {
          "id": "notifications",
          "action": "notifications",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        }
      ]
    },
    {
      "id": "language",
      "title": {
        "nl": "Taal",
        "en": "Language"
      },
      "description": {
        "nl": "",
        "en": ""
      },
      "icon": "language",
      "collapsed": true,
      "hidden": false,
      "items": [
        {
          "id": "language",
          "action": "language",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "all",
          "hidden": false,
          "url": ""
        }
      ]
    },
    {
      "id": "plus",
      "title": {
        "nl": "PasKluis Plus",
        "en": "PasKluis Plus"
      },
      "description": {
        "nl": "",
        "en": ""
      },
      "icon": "star",
      "collapsed": false,
      "hidden": false,
      "items": [
        {
          "id": "plus",
          "action": "plus",
          "title": {
            "nl": "",
            "en": ""
          },
          "description": {
            "nl": "",
            "en": ""
          },
          "icon": "",
          "audience": "free",
          "hidden": false,
          "url": ""
        }
      ]
    }
  ]
}
'::jsonb);
insert into public.app_menu_draft(id,config) select id,config from public.app_menu_publication;
insert into public.app_menu_history(revision,config) select revision,config from public.app_menu_publication;
