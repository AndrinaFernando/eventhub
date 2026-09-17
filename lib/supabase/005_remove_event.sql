begin;

create function public.remove_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_event public.events%rowtype;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Please log in.';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = v_user_id
      and role = 'organizer'
  ) then
    raise exception 'Only organizers can remove events.';
  end if;

  -- Use the same event lock as booking and cancellation.
  select *
  into v_event
  from public.events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Event not found.';
  end if;

  if v_event.organizer_id <> v_user_id then
    raise exception 'You can remove only your own events.';
  end if;

  if v_event.status = 'removed' then
    return;
  end if;

  if v_event.starts_at <= clock_timestamp() then
    raise exception 'Past or started events are kept for history.';
  end if;

  update public.events
  set status = 'removed'
  where id = p_event_id;

  update public.bookings
  set status = 'cancelled'
  where event_id = p_event_id
    and status = 'confirmed';
end;
$$;

revoke execute on function public.remove_event(uuid)
  from public, anon, authenticated;

grant execute on function public.remove_event(uuid)
  to authenticated;

commit;