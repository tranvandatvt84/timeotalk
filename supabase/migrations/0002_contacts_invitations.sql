create table invitations (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references profiles(id) on delete cascade,
  receiver_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'canceled', 'expired')),
  message text,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  expires_at timestamptz,
  check (sender_id <> receiver_id)
);

create unique index invitations_one_pending_pair
on invitations (
  least(sender_id, receiver_id),
  greatest(sender_id, receiver_id)
)
where status = 'pending';

create index invitations_receiver_id_status_idx
on invitations (receiver_id, status);

create index invitations_sender_id_status_idx
on invitations (sender_id, status);

create table contacts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  contact_user_id uuid not null references profiles(id) on delete cascade,
  created_from_invitation_id uuid references invitations(id) on delete set null,
  nickname text,
  favorite_at timestamptz,
  blocked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, contact_user_id),
  check (owner_id <> contact_user_id)
);

create index contacts_owner_id_idx
on contacts (owner_id);

create index contacts_contact_user_id_idx
on contacts (contact_user_id);
