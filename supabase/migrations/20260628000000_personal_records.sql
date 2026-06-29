-- Personal records + program days

create table if not exists public.personal_records (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_id uuid not null,
  type text not null,
  value double precision not null,
  achieved_at timestamptz not null,
  session_id uuid not null,
  set_id uuid not null,
  created_at timestamptz not null default now()
);

alter table public.personal_records enable row level security;

create policy "Users manage own personal records"
  on public.personal_records for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.program_days (
  id uuid primary key,
  program_id uuid not null references public.programs (id) on delete cascade,
  user_id uuid references auth.users (id) on delete cascade,
  week_index int not null default 0,
  day_of_week int not null,
  routine_id uuid,
  sort_order int not null default 0
);

alter table public.program_days enable row level security;

create policy "Users read suggested and own program days"
  on public.program_days for select
  using (
    exists (
      select 1 from public.programs p
      where p.id = program_id
      and (p.is_suggested = true or auth.uid() = p.user_id)
    )
  );

create policy "Users manage own program days"
  on public.program_days for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
