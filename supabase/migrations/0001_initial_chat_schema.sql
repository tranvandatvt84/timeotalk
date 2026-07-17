create extension if not exists "pgcrypto";

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_url text,
  status text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('direct', 'group')),
  title text,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table conversation_members (
  conversation_id uuid not null references conversations(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  last_read_message_id uuid,
  muted_until timestamptz,
  primary key (conversation_id, user_id)
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  client_message_id text not null,
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete restrict,
  sender_device_id text,
  type text not null check (type in ('text', 'image', 'video', 'file', 'audio')),
  body jsonb not null default '{}'::jsonb,
  reply_to_message_id uuid references messages(id) on delete set null,
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (conversation_id, client_message_id)
);

alter table conversation_members
add constraint conversation_members_last_read_message_id_fkey
foreign key (last_read_message_id) references messages(id) on delete set null;

create table attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid references messages(id) on delete cascade,
  conversation_id uuid not null references conversations(id) on delete cascade,
  uploaded_by uuid not null references profiles(id) on delete restrict,
  storage_path text not null,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes > 0),
  width integer,
  height integer,
  duration_ms integer,
  created_at timestamptz not null default now()
);

create table message_receipts (
  message_id uuid not null references messages(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  status text not null check (status in ('delivered', 'read')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, status)
);

create table devices (
  id text primary key,
  user_id uuid not null references profiles(id) on delete cascade,
  platform text not null,
  push_token text,
  push_provider text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index messages_conversation_created_at_idx
on messages (conversation_id, created_at desc);

create index conversation_members_user_id_idx
on conversation_members (user_id);

create index attachments_conversation_id_idx
on attachments (conversation_id);

create index devices_user_id_idx
on devices (user_id);
