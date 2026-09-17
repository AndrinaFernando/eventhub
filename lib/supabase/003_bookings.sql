begin;

-- Store bookings.
create table public.bookings (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id),

  event_id uuid not null
    references public.events(id),

  contact_name text not null
    check (char_length(trim(contact_name)) > 0),

  contact_email text not null,

  quantity integer not null
    check (quantity > 0),

  total_price numeric(18, 2) not null
    check (total_price >= 0),

  status text not null default 'confirmed'
    check (status in ('confirmed', 'cancelled')),

  created_at timestamptz not null default now()
);

create index bookings_user_id_idx
  on public.bookings (user_id);

create index bookings_event_status_idx
  on public.bookings (event_id, status);

alter table public.bookings enable row level security;

-- App users cannot directly insert or change bookings.
-- They must use the checked database functions.
revoke all on table public.bookings from anon, authenticated;

grant select on table public.bookings to authenticated;

-- Users can view their own bookings.
-- Organizers can view bookings for their events.
create policy "Users and organizers can view relevant bookings"
on public.bookings
for select
to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1
    from public.events
    where events.id = bookings.event_id
      and events.organizer_id = (select auth.uid())
  )
);

-- Check availability and create a booking in one transaction.
create function public.book_event(
  p_event_id uuid,
  p_quantity integer,
  p_contact_name text,
  p_contact_email text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_event public.events%rowtype;
  v_booked bigint;
  v_booking_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Please log in before booking.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Enter a positive ticket quantity.';
  end if;

  if p_contact_name is null
     or char_length(trim(p_contact_name)) = 0 then
    raise exception 'Enter your contact name.';
  end if;

  if p_contact_email is null
     or trim(p_contact_email)
        !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then
    raise exception 'Enter a valid contact email.';
  end if;

  -- Lock this event until the booking transaction finishes.
  select *
  into v_event
  from public.events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Event not found.';
  end if;

  if v_event.status <> 'published' then
    raise exception 'This event is not available for booking.';
  end if;

  if v_event.starts_at <= clock_timestamp() then
    raise exception 'This event has already started.';
  end if;

  select coalesce(sum(quantity), 0)
  into v_booked
  from public.bookings
  where event_id = p_event_id
    and status = 'confirmed';

  if p_quantity > v_event.capacity - v_booked then
    raise exception 'Not enough seats are available.';
  end if;

  insert into public.bookings (
    user_id,
    event_id,
    contact_name,
    contact_email,
    quantity,
    total_price
  )
  values (
    v_user_id,
    p_event_id,
    trim(p_contact_name),
    trim(p_contact_email),
    p_quantity,
    v_event.price * p_quantity
  )
  returning id into v_booking_id;

  return v_booking_id;
end;
$$;

revoke execute on function public.book_event(uuid, integer, text, text)
  from public, anon, authenticated;

grant execute on function public.book_event(uuid, integer, text, text)
  to authenticated;

-- Return the remaining seats without exposing other users' bookings.
create function public.get_available_seats(p_event_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.events%rowtype;
  v_booked bigint;
begin
  if auth.uid() is null then
    raise exception 'Please log in.';
  end if;

  select *
  into v_event
  from public.events
  where id = p_event_id;

  if not found then
    raise exception 'Event not found.';
  end if;

  if v_event.status <> 'published'
     or v_event.starts_at <= clock_timestamp() then
    return 0;
  end if;

  select coalesce(sum(quantity), 0)
  into v_booked
  from public.bookings
  where event_id = p_event_id
    and status = 'confirmed';

  return greatest(v_event.capacity - v_booked, 0)::integer;
end;
$$;

revoke execute on function public.get_available_seats(uuid)
  from public, anon, authenticated;

grant execute on function public.get_available_seats(uuid)
  to authenticated;

-- Prevent organizers from reducing capacity below confirmed bookings.
create function public.check_event_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booked bigint;
begin
  select coalesce(sum(quantity), 0)
  into v_booked
  from public.bookings
  where event_id = new.id
    and status = 'confirmed';

  if new.capacity < v_booked then
    raise exception
      'Capacity cannot be less than the number of booked seats.';
  end if;

  return new;
end;
$$;

revoke execute on function public.check_event_capacity()
  from public, anon, authenticated;

create trigger check_capacity_before_event_update
before update of capacity on public.events
for each row
execute function public.check_event_capacity();

commit;