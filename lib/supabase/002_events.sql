begin;

-- Store event information.
create table public.events (
  id uuid primary key default gen_random_uuid(),

  organizer_id uuid not null
    references public.profiles(id),

  name text not null
    check (char_length(trim(name)) > 0),

  description text not null
    check (char_length(trim(description)) > 0),

  image_url text not null default '',

  starts_at timestamptz not null,

  location text not null
    check (char_length(trim(location)) > 0),

  category text not null
    check (
      category in (
        'Music',
        'Technology',
        'Workshops',
        'Sports',
        'Other'
      )
    ),

  price numeric(10, 2) not null default 0
    check (price >= 0),

  capacity integer not null
    check (capacity > 0),

  status text not null default 'published'
    check (
      status in ('draft', 'published', 'cancelled', 'removed')
    ),

  created_at timestamptz not null default now()
);

-- Improve event lookup performance.
create index events_organizer_id_idx
  on public.events (organizer_id);

create index events_status_starts_at_idx
  on public.events (status, starts_at);

-- Enable access rules.
alter table public.events enable row level security;

revoke all on table public.events from anon, authenticated;

grant select, insert, delete
  on table public.events to authenticated;

-- Event ownership and IDs cannot be changed through the app.
grant update (
  name,
  description,
  image_url,
  starts_at,
  location,
  category,
  price,
  capacity,
  status
)
on table public.events to authenticated;

-- Signed-in users can browse published events.
-- Organizers can also see their own unpublished events.
create policy "Users can view published or own events"
on public.events
for select
to authenticated
using (
  status = 'published'
  or organizer_id = (select auth.uid())
);

-- Only organizer accounts can create events under their own ID.
create policy "Organizers can create their own events"
on public.events
for insert
to authenticated
with check (
  organizer_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.role = 'organizer'
  )
);

-- Organizers can edit only their own events.
create policy "Organizers can update their own events"
on public.events
for update
to authenticated
using (
  organizer_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.role = 'organizer'
  )
)
with check (
  organizer_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.role = 'organizer'
  )
);

-- Organizers can delete only their own events.
create policy "Organizers can delete their own events"
on public.events
for delete
to authenticated
using (
  organizer_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.role = 'organizer'
  )
);

commit;