-- Phase E: cross-device soft-delete for programs + real server-side account deletion.

-- ---------------------------------------------------------------------------
-- Programs were the only synced entity without a tombstone column. Without it,
-- a deleted program could never be observed-as-deleted by another device (the
-- pull reconciler keys deletes off `deleted_at`), so it would silently come back.
-- ---------------------------------------------------------------------------
alter table public.programs add column if not exists deleted_at timestamptz;

-- ---------------------------------------------------------------------------
-- Real account deletion.
--
-- Previously "delete account" only signed out and wiped the local store; the
-- user's cloud rows lived on forever. Deleting the row in auth.users cascades
-- (every table FKs auth.users with ON DELETE CASCADE) and removes all of it.
--
-- SECURITY DEFINER runs the delete as the function owner (which can touch
-- auth.users) while the body is hard-scoped to auth.uid(), so an authenticated
-- user can only ever delete THEIR OWN account — no service-role key on device.
-- ---------------------------------------------------------------------------
create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_current_user() from public, anon;
grant execute on function public.delete_current_user() to authenticated;
