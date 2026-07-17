# TimeoTalk Chat Architecture

This document describes the planned architecture for TimeoTalk, a Flutter chat
app inspired by Facebook Messenger. The filename uses `architure.md` because
that was the requested name.

## Current Project State

- Flutter app name: `timeotalk`
- Current app status: starter Flutter project
- Current architecture note: `md/design pattern.md`
- Current design pattern: MVVP, meaning Model, View, ViewModel, Provider
- Backend services planned: Supabase and Ably
- Local storage planned: SQLite
- Push planned: FCM/APNs, optionally through Ably Push

## Product Goal

Build a fast, reliable chat app with:

- Supabase Auth for user identity
- Supabase Postgres for long-term data
- Supabase Storage for media files
- Supabase Edge Functions for trusted backend operations
- Ably Realtime for low-latency messaging, typing, presence, and receipts
- SQLite for local message cache, offline queue, and instant UI
- Push notifications for closed-app message alerts

## Core Architecture

```text
Flutter App
  -> Local SQLite
  -> Supabase Auth
  -> Supabase Edge Functions
  -> Supabase Postgres
  -> Supabase Storage
  -> Ably Realtime
  -> FCM/APNs Push
```

### Responsibility Split

```text
Supabase Auth      = who the user is
Supabase Postgres  = source of truth for messages and conversations
Supabase Storage   = source of truth for uploaded media
Supabase Functions = trusted validation, token issuing, writes, fanout
Ably Realtime      = live message delivery while app is open
SQLite             = local cache, optimistic messages, offline queue
Push               = closed-app notification signal
```

## Important Principles

- Ably tokens are not sent inside message payloads.
- Ably tokens authenticate the realtime connection.
- Supabase JWT authenticates requests to the backend.
- Supabase remains the long-term source of truth.
- SQLite makes the UI instant, but is not the global source of truth.
- Push notifications tell the user something changed; they are not sync.
- Every sent message needs a `client_message_id` for idempotency.
- Do not trust `sender_id` from the client payload.
- Backend should derive sender identity from the authenticated connection or
  verified Supabase JWT.

## App Lifecycle

### App Open

```text
1. Restore Supabase session.
2. Open local SQLite.
3. Fetch latest conversation metadata from Supabase.
4. Fetch missed messages from Supabase using sync cursors.
5. Request Ably token from backend.
6. Connect to Ably.
7. Subscribe to required channels.
8. Flush queued outgoing SQLite messages.
9. Continue receiving live messages through Ably.
```

### App Backgrounded

```text
1. Keep local state in SQLite.
2. Realtime connection may continue briefly or be suspended by the OS.
3. Incoming messages may arrive through Ably if connection is still alive.
4. Push notifications should cover missed closed/background delivery.
5. Sync from Supabase when app returns to foreground.
```

### App Closed

```text
1. No active Ably realtime connection.
2. No Ably token refresh is needed.
3. Messages are persisted by backend to Supabase.
4. Backend sends push notifications to recipient devices.
5. User opens app from notification.
6. App requests a fresh Ably token.
7. App syncs missed messages from Supabase.
```

## Authentication And Authorization

### Supabase Auth

Supabase Auth provides the user session.

```text
Flutter -> Supabase Auth -> Supabase JWT
```

Use the Supabase JWT when calling:

- Edge Function to request Ably token
- Edge Function to upload or finalize attachments
- Edge Function to send server-authoritative messages, if needed
- Supabase database queries allowed by RLS

### Ably Token

Ably token is requested only when the app needs realtime.

```text
Flutter app opens
-> Flutter calls /ably-token with Supabase JWT
-> backend verifies user
-> backend checks conversation memberships
-> backend returns short-lived Ably token
-> Ably SDK connects with token
```

Recommended token lifetime:

```text
Normal chat: 30 minutes
High security: 10-15 minutes
Prototype: 60 minutes
Refresh: automatically before expiry through authCallback/authUrl
```

Example Ably capability:

```json
{
  "chat:conv_123": ["publish", "subscribe"],
  "typing:conv_123": ["publish", "subscribe"],
  "receipt:conv_123": ["publish", "subscribe"],
  "presence:conv_123": ["presence", "subscribe"],
  "user:user_456": ["subscribe"]
}
```

### Token Refresh

```text
App open:
  Ably SDK requests token on connect and before expiry.

App closed:
  No realtime token refresh.

App reopened:
  Restore Supabase session, then request a fresh Ably token.
```

## Message Delivery Model

### Status Definitions

```text
queued          = saved locally, waiting for network or token
sent_realtime   = published to Ably
delivered       = recipient device received the realtime event
read            = recipient opened or viewed the message
persisting      = backend is saving message to Supabase
persisted       = message is stored in Supabase with server id
failed          = message could not be sent or persisted
rejected        = backend rejected message for permission or policy
```

Important rule:

```text
delivered != persisted
read != persisted
```

Delivered means a device received the realtime event. Persisted means the
message is safely stored in Supabase.

## Message Send Flow

Recommended local-first realtime flow:

```text
1. Sender taps send.
2. App creates client_message_id.
3. App saves pending message to SQLite.
4. App publishes message.created to Ably.
5. Sender UI shows message immediately.
6. Recipient receives Ably event.
7. Recipient saves message to SQLite.
8. Recipient emits delivered/read receipt through Ably.
9. Backend receives or processes the message event.
10. Backend validates sender membership.
11. Backend inserts message into Supabase using client_message_id.
12. Backend publishes message.persisted with server_message_id.
13. Clients update SQLite record with server_message_id.
```

## Message Receive Flow

### Realtime Receive

```text
1. App is open and subscribed to chat:conversation_id.
2. Ably message.created arrives.
3. App checks client_message_id for dedupe.
4. App inserts or updates message in SQLite.
5. UI renders from SQLite.
6. App emits receipt.delivered.
7. If conversation is active and visible, app emits receipt.read.
```

### Closed-App Receive

```text
1. Backend persists message to Supabase.
2. Backend sends push notification.
3. User taps notification.
4. App opens.
5. App syncs missed messages from Supabase.
6. App connects to Ably for new live messages.
```

## Message Envelope

Send only chat data in the message payload. Do not include Ably token,
Supabase service key, or trusted permission flags.

### Text Message

```json
{
  "event": "message.created",
  "version": 1,
  "client_message_id": "01JABC123LOCALTEMP",
  "conversation_id": "conv_123",
  "sender_device_id": "device_abc",
  "type": "text",
  "body": {
    "text": "Hey, are you free later?"
  },
  "attachments": [],
  "reply_to": null,
  "client_created_at": "2026-07-16T22:10:30.000Z"
}
```

### Image Message

```json
{
  "event": "message.created",
  "version": 1,
  "client_message_id": "01JABC124LOCALTEMP",
  "conversation_id": "conv_123",
  "sender_device_id": "device_abc",
  "type": "image",
  "body": {
    "text": "Look at this"
  },
  "attachments": [
    {
      "client_attachment_id": "att_local_1",
      "storage_path": "chat/conv_123/01JABC124/image.jpg",
      "mime_type": "image/jpeg",
      "size_bytes": 248000,
      "width": 1200,
      "height": 900
    }
  ],
  "reply_to": null,
  "client_created_at": "2026-07-16T22:10:30.000Z"
}
```

### Persisted Event

```json
{
  "event": "message.persisted",
  "version": 1,
  "client_message_id": "01JABC123LOCALTEMP",
  "server_message_id": "msg_789",
  "conversation_id": "conv_123",
  "server_created_at": "2026-07-16T22:10:31.000Z"
}
```

### Rejected Event

```json
{
  "event": "message.rejected",
  "version": 1,
  "client_message_id": "01JABC123LOCALTEMP",
  "conversation_id": "conv_123",
  "reason": "not_a_member"
}
```

## Ably Channels

```text
chat:{conversation_id}
typing:{conversation_id}
receipt:{conversation_id}
presence:{conversation_id}
user:{user_id}
```

### Channel Responsibilities

```text
chat:{conversation_id}
  message.created
  message.persisted
  message.rejected
  message.deleted
  message.edited

typing:{conversation_id}
  typing.started
  typing.stopped

receipt:{conversation_id}
  receipt.delivered
  receipt.read

presence:{conversation_id}
  presence enter/update/leave

user:{user_id}
  token.refresh_required
  conversation.removed
  notification.control
```

## Supabase Database Schema

### profiles

```sql
create table profiles (
  id uuid primary key references auth.users(id),
  display_name text not null,
  avatar_url text,
  status text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### invitations

Invitations represent friend requests between users. A pending invitation can
be accepted, declined, canceled, or expired.

```sql
create table invitations (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references profiles(id),
  receiver_id uuid not null references profiles(id),
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
```

### contacts

Contacts represent accepted friend relationships. Store one row per owner so
each user can manage display preferences independently. When an invitation is
accepted, create two rows: one for the sender and one for the receiver.

```sql
create table contacts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id),
  contact_user_id uuid not null references profiles(id),
  created_from_invitation_id uuid references invitations(id),
  nickname text,
  favorite_at timestamptz,
  blocked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, contact_user_id),
  check (owner_id <> contact_user_id)
);
```

### conversations

```sql
create table conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('direct', 'group')),
  title text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

### conversation_members

```sql
create table conversation_members (
  conversation_id uuid not null references conversations(id),
  user_id uuid not null references profiles(id),
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  last_read_message_id uuid,
  muted_until timestamptz,
  primary key (conversation_id, user_id)
);
```

### messages

```sql
create table messages (
  id uuid primary key default gen_random_uuid(),
  client_message_id text not null,
  conversation_id uuid not null references conversations(id),
  sender_id uuid not null references profiles(id),
  sender_device_id text,
  type text not null check (type in ('text', 'image', 'video', 'file', 'audio')),
  body jsonb not null default '{}'::jsonb,
  reply_to_message_id uuid references messages(id),
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (conversation_id, client_message_id)
);
```

### attachments

```sql
create table attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid references messages(id),
  conversation_id uuid not null references conversations(id),
  uploaded_by uuid not null references profiles(id),
  storage_path text not null,
  mime_type text not null,
  size_bytes bigint not null,
  width integer,
  height integer,
  duration_ms integer,
  created_at timestamptz not null default now()
);
```

### message_receipts

```sql
create table message_receipts (
  message_id uuid not null references messages(id),
  user_id uuid not null references profiles(id),
  status text not null check (status in ('delivered', 'read')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, status)
);
```

### devices

```sql
create table devices (
  id text primary key,
  user_id uuid not null references profiles(id),
  platform text not null,
  push_token text,
  push_provider text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

## SQLite Local Schema

SQLite stores the UI-ready local state.

### local_conversations

```sql
create table local_conversations (
  id text primary key,
  type text not null,
  title text,
  last_message_preview text,
  last_server_message_id text,
  last_server_created_at text,
  last_synced_at text,
  unread_count integer not null default 0,
  updated_at text not null
);
```

### local_messages

```sql
create table local_messages (
  client_message_id text primary key,
  server_message_id text,
  conversation_id text not null,
  sender_id text not null,
  sender_device_id text,
  type text not null,
  body_json text not null,
  attachments_json text not null default '[]',
  local_status text not null,
  delivery_status text,
  persistence_status text not null,
  client_created_at text not null,
  server_created_at text,
  updated_at text not null
);
```

### outgoing_queue

```sql
create table outgoing_queue (
  id text primary key,
  client_message_id text not null,
  conversation_id text not null,
  payload_json text not null,
  attempt_count integer not null default 0,
  next_attempt_at text,
  last_error text,
  created_at text not null
);
```

### sync_cursors

```sql
create table sync_cursors (
  conversation_id text primary key,
  last_server_message_id text,
  last_server_created_at text,
  last_synced_at text
);
```

### local_contacts

```sql
create table local_contacts (
  owner_id text not null,
  contact_user_id text not null,
  display_name text not null,
  avatar_url text,
  nickname text,
  favorite_at text,
  blocked_at text,
  last_synced_at text,
  updated_at text not null,
  primary key (owner_id, contact_user_id)
);
```

### local_invitations

```sql
create table local_invitations (
  id text primary key,
  sender_id text not null,
  receiver_id text not null,
  status text not null,
  message text,
  created_at text not null,
  responded_at text,
  expires_at text,
  updated_at text not null
);
```

## Supabase Edge Functions

### ably-token

Purpose:

- Verify Supabase JWT.
- Load current user membership.
- Generate short-lived Ably token.
- Return channel capabilities.

Todo:

- [ ] Validate Supabase JWT.
- [ ] Reject disabled users.
- [ ] Query active conversation memberships.
- [ ] Generate channel-scoped Ably capabilities.
- [ ] Set token TTL to 30 minutes.
- [ ] Return token to Flutter.
- [ ] Add logging and rate limiting.

### persist-message

Purpose:

- Validate incoming message event.
- Verify sender membership.
- Insert message into Supabase.
- Publish `message.persisted` or `message.rejected`.

Todo:

- [ ] Validate event schema.
- [ ] Derive sender from trusted auth context.
- [ ] Verify conversation membership.
- [ ] Insert message using `client_message_id` as idempotency key.
- [ ] Persist attachments metadata.
- [ ] Publish `message.persisted`.
- [ ] Publish `message.rejected` when unauthorized.

### register-device

Purpose:

- Store device push tokens for closed-app notifications.

Todo:

- [ ] Accept device id, platform, push token, push provider.
- [ ] Verify Supabase JWT.
- [ ] Upsert device row.
- [ ] Update `last_seen_at`.

### send-invitation

Purpose:

- Create a friend invitation from the current user to another user.
- Prevent duplicate pending invitations.
- Prevent inviting users who are already contacts.

Todo:

- [ ] Verify Supabase JWT.
- [ ] Validate receiver user exists.
- [ ] Reject self-invitations.
- [ ] Reject duplicate pending invitations.
- [ ] Reject invitations between existing contacts.
- [ ] Insert `invitations` row.
- [ ] Notify receiver through `user:{user_id}` and push.

### respond-invitation

Purpose:

- Accept, decline, or cancel a friend invitation.
- Create contact rows when an invitation is accepted.

Todo:

- [ ] Verify Supabase JWT.
- [ ] Load invitation.
- [ ] Verify current user is allowed to respond.
- [ ] Update invitation status.
- [ ] On accept, create two `contacts` rows.
- [ ] Notify both users through `user:{user_id}`.

### send-push

Purpose:

- Send push notifications for messages when recipients are offline or not
  actively connected.

Todo:

- [ ] Find conversation recipients.
- [ ] Exclude sender device when appropriate.
- [ ] Check mute settings.
- [ ] Build notification payload.
- [ ] Send through FCM/APNs or Ably Push.
- [ ] Log delivery failures.

## Push Notifications

Push payload should be small and only contain routing data.

```json
{
  "type": "new_message",
  "conversation_id": "conv_123",
  "message_id": "msg_789"
}
```

When the user taps push:

```text
1. Open app.
2. Navigate to conversation.
3. Sync latest messages from Supabase.
4. Render from SQLite.
5. Connect to Ably for live messages.
```

Do not depend on push payload as the full message content.

## Media Upload Flow

```text
1. User picks image/video/file.
2. App compresses or prepares preview if needed.
3. App requests upload permission or signed path.
4. App uploads file to Supabase Storage.
5. App sends message.created with attachment metadata.
6. Backend validates storage path ownership.
7. Backend persists message and attachment rows.
8. Backend publishes message.persisted.
```

Todo:

- [ ] Create `chat-media` storage bucket.
- [ ] Add storage access policies.
- [ ] Add image compression.
- [ ] Add upload progress UI.
- [ ] Add retry for failed uploads.
- [ ] Add thumbnail handling.

## MVVP Flutter Structure

```text
lib/
  app/
    app.dart
    router.dart
    theme.dart
  core/
    config/
    database/
    network/
    realtime/
    storage/
    widgets/
  features/
    auth/
    chat/
    contacts/
    inbox/
    media/
    profile/
```

### Chat Feature

```text
lib/features/chat/
  models/
    chat_message_model.dart
    chat_receipt_model.dart
    chat_attachment_model.dart
  providers/
    chat_provider.dart
  repositories/
    chat_local_repository.dart
    chat_remote_repository.dart
    chat_realtime_repository.dart
  viewmodels/
    chat_view_model.dart
  views/
    chat_view.dart
    widgets/
      message_bubble.dart
      message_input.dart
      receipt_indicator.dart
      typing_indicator.dart
```

## Error Handling

### Network Offline

```text
1. Save outgoing message to SQLite.
2. Mark as queued.
3. Wait for network restore.
4. Refresh Ably token.
5. Publish queued messages.
```

### Token Expired

```text
1. Ably SDK calls auth callback.
2. Backend verifies Supabase session.
3. Backend returns fresh token.
4. If auth fails, disconnect realtime and show login state.
```

### Persistence Failed

```text
1. Keep message in SQLite.
2. Mark `persistence_status = pending` or `failed`.
3. Retry with backoff for transient failures.
4. Publish or process rejection for policy failures.
```

### Duplicate Message

```text
1. Use `client_message_id` for local dedupe.
2. Use unique constraint on `(conversation_id, client_message_id)`.
3. Merge realtime and Supabase sync records into one local message.
```

## Security Checklist

- [ ] Never store Ably API key in Flutter.
- [ ] Never store Supabase service role key in Flutter.
- [ ] Use short-lived Ably tokens.
- [ ] Scope Ably token capabilities to active conversations.
- [ ] Use `clientId` equal to Supabase user id.
- [ ] Verify conversation membership in backend before persistence.
- [ ] Enable Supabase RLS on user-facing tables.
- [ ] Restrict Storage paths by user and conversation membership.
- [ ] Rate limit token issuing.
- [ ] Rate limit message sends.
- [ ] Handle blocked users.
- [ ] Handle removed conversation members.
- [ ] Validate message payload size.
- [ ] Validate attachment MIME type and size.

## MVP Todo List

### Project Setup

- [ ] Add Flutter dependencies for Supabase.
- [ ] Add Flutter dependencies for Ably.
- [ ] Add Flutter dependencies for SQLite.
- [ ] Add environment configuration.
- [ ] Add app routing.
- [ ] Add theme foundation.
- [ ] Create MVVP feature folders.

### Auth

- [ ] Initialize Supabase client.
- [ ] Build login screen.
- [ ] Build signup screen.
- [ ] Build logout flow.
- [ ] Create profile after signup.
- [ ] Restore session on app start.

### Local Database

- [ ] Create SQLite database.
- [ ] Create local conversation table.
- [ ] Create local message table.
- [ ] Create local contacts table.
- [ ] Create local invitations table.
- [ ] Create outgoing queue table.
- [ ] Create sync cursor table.
- [ ] Add migrations.
- [ ] Add local repositories.

### Contacts And Invitations

- [ ] Build contacts list screen.
- [ ] Build user search or invite-by-identifier flow.
- [ ] Send friend invitation.
- [ ] Show incoming invitations.
- [ ] Show outgoing invitations.
- [ ] Accept invitation.
- [ ] Decline invitation.
- [ ] Cancel outgoing invitation.
- [ ] Create contact rows after accepted invitation.
- [ ] Sync contacts to SQLite.
- [ ] Sync invitations to SQLite.
- [ ] Start direct conversation from contact row.

### Realtime

- [ ] Create `/ably-token` backend function.
- [ ] Configure Ably auth callback in Flutter.
- [ ] Subscribe to conversation channels.
- [ ] Publish text messages.
- [ ] Receive text messages.
- [ ] Dedupe by `client_message_id`.
- [ ] Add reconnect handling.

### Messaging

- [ ] Build conversation list.
- [ ] Build chat screen.
- [ ] Build message bubble.
- [ ] Build message input.
- [ ] Save outgoing messages locally first.
- [ ] Show pending state.
- [ ] Show delivered state.
- [ ] Show read state.
- [ ] Show persistence failed state.
- [ ] Retry queued messages.

### Supabase Persistence

- [ ] Create database tables.
- [ ] Create contacts table.
- [ ] Create invitations table.
- [ ] Add RLS policies.
- [ ] Add message insert function or worker.
- [ ] Add invitation send/respond functions.
- [ ] Persist messages with idempotency.
- [ ] Persist receipts.
- [ ] Sync missed messages on app open.
- [ ] Sync missed messages on foreground resume.

### Push Notifications

- [ ] Register device push token.
- [ ] Store device token in Supabase.
- [ ] Send push after persisted messages.
- [ ] Route notification tap to conversation.
- [ ] Sync conversation after notification tap.
- [ ] Dedupe push with realtime messages.

### Media

- [ ] Create Supabase Storage bucket.
- [ ] Upload image attachment.
- [ ] Send image message.
- [ ] Show image preview.
- [ ] Persist attachment metadata.
- [ ] Download cached media.

### Production Readiness

- [ ] Add logging.
- [ ] Add crash reporting.
- [ ] Add analytics for message send latency.
- [ ] Add message retry metrics.
- [ ] Add moderation hooks.
- [ ] Add account deletion flow.
- [ ] Add privacy policy support.
- [ ] Add backup and restore plan.

## Testing Todo List

### Unit Tests

- [ ] Test message model parsing.
- [ ] Test local database inserts.
- [ ] Test sync cursor logic.
- [ ] Test outgoing queue retry logic.
- [ ] Test ViewModel send flow.
- [ ] Test ViewModel receive flow.

### Integration Tests

- [ ] Test Supabase auth restore.
- [ ] Test Ably token request.
- [ ] Test send message realtime path.
- [ ] Test Supabase persistence confirmation.
- [ ] Test duplicate message merge.
- [ ] Test offline queue flush.

### Manual QA

- [ ] Send message with both users online.
- [ ] Send message with recipient app closed.
- [ ] Open app from push notification.
- [ ] Send message while offline.
- [ ] Reopen app after token expiry.
- [ ] Remove user from group while connected.
- [ ] Verify removed user loses access after token refresh.
- [ ] Upload image on slow network.
- [ ] Force persistence failure and verify UI state.

## Open Decisions

- [ ] Decide whether backend persistence listens to Ably events or receives
      direct client calls.
- [ ] Decide whether to use Ably Push directly or FCM/APNs separately.
- [ ] Decide exact SQLite package.
- [ ] Decide exact Flutter state management package.
- [ ] Decide whether message ids use UUID, ULID, or database-generated UUID.
- [ ] Decide whether direct chat conversation ids are deterministic.
- [ ] Decide whether to add end-to-end encryption later.
