-- Cultural Storyteller 2.0 — Supabase Schema (idempotent)

do $$
begin
  if not exists (select 1 from pg_type where typname = 'story_status') then
    create type story_status as enum (
      'draft',
      'subtopics_generating',
      'subtopics_ready',
      'story_generating',
      'story_ready',
      'audio_script_ready',
      'segmenting',
      'segmented',
      'audio_render_queued',
      'audio_rendering',
      'audio_uploading',
      'complete',
      'failed'
    );
  end if;
end $$;

alter type story_status add value if not exists 'subtopics_generating';
alter type story_status add value if not exists 'subtopics_ready';
alter type story_status add value if not exists 'story_generating';
alter type story_status add value if not exists 'story_ready';
alter type story_status add value if not exists 'audio_script_ready';
alter type story_status add value if not exists 'segmenting';
alter type story_status add value if not exists 'segmented';
alter type story_status add value if not exists 'audio_render_queued';
alter type story_status add value if not exists 'audio_rendering';
alter type story_status add value if not exists 'audio_uploading';
alter type story_status add value if not exists 'complete';
alter type story_status add value if not exists 'failed';

create table if not exists stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  topic text not null,
  subtopic text,
  language text not null default 'en',
  tone text not null default 'educational',
  status story_status not null default 'draft',
  title text,
  story_markdown text,
  audio_script text,
  audio_url text,
  audio_duration_seconds int,
  failed_step text,
  error_code text,
  last_error text,
  retryable boolean default true,
  render_job_id uuid,
  render_hash text,
  outputs jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table stories add column if not exists topic text;
alter table stories add column if not exists subtopic text;
alter table stories add column if not exists language text not null default 'en';
alter table stories add column if not exists tone text not null default 'educational';
alter table stories add column if not exists status story_status not null default 'draft';
alter table stories add column if not exists title text;
alter table stories add column if not exists story_markdown text;
alter table stories add column if not exists audio_script text;
alter table stories add column if not exists audio_url text;
alter table stories add column if not exists audio_duration_seconds int;
alter table stories add column if not exists failed_step text;
alter table stories add column if not exists error_code text;
alter table stories add column if not exists last_error text;
alter table stories add column if not exists retryable boolean default true;
alter table stories add column if not exists render_job_id uuid;
alter table stories add column if not exists render_hash text;
alter table stories add column if not exists outputs jsonb default '{}'::jsonb;
alter table stories add column if not exists created_at timestamptz default now();
alter table stories add column if not exists updated_at timestamptz default now();

create index if not exists idx_stories_user on stories(user_id);
create index if not exists idx_stories_status on stories(status);
create index if not exists idx_stories_created on stories(created_at desc);

-- Auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists stories_updated_at on stories;
create trigger stories_updated_at
  before update on stories
  for each row execute function update_updated_at();

-- Event log for debugging and analytics
create table if not exists story_events (
  id uuid primary key default gen_random_uuid(),
  story_id uuid references stories(id) on delete cascade,
  event_type text not null,
  payload jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create index if not exists idx_story_events_story on story_events(story_id);

-- Storage bucket (create via Supabase dashboard or API)
-- insert into storage.buckets (id, name, public) values ('story-audio', 'story-audio', true);

-- RLS policies
alter table stories enable row level security;

drop policy if exists "Users can view own stories" on stories;
create policy "Users can view own stories"
  on stories for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own stories" on stories;
create policy "Users can insert own stories"
  on stories for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own stories" on stories;
create policy "Users can update own stories"
  on stories for update
  using (auth.uid() = user_id);

drop policy if exists "Users can delete own stories" on stories;
create policy "Users can delete own stories"
  on stories for delete
  using (auth.uid() = user_id);
