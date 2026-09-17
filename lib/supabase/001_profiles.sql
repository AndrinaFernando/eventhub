begin;

-- Store profile information.
-- Supabase Auth separately manages emails and passwords.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text not null default '',
  role text not null default 'attendee'
    check (role in ('attendee', 'organizer')),
  created_at timestamptz not null default now()
);

-- Protect profile records.
alter table public.profiles enable row level security;

-- Give app users only the permissions they need.
revoke all on table public.profiles from anon, authenticated;

grant select on table public.profiles to authenticated;

-- Users can edit personal details, but cannot change their role.
grant update (full_name, phone)
  on table public.profiles to authenticated;

create policy "Users can view their own profile"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy "Users can update their own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

-- Automatically create a profile when someone registers.
create function public.handle_new_eventhub_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  );

  return new;
end;
$$;

-- This function is used by the database trigger, not called by the app.
revoke execute on function public.handle_new_eventhub_user()
  from public, anon, authenticated;

create trigger on_eventhub_user_created
after insert on auth.users
for each row
execute function public.handle_new_eventhub_user();

-- Also create profiles for any existing app accounts.
insert into public.profiles (id, full_name)
select
  id,
  coalesce(raw_user_meta_data ->> 'full_name', '')
from auth.users
on conflict (id) do nothing;

commit;