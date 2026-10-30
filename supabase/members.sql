-- Register the three travellers as members.
-- 1) First create the three users in Authentication → Users → "Add user" → "Create new user"
--    (email: <ID>@trip.example, password: the shared passphrase, Auto Confirm User: ON).
-- 2) Replace the e-mail addresses and names below, then run this in the SQL Editor.
--    Only the owner can confirm candidates and edit the schedule.

insert into public.members (user_id, name, role)
select id, v.name, v.role
from auth.users u
join (values
  ('ID1@trip.example', 'なまえ1', 'owner'),
  ('ID2@trip.example', 'なまえ2', 'member'),
  ('ID3@trip.example', 'なまえ3', 'member')
) as v(email, name, role) on lower(u.email) = lower(v.email)
on conflict (user_id) do update set name = excluded.name, role = excluded.role;

-- Check: should list exactly three rows.
select m.name, m.role, u.email from public.members m join auth.users u on u.id = m.user_id;
