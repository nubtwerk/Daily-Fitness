-- DailyFitness initial schema
-- Apply via: supabase db push

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Exercises (seed + user custom)
-- ---------------------------------------------------------------------------
create table if not exists public.exercises (
  id uuid primary key,
  user_id uuid references auth.users (id) on delete cascade,
  name text not null,
  category text not null check (category in ('strength', 'mobility', 'flexibility', 'yoga', 'cardio')),
  primary_muscles text[] not null default '{}',
  equipment text[] not null default '{}',
  image_url text,
  is_custom boolean not null default false,
  logging_fields text not null default 'weightReps',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_exercises_user on public.exercises (user_id);
create index if not exists idx_exercises_category on public.exercises (category);

alter table public.exercises enable row level security;

create policy "Users read seed and own exercises"
  on public.exercises for select
  using (user_id is null or auth.uid() = user_id);

create policy "Users manage own custom exercises"
  on public.exercises for insert
  with check (auth.uid() = user_id and is_custom = true);

create policy "Users update own custom exercises"
  on public.exercises for update
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Routines
-- ---------------------------------------------------------------------------
create table if not exists public.routines (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.routines enable row level security;

create policy "Users manage own routines"
  on public.routines for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.routine_exercises (
  id uuid primary key,
  routine_id uuid not null references public.routines (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  sort_order int not null,
  exercise_id uuid not null,
  target_sets int not null default 3,
  target_reps_min int,
  target_reps_max int,
  target_duration_seconds int,
  rest_seconds int not null default 90,
  superset_group_id uuid,
  progression_enabled boolean not null default true,
  note text
);

alter table public.routine_exercises enable row level security;

create policy "Users manage own routine exercises"
  on public.routine_exercises for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Workout sessions
-- ---------------------------------------------------------------------------
create table if not exists public.workout_sessions (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  routine_id uuid,
  program_day_id uuid,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists idx_workout_sessions_user_started
  on public.workout_sessions (user_id, started_at desc);

alter table public.workout_sessions enable row level security;

create policy "Users manage own sessions"
  on public.workout_sessions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.workout_sets (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  exercise_id uuid not null,
  set_number int not null,
  set_type text not null default 'normal',
  weight_kg double precision,
  reps int,
  duration_seconds int,
  hold_seconds int,
  side text,
  rir int,
  completed_at timestamptz,
  is_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_workout_sets_session on public.workout_sets (session_id);
create index if not exists idx_workout_sets_exercise on public.workout_sets (user_id, exercise_id, completed_at desc);

alter table public.workout_sets enable row level security;

create policy "Users manage own sets"
  on public.workout_sets for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Programs
-- ---------------------------------------------------------------------------
create table if not exists public.programs (
  id uuid primary key,
  user_id uuid references auth.users (id) on delete cascade,
  name text not null,
  category text not null,
  is_suggested boolean not null default false,
  source_template_id uuid,
  weeks int,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.programs enable row level security;

create policy "Users read suggested and own programs"
  on public.programs for select
  using (is_suggested = true or auth.uid() = user_id);

create policy "Users manage own programs"
  on public.programs for insert
  with check (auth.uid() = user_id and is_suggested = false);

create policy "Users update own programs"
  on public.programs for update
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- User preferences
-- ---------------------------------------------------------------------------
create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  use_pounds boolean not null default false,
  default_rest_seconds int not null default 90,
  rir_enabled boolean not null default false,
  live_activities_enabled boolean not null default true,
  rest_end_notification_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.user_preferences enable row level security;

create policy "Users manage own preferences"
  on public.user_preferences for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
