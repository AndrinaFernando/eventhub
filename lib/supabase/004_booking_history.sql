begin;

-- Return only the signed-in user's bookings.
-- Event information remains available even if an event is unpublished.
create function public.get_my_bookings()
returns table (
  booking_id uuid,
  event_id uuid,
  event_name text,
  event_location text,
  starts_at timestamptz,
  event_status text,
  quantity integer,
  total_price numeric,
  booking_status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Please log in.';
  end if;

  return query
  select
    b.id,
    e.id,
    e.name,
    e.location,
    e.starts_at,
    e.status,
    b.quantity,
    b.total_price,
    b.status,
    b.created_at
  from public.bookings b
  join public.events e on e.id = b.event_id
  where b.user_id = auth.uid()
  order by b.created_at desc;
end;
$$;

revoke execute on function public.get_my_bookings()
  from public, anon, authenticated;

grant execute on function public.get_my_bookings()
  to authenticated;

-- Cancel an owned booking before the event starts.
create function public.cancel_booking(p_booking_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_event_id uuid;
  v_starts_at timestamptz;
  v_status text;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Please log in.';
  end if;

  select event_id
  into v_event_id
  from public.bookings
  where id = p_booking_id
    and user_id = v_user_id;

  if not found then
    raise exception 'Booking not found.';
  end if;

  -- Use the same event lock as the booking function.
  select starts_at
  into v_starts_at
  from public.events
  where id = v_event_id
  for update;

  select status
  into v_status
  from public.bookings
  where id = p_booking_id
    and user_id = v_user_id
  for update;

  if not found then
    raise exception 'Booking not found.';
  end if;

  -- Repeated cancellation requests have no extra effect.
  if v_status = 'cancelled' then
    return;
  end if;

  if v_starts_at <= clock_timestamp() then
    raise exception 'Bookings cannot be cancelled after the event starts.';
  end if;

  update public.bookings
  set status = 'cancelled'
  where id = p_booking_id
    and user_id = v_user_id;
end;
$$;

revoke execute on function public.cancel_booking(uuid)
  from public, anon, authenticated;

grant execute on function public.cancel_booking(uuid)
  to authenticated;

commit;