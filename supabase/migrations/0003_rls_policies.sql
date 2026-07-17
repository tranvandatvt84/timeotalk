create or replace function public.is_conversation_member(
  target_conversation_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from conversation_members
    where conversation_id = target_conversation_id
      and user_id = auth.uid()
      and left_at is null
  );
$$;

grant execute on function public.is_conversation_member(uuid) to authenticated;

alter table profiles enable row level security;
alter table conversations enable row level security;
alter table conversation_members enable row level security;
alter table messages enable row level security;
alter table attachments enable row level security;
alter table message_receipts enable row level security;
alter table devices enable row level security;
alter table contacts enable row level security;
alter table invitations enable row level security;

create policy "users can read own profile"
on profiles for select
to authenticated
using (id = auth.uid());

create policy "users can read contact profiles"
on profiles for select
to authenticated
using (
  exists (
    select 1
    from contacts
    where owner_id = auth.uid()
      and contact_user_id = profiles.id
  )
);

create policy "users can insert own profile"
on profiles for insert
to authenticated
with check (id = auth.uid());

create policy "users can update own profile"
on profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "conversation members can read conversations"
on conversations for select
to authenticated
using (public.is_conversation_member(id));

create policy "users can create conversations"
on conversations for insert
to authenticated
with check (created_by = auth.uid());

create policy "conversation members can read memberships"
on conversation_members for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_conversation_member(conversation_id)
);

create policy "conversation members can read messages"
on messages for select
to authenticated
using (public.is_conversation_member(conversation_id));

create policy "conversation members can insert own messages"
on messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and public.is_conversation_member(conversation_id)
);

create policy "senders can update own messages"
on messages for update
to authenticated
using (
  sender_id = auth.uid()
  and public.is_conversation_member(conversation_id)
)
with check (
  sender_id = auth.uid()
  and public.is_conversation_member(conversation_id)
);

create policy "conversation members can read attachments"
on attachments for select
to authenticated
using (public.is_conversation_member(conversation_id));

create policy "conversation members can insert own attachments"
on attachments for insert
to authenticated
with check (
  uploaded_by = auth.uid()
  and public.is_conversation_member(conversation_id)
);

create policy "conversation members can read receipts"
on message_receipts for select
to authenticated
using (
  exists (
    select 1
    from messages
    where messages.id = message_receipts.message_id
      and public.is_conversation_member(messages.conversation_id)
  )
);

create policy "conversation members can insert own receipts"
on message_receipts for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from messages
    where messages.id = message_receipts.message_id
      and public.is_conversation_member(messages.conversation_id)
  )
);

create policy "users can read own devices"
on devices for select
to authenticated
using (user_id = auth.uid());

create policy "users can insert own devices"
on devices for insert
to authenticated
with check (user_id = auth.uid());

create policy "users can update own devices"
on devices for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "users can delete own devices"
on devices for delete
to authenticated
using (user_id = auth.uid());

create policy "users can read own contacts"
on contacts for select
to authenticated
using (owner_id = auth.uid());

create policy "users can insert own contacts"
on contacts for insert
to authenticated
with check (owner_id = auth.uid());

create policy "users can update own contacts"
on contacts for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "users can delete own contacts"
on contacts for delete
to authenticated
using (owner_id = auth.uid());

create policy "users can read sent invitations"
on invitations for select
to authenticated
using (sender_id = auth.uid());

create policy "users can read received invitations"
on invitations for select
to authenticated
using (receiver_id = auth.uid());

create policy "users can create sent invitations"
on invitations for insert
to authenticated
with check (
  sender_id = auth.uid()
  and receiver_id <> auth.uid()
  and status = 'pending'
);

create policy "users can manage sent invitations"
on invitations for update
to authenticated
using (sender_id = auth.uid())
with check (
  sender_id = auth.uid()
  and status in ('pending', 'canceled')
);

create policy "users can respond to received invitations"
on invitations for update
to authenticated
using (receiver_id = auth.uid())
with check (
  receiver_id = auth.uid()
  and status in ('accepted', 'declined')
);
