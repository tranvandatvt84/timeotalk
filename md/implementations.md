# TimeoTalk Chat App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the TimeoTalk Flutter chat app with Supabase as the source of truth, Ably for realtime messaging, SQLite for local-first cache/queue, contacts/invitations for friend discovery, and push notifications for closed-app alerts.

**Architecture:** The app follows MVVP: View, ViewModel, Provider, Model. Supabase owns auth, database, storage, and trusted backend functions. Ably owns live delivery while the app is open; SQLite owns local state and offline queue; push only notifies users to reopen and sync.

**Tech Stack:** Flutter, Dart SDK `^3.11.5`, Supabase Auth/Postgres/Storage/Edge Functions, Ably Realtime, SQLite, FCM/APNs push, MVVP feature folders.

## Global Constraints

- Keep Ably API keys out of Flutter code.
- Keep Supabase service role keys out of Flutter code.
- Use short-lived Ably tokens with 30 minute TTL for normal chat.
- Use `client_message_id` for all outgoing message idempotency.
- Treat Supabase Postgres as the long-term source of truth.
- Treat SQLite as local cache and offline queue only.
- Treat push notifications as notification/routing signals only.
- Do not treat `delivered` or `read` as proof that a message is persisted.
- Do not trust `sender_id` from client payloads.
- Follow `md/design pattern.md` for MVVP structure.
- Keep backend tables aligned with `md/architure.md`.

---

## Planned File Structure

### Flutter App

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
    config/app_config.dart
    database/app_database.dart
    database/database_migrations.dart
    network/supabase_client_provider.dart
    realtime/ably_client_provider.dart
    realtime/realtime_event.dart
    storage/media_storage_repository.dart
    widgets/app_error_view.dart
    widgets/app_loading_view.dart
  features/
    auth/
      models/auth_user_model.dart
      providers/auth_provider.dart
      repositories/auth_repository.dart
      viewmodels/auth_view_model.dart
      views/login_view.dart
      views/signup_view.dart
    contacts/
      models/contact_model.dart
      models/invitation_model.dart
      providers/contacts_provider.dart
      repositories/contacts_repository.dart
      viewmodels/contacts_view_model.dart
      views/contacts_view.dart
      views/invitations_view.dart
    inbox/
      models/conversation_model.dart
      providers/inbox_provider.dart
      repositories/inbox_repository.dart
      viewmodels/inbox_view_model.dart
      views/inbox_view.dart
    chat/
      models/chat_attachment_model.dart
      models/chat_message_model.dart
      models/chat_receipt_model.dart
      providers/chat_provider.dart
      repositories/chat_local_repository.dart
      repositories/chat_remote_repository.dart
      repositories/chat_realtime_repository.dart
      viewmodels/chat_view_model.dart
      views/chat_view.dart
      views/widgets/message_bubble.dart
      views/widgets/message_input.dart
      views/widgets/receipt_indicator.dart
      views/widgets/typing_indicator.dart
    media/
      models/media_upload_model.dart
      repositories/media_repository.dart
      viewmodels/media_upload_view_model.dart
    profile/
      models/profile_model.dart
      providers/profile_provider.dart
      repositories/profile_repository.dart
      viewmodels/profile_view_model.dart
      views/profile_view.dart
```

### Supabase

```text
supabase/
  config.toml
  migrations/
    0001_initial_chat_schema.sql
    0002_contacts_invitations.sql
    0003_rls_policies.sql
    0004_storage_policies.sql
  functions/
    ably-token/index.ts
    persist-message/index.ts
    register-device/index.ts
    send-invitation/index.ts
    respond-invitation/index.ts
    send-push/index.ts
```

### Tests

```text
test/
  core/database/app_database_test.dart
  features/auth/auth_view_model_test.dart
  features/contacts/contacts_view_model_test.dart
  features/inbox/inbox_view_model_test.dart
  features/chat/chat_message_model_test.dart
  features/chat/chat_view_model_test.dart
  features/chat/outgoing_queue_test.dart
  features/chat/realtime_event_test.dart
```

---

## Task 1: Project Dependencies And Configuration

**Files:**

- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Create: `lib/app/app.dart`
- Create: `lib/app/router.dart`
- Create: `lib/app/theme.dart`
- Create: `lib/core/config/app_config.dart`

**Interfaces:**

- Produces: `AppConfig.fromEnvironment()`
- Produces: `TimeoTalkApp`
- Produces: `AppRouter`

- [x] Add dependencies to `pubspec.yaml`.

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  ably_flutter: ^1.2.44
  sqflite: ^2.4.0
  path: ^1.9.0
  uuid: ^4.5.0
  flutter_secure_storage: ^9.2.0
  image_picker: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  mocktail: ^1.0.4
```

- [x] Run dependency install.

```bash
flutter pub get
```

Expected: command exits `0` and `pubspec.lock` updates.

- [x] Create `AppConfig` with compile-time environment values.

```dart
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.ablyTokenFunctionName,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String ablyTokenFunctionName;

  static AppConfig fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      ablyTokenFunctionName: 'ably-token',
    );
  }
}
```

- [x] Move app shell out of `main.dart` into `TimeoTalkApp`.
- [x] Initialize Supabase before `runApp`.
- [x] Add a basic router with login and inbox placeholders.
- [x] Run formatting.

```bash
dart format lib test
```

Expected: command exits `0`.

- [x] Run analyzer.

```bash
flutter analyze
```

Expected: command exits `0`.

- [x] Commit.

Status: committed in the initial project commit.

```bash
git add pubspec.yaml pubspec.lock lib
git commit -m "chore: configure app foundation"
```

---

## Task 2: Supabase Database Schema

**Files:**

- Create: `supabase/migrations/0001_initial_chat_schema.sql`
- Create: `supabase/migrations/0002_contacts_invitations.sql`
- Create: `supabase/migrations/0003_rls_policies.sql`
- Create: `supabase/config.toml`

**Interfaces:**

- Produces backend tables: `profiles`, `conversations`, `conversation_members`, `messages`, `attachments`, `message_receipts`, `devices`, `contacts`, `invitations`
- Produces RLS policies that allow users to read and write only their own permitted rows

- [x] Create `0001_initial_chat_schema.sql` with `profiles`, `conversations`, `conversation_members`, `messages`, `attachments`, `message_receipts`, and `devices` from `md/architure.md`.
- [x] Create `0002_contacts_invitations.sql` with `contacts` and `invitations` from `md/architure.md`.
- [x] Add indexes for message pagination.

```sql
create index messages_conversation_created_at_idx
on messages (conversation_id, created_at desc);

create index conversation_members_user_id_idx
on conversation_members (user_id);

create index contacts_owner_id_idx
on contacts (owner_id);

create index invitations_receiver_id_status_idx
on invitations (receiver_id, status);
```

- [x] Add RLS enabling statements.

```sql
alter table profiles enable row level security;
alter table conversations enable row level security;
alter table conversation_members enable row level security;
alter table messages enable row level security;
alter table attachments enable row level security;
alter table message_receipts enable row level security;
alter table devices enable row level security;
alter table contacts enable row level security;
alter table invitations enable row level security;
```

- [x] Add read policies for conversation members.
- [x] Add insert/update policies for own device rows.
- [x] Add read/write policies for own contacts and invitations.
- [x] Run local Supabase migration.

Status: completed manually. `supabase db reset` applied migrations
`0001_initial_chat_schema.sql`, `0002_contacts_invitations.sql`, and
`0003_rls_policies.sql`.

```bash
supabase db reset
```

Expected: migrations apply without SQL errors.

- [x] Commit.

Status: committed in the initial project commit.

```bash
git add supabase
git commit -m "feat: add supabase chat schema"
```

---

## Task 3: Local SQLite Database

**Files:**

- Create: `lib/core/database/app_database.dart`
- Create: `lib/core/database/database_migrations.dart`
- Create: `test/core/database/app_database_test.dart`

**Interfaces:**

- Produces: `AppDatabase.open()`
- Produces: `AppDatabase.close()`
- Produces local tables: `local_conversations`, `local_messages`, `local_contacts`, `local_invitations`, `outgoing_queue`, `sync_cursors`

- [x] Write failing test that opens the database and verifies every local table exists.
- [x] Implement migration version `1`.

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

- [x] Add the remaining local table statements from `md/architure.md`.
- [x] Add helper query `Future<bool> tableExists(String tableName)` for tests.
- [x] Run the database test.

Status: completed with `sqflite_common_ffi` added as a dev dependency so the
SQLite database can be opened in local Flutter unit tests.

```bash
flutter test test/core/database/app_database_test.dart
```

Expected: all tests pass.

- [x] Commit.

Status: committed in the initial project commit.

```bash
git add lib/core/database test/core/database
git commit -m "feat: add local sqlite database"
```

---

## Task 4: Domain Models

**Files:**

- Create: `lib/features/profile/models/profile_model.dart`
- Create: `lib/features/contacts/models/contact_model.dart`
- Create: `lib/features/contacts/models/invitation_model.dart`
- Create: `lib/features/inbox/models/conversation_model.dart`
- Create: `lib/features/chat/models/chat_message_model.dart`
- Create: `lib/features/chat/models/chat_attachment_model.dart`
- Create: `lib/features/chat/models/chat_receipt_model.dart`
- Create: `test/features/chat/chat_message_model_test.dart`

**Interfaces:**

- Produces: immutable model classes with `fromJson`, `toJson`, and `copyWith`
- Produces: `ChatMessageModel.clientMessageId`
- Produces: `ChatMessageModel.persistenceStatus`

- [x] Write `ChatMessageModel` parsing tests for `message.created`, `message.persisted`, and local SQLite rows.
- [x] Implement `ChatMessageModel`.
- [x] Implement `ChatAttachmentModel`.
- [x] Implement `ChatReceiptModel`.
- [x] Implement `ProfileModel`, `ContactModel`, `InvitationModel`, and `ConversationModel`.
- [x] Run model tests.

```bash
flutter test test/features/chat/chat_message_model_test.dart
```

Expected: all tests pass.

- [x] Commit.

Status: committed in the initial project commit.

```bash
git add lib/features test/features
git commit -m "feat: add chat domain models"
```

---

## Task 5: Auth And Profile Foundation

**Files:**

- Create: `lib/core/network/supabase_client_provider.dart`
- Create: `lib/features/auth/repositories/auth_repository.dart`
- Create: `lib/features/auth/viewmodels/auth_view_model.dart`
- Create: `lib/features/auth/views/login_view.dart`
- Create: `lib/features/auth/views/signup_view.dart`
- Create: `lib/features/profile/repositories/profile_repository.dart`
- Create: `test/features/auth/auth_view_model_test.dart`

**Interfaces:**

- Produces: `AuthRepository.currentUser()`
- Produces: `AuthRepository.signIn(email, password)`
- Produces: `AuthRepository.signUp(email, password, displayName)`
- Produces: `AuthRepository.signInWithGoogle()`
- Produces: `AuthRepository.signInWithApple()`
- Produces: `AuthRepository.signOut()`
- Produces: `ProfileRepository.upsertCurrentUserProfile()`

- [x] Write ViewModel tests for signed-out, sign-in success, and sign-in failure states.
- [x] Write ViewModel tests for Google OAuth success and Apple OAuth failure states.
- [x] Implement `SupabaseClientProvider`.
- [x] Implement `AuthRepository`.
- [x] Implement Supabase Google OAuth launch through `AuthRepository` and `AuthViewModel`.
- [x] Implement Supabase Apple OAuth launch through `AuthRepository` and `AuthViewModel`.
- [x] Support optional `AUTH_REDIRECT_URI` for mobile OAuth callbacks.
- [x] Implement profile upsert after signup.
- [x] Build simple login and signup views.
- [x] Add Google and Apple sign-in buttons to login and signup views.
- [x] Wire router to show auth views when signed out.
- [x] Run auth tests and analyzer.

```bash
flutter test test/features/auth/auth_view_model_test.dart
flutter test test/app/app_test.dart
flutter analyze
```

Expected: both commands exit `0`.

- [x] Commit.

Status: committed in the initial project commit.

```bash
git add lib/features/auth lib/features/profile lib/core/network test/features/auth
git commit -m "feat: add auth and profile foundation"
```

---

## Task 6: Contacts And Invitations

**Files:**

- Create: `supabase/functions/send-invitation/index.ts`
- Create: `supabase/functions/respond-invitation/index.ts`
- Create: `lib/features/contacts/repositories/contacts_repository.dart`
- Create: `lib/features/contacts/viewmodels/contacts_view_model.dart`
- Create: `lib/features/contacts/views/contacts_view.dart`
- Create: `lib/features/contacts/views/invitations_view.dart`
- Create: `test/features/contacts/contacts_view_model_test.dart`

**Interfaces:**

- Produces: `ContactsRepository.fetchContacts()`
- Produces: `ContactsRepository.fetchInvitations()`
- Produces: `ContactsRepository.sendInvitation(receiverId, message)`
- Produces: `ContactsRepository.respondInvitation(invitationId, action)`

- [x] Write ViewModel tests for loading contacts, sending invitation, accepting invitation, and declining invitation.
- [x] Implement `send-invitation` Edge Function.
- [x] Implement `respond-invitation` Edge Function.
- [x] Implement local SQLite sync for `local_contacts` and `local_invitations`.
- [x] Implement `ContactsRepository`.
- [x] Implement contacts and invitations views.
- [x] Run tests.

```bash
flutter test test/features/contacts/contacts_view_model_test.dart
supabase functions serve send-invitation
supabase functions serve respond-invitation
```

Expected: Flutter tests pass; both functions start locally.

- [x] Commit.

Status: committed in the initial project commit.

```bash
git add supabase/functions/send-invitation supabase/functions/respond-invitation lib/features/contacts test/features/contacts
git commit -m "feat: add contacts and invitations"
```

---

## Task 7: Auth Frontend Wiring And OAuth Redirects

**Files:**

- Modify: `lib/features/auth/repositories/auth_repository.dart`
- Modify: `lib/features/auth/viewmodels/auth_view_model.dart`
- Modify: `lib/features/auth/views/login_view.dart`
- Modify: `lib/features/auth/views/signup_view.dart`
- Create: `lib/features/auth/providers/auth_provider.dart`
- Create: `lib/features/auth/views/auth_gate.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/app/router.dart`
- Modify: `test/features/auth/auth_view_model_test.dart`
- Create: `test/features/auth/auth_frontend_test.dart`
- Create: `md/auth-oauth-setup.md`

**Interfaces:**

- Consumes: `AuthRepository.signIn(email, password)`
- Consumes: `AuthRepository.signUp(email, password, displayName)`
- Consumes: `AuthRepository.signInWithGoogle()`
- Consumes: `AuthRepository.signInWithApple()`
- Produces: `AuthRepository.authStateChanges()`
- Produces: `AuthViewModel.startListening()`
- Produces: `AuthProvider.of(context)`
- Produces: `AuthGate`

- [x] Write failing ViewModel test that `authStateChanges()` updates signed-in and signed-out states after OAuth redirect.
- [x] Add `Stream<AuthUserModel?> authStateChanges()` to `AuthRepository`.
- [x] Implement Supabase auth-state mapping from `Supabase.instance.client.auth.onAuthStateChange`.
- [x] Add `AuthViewModel.startListening()` and dispose the auth-state subscription.
- [x] Write failing widget tests that tapping email sign-in, Google sign-in, Apple sign-in, and signup buttons calls the ViewModel methods.
- [x] Create `AuthProvider` to provide one `AuthViewModel` to auth views.
- [x] Create `AuthGate` that shows `LoginView` when signed out and `AppRouter.inbox` content when signed in.
- [x] Wire `LoginView` form submit to `AuthViewModel.signIn()`.
- [x] Wire `SignupView` form submit to `AuthViewModel.signUp()`.
- [x] Wire Google button to `AuthViewModel.signInWithGoogle()`.
- [x] Wire Apple button to `AuthViewModel.signInWithApple()`.
- [x] Render loading and error states from `AuthViewState`.
- [x] Document required Supabase OAuth provider settings, redirect URLs, and local `--dart-define=AUTH_REDIRECT_URI=...` usage in `md/auth-oauth-setup.md`.
- [x] Run auth frontend tests and analyzer.

```bash
flutter test test/features/auth/auth_view_model_test.dart
flutter test test/features/auth/auth_frontend_test.dart
flutter analyze
```

Expected: Google/Apple buttons call real auth methods; after OAuth redirect,
Supabase auth state updates the ViewModel and the app leaves the signed-out
screen.

- [x] Commit.

Status: committed in the initial project commit.

```bash
git add lib/features/auth lib/app test/features/auth md/auth-oauth-setup.md
git commit -m "feat: wire auth frontend"
```

---

## Task 7.1: Profile Screen

**Files:**

- Modify: `lib/features/profile/repositories/profile_repository.dart`
- Modify: `lib/features/profile/models/profile_model.dart`
- Create: `lib/features/profile/viewmodels/profile_view_model.dart`
- Create: `lib/features/profile/views/profile_view.dart`
- Modify: `lib/app/main_shell.dart`
- Create: `supabase/migrations/0004_profile_handles.sql`
- Create: `test/features/profile/profile_view_model_test.dart`
- Create: `test/features/profile/profile_view_test.dart`
- Modify: `test/features/profile/profile_repository_test.dart`
- Modify: `test/supabase/supabase_migrations_test.dart`
- Modify: `test/app/main_shell_test.dart`

**Interfaces:**

- Consumes: `ProfileRepository.upsertCurrentUserProfile(displayName, avatarUrl, status)`
- Consumes: `ProfileRepository.upsertCurrentUserProfile(displayName, handle, avatarUrl, status)`
- Produces: `ProfileRepository.fetchCurrentUserProfile()`
- Produces: `ProfileModel.handle`
- Produces: `ProfileViewModel.loadProfile()`
- Produces: `ProfileViewModel.updateProfile(displayName, status)`
- Produces: `ProfileViewModel.updateProfile(displayName, handle, status)`
- Produces: `ProfileView`
- Consumes in shell: `ProfileView` for the Profile tab content

- [x] Write failing `ProfileViewModel` tests for loading the current profile, updating display name, updating status, and surfacing repository errors.
- [x] Add `ProfileRepository.fetchCurrentUserProfile()` that reads the signed-in user's row from `profiles`.
- [x] Implement `ProfileViewState` with `profile`, `isLoading`, `isSaving`, and `errorMessage`.
- [x] Implement `ProfileViewModel.loadProfile()` and `ProfileViewModel.updateProfile(displayName, status)`.
- [x] Create `ProfileView` with avatar/initials, display name, status, user id, edit fields, save button, loading state, empty state, and error state.
- [x] Replace the blank Profile tab in `MainShell` with `ProfileView`.
- [x] Update shell/widget tests so the Profile tab renders the real `ProfileView` while keeping the icon-only navbar.
- [x] Run profile tests and analyzer.
- [x] Add a profile `handle` column with lowercase uniqueness, handle format validation, and a migration test.
- [x] Update `ProfileModel`, `ProfileRepository`, and `ProfileViewModel` to load and save the current user's handle.
- [x] Add a handle field to `ProfileView` so users can claim or edit their searchable `@handle`.
- [x] Add profile tests for handle rendering, handle save, blank/invalid handle validation, and repository error state.
- [x] Run profile handle tests, migration tests, and analyzer.

```bash
flutter test test/features/profile/profile_view_model_test.dart
flutter test test/features/profile/profile_view_test.dart
flutter test test/app/main_shell_test.dart
flutter analyze
```

Expected: Profile tab opens the real profile screen, profile data loads from Supabase, edits call the repository, and analyzer reports no issues.

- [x] Commit.

Status: committed in the initial project commit.

```bash
git add lib/features/profile lib/app/main_shell.dart test/features/profile test/app/main_shell_test.dart
git commit -m "feat: add profile screen"
```

---

## Task 7.2: Contact Screen

**Files:**

- Modify: `lib/features/contacts/views/contacts_view.dart`
- Modify: `lib/features/contacts/views/invitations_view.dart`
- Create: `lib/features/contacts/models/profile_search_result_model.dart`
- Modify: `lib/features/contacts/repositories/contacts_repository.dart`
- Modify: `lib/features/contacts/viewmodels/contacts_view_model.dart`
- Modify: `lib/app/main_shell.dart`
- Create: `supabase/functions/search-users/index.ts`
- Create: `test/features/contacts/contacts_view_test.dart`
- Modify: `test/features/contacts/contacts_view_model_test.dart`
- Create: `test/features/contacts/profile_search_result_model_test.dart`
- Modify: `test/app/main_shell_test.dart`

**Interfaces:**

- Consumes: `ContactsViewModel.load()`
- Consumes: `ContactsViewModel.sendInvitation(receiverId, message)`
- Consumes: `ContactsViewModel.searchProfiles(query)`
- Consumes: `ContactsViewModel.acceptInvitation(invitationId)`
- Consumes: `ContactsViewModel.declineInvitation(invitationId)`
- Produces: `ContactsRepository.searchProfiles(query)`
- Produces: `ProfileSearchResultModel`
- Produces: `ContactsView` as the Contacts tab content
- Produces: `InvitationsView` navigation from the Contacts screen

- [x] Write failing widget tests for contacts loading state, empty state, populated contacts, send invitation, invitations navigation, and repository error state.
- [x] Keep `ContactsViewModel.load()` loading contacts and invitations together.
- [x] Update `ContactsView` for signed-in tab usage: no nested app shell, safe bottom padding above the native/Flutter navbar, invite form, contact list, empty state, and error state.
- [x] Keep `InvitationsView` reachable from `ContactsView` and able to accept or decline invitations with the same shared `ContactsViewModel`.
- [x] Replace the blank Contacts tab in `MainShell` with `ContactsView`.
- [x] Update shell/widget tests so the Contacts tab renders the real `ContactsView` while keeping the icon-only navbar.
- [x] Run contacts tests and analyzer.
- [x] Write failing ViewModel tests for profile search loading, results, empty results, and repository search errors.
- [x] Write failing widget tests for the contacts search bar, typing by handle/display name, showing user results, no-results state, and tapping Add.
- [x] Implement `ProfileSearchResultModel` with `id`, `displayName`, `handle`, and optional `avatarUrl`.
- [x] Implement a `search-users` Edge Function that searches `profiles.handle` and `profiles.display_name`, excludes the current user, returns only safe public fields, and does not expose unrestricted profile reads through RLS.
- [x] Add `ContactsRepository.searchProfiles(query)` that calls `search-users`.
- [x] Add `ContactsViewModel.searchProfiles(query)` state for `searchQuery`, `searchResults`, `isSearching`, and `searchErrorMessage`.
- [x] Replace the raw Profile ID invite field with a search bar that finds users by `@handle` or display name.
- [x] Show search results with avatar/initials, display name, `@handle`, and an Add action that sends the invitation using the selected user's profile id.
- [x] Clear search results and invite message after a successful Add, while preserving errors when invitation sending fails.
- [x] Run contacts search tests, Edge Function checks, and analyzer.

```bash
flutter test test/features/contacts/contacts_view_model_test.dart
flutter test test/features/contacts/contacts_view_test.dart
flutter test test/app/main_shell_test.dart
flutter analyze
```

Expected: Contacts tab opens the real contacts screen, contacts and invitations load through `ContactsViewModel`, invitation actions update UI state, and analyzer reports no issues.

- [x] Commit.

Status: committed in the initial project commit.

```bash
git add lib/features/contacts lib/app/main_shell.dart test/features/contacts test/app/main_shell_test.dart
git commit -m "feat: add contacts screen"
```

---

## Task 8: Ably Token Function And Realtime Client

**Files:**

- Create: `supabase/functions/ably-token/index.ts`
- Create: `lib/core/realtime/ably_client_provider.dart`
- Create: `lib/core/realtime/realtime_event.dart`
- Create: `test/features/chat/realtime_event_test.dart`

**Interfaces:**

- Produces: `AblyClientProvider.connect()`
- Produces: `AblyClientProvider.disconnect()`
- Produces: `AblyClientProvider.channel(name)`
- Produces: `RealtimeEvent.fromJson(Map<String, dynamic>)`

- [x] Write `RealtimeEvent` tests for `message.created`, `message.persisted`, `message.rejected`, `receipt.delivered`, and `receipt.read`.
- [x] Implement `ably-token` Edge Function.
- [x] Make token TTL 30 minutes.
- [x] Include capabilities for `chat:*`, `typing:*`, `receipt:*`, `presence:*`, and `user:{user_id}` only when membership allows it.
- [x] Implement Flutter Ably auth callback that calls Supabase Function with current Supabase JWT.
- [x] Implement realtime event parsing.
- [x] Run tests.

```bash
flutter test test/features/chat/realtime_event_test.dart
supabase functions serve ably-token
```

Expected: Flutter tests pass; function starts locally.

- [x] Commit.

```bash
git add supabase/functions/ably-token lib/core/realtime test/features/chat/realtime_event_test.dart
git commit -m "feat: add ably token auth"
```

---

## Task 9: Inbox And Conversation Sync

**Files:**

- Create: `lib/features/inbox/repositories/inbox_repository.dart`
- Create: `lib/features/inbox/viewmodels/inbox_view_model.dart`
- Create: `lib/features/inbox/views/inbox_view.dart`
- Create: `test/features/inbox/inbox_view_model_test.dart`
- Create: `test/features/inbox/inbox_repository_test.dart`
- Create: `test/features/inbox/inbox_view_test.dart`
- Update: `lib/app/main_shell.dart`

**Interfaces:**

- Produces: `InboxRepository.fetchRemoteConversations()`
- Produces: `InboxRepository.watchLocalConversations()`
- Produces: `InboxRepository.syncConversations()`

- [x] Write ViewModel test for loading local conversations first, then refreshing from Supabase.
- [x] Implement local conversation reads from SQLite.
- [x] Implement Supabase conversation fetch.
- [x] Implement sync cursor updates.
- [x] Build inbox list UI.
- [x] Run tests.

```bash
flutter test test/features/inbox/inbox_view_model_test.dart
```

Expected: tests pass.

- [x] Commit.

```bash
git add lib/app/main_shell.dart lib/features/inbox test/app/main_shell_test.dart test/features/inbox md/implementations.md
git commit -m "feat: add inbox sync"
```

---

## Task 10: Local-First Message Send

**Files:**

- Create: `lib/features/chat/repositories/chat_local_repository.dart`
- Create: `lib/features/chat/repositories/chat_realtime_repository.dart`
- Create: `lib/features/chat/viewmodels/chat_view_model.dart`
- Create: `test/features/chat/chat_view_model_test.dart`
- Create: `test/features/chat/outgoing_queue_test.dart`
- Create: `test/features/chat/chat_realtime_repository_test.dart`

**Interfaces:**

- Produces: `ChatViewModel.sendTextMessage(conversationId, text)`
- Produces: `ChatLocalRepository.insertOutgoingMessage(message)`
- Produces: `ChatRealtimeRepository.publishMessageCreated(message)`
- Produces: `OutgoingQueue.flush()`

- [x] Write failing test: sending text creates local message with `persistence_status = pending`.
- [x] Write failing test: message is added to `outgoing_queue` when Ably is disconnected.
- [x] Implement local insert.
- [x] Implement `client_message_id` generation.
- [x] Implement Ably publish to `chat:{conversation_id}`.
- [x] Implement queue flush after token refresh or reconnect.
- [x] Run tests.

```bash
flutter test test/features/chat/chat_view_model_test.dart
flutter test test/features/chat/outgoing_queue_test.dart
```

Expected: tests pass.

- [x] Commit.

```bash
git add lib/features/chat test/features/chat
git commit -m "feat: send local-first chat messages"
```

---

## Task 11: Message Persistence Function

**Files:**

- Create: `supabase/functions/persist-message/index.ts`
- Create: `lib/features/chat/repositories/chat_remote_repository.dart`
- Modify: `lib/features/chat/viewmodels/chat_view_model.dart`
- Modify: `lib/features/chat/repositories/chat_local_repository.dart`
- Modify: `test/features/chat/chat_view_model_test.dart`
- Create: `test/features/chat/chat_remote_repository_test.dart`
- Modify: `test/supabase/supabase_migrations_test.dart`

**Interfaces:**

- Produces: `persist-message` Edge Function
- Consumes: `client_message_id`, `conversation_id`, `body`, `attachments`
- Produces Ably event: `message.persisted`
- Produces Ably event: `message.rejected`

- [x] Implement event schema validation for `message.created`.
- [x] Verify sender is a current `conversation_members` row.
- [x] Insert into `messages` using unique `(conversation_id, client_message_id)`.
- [x] Insert `attachments` rows when message includes media.
- [x] Publish `message.persisted` on success.
- [x] Publish `message.rejected` on authorization failure.
- [x] Update Flutter to merge `message.persisted` into SQLite by `client_message_id`.
- [x] Run local function.

```bash
supabase functions serve persist-message
```

Expected: function starts locally and logs no startup errors.

- [x] Commit.

```bash
git add supabase/functions/persist-message lib/features/chat test/features/chat test/supabase/supabase_migrations_test.dart md/implementations.md
git commit -m "feat: persist realtime messages"
```

---

## Task 12: Message Receive, Receipts, And Chat UI

**Files:**

- Create: `lib/features/chat/views/chat_view.dart`
- Create: `lib/features/chat/views/widgets/message_bubble.dart`
- Create: `lib/features/chat/views/widgets/message_input.dart`
- Create: `lib/features/chat/views/widgets/receipt_indicator.dart`
- Create: `lib/features/chat/views/widgets/typing_indicator.dart`
- Modify: `lib/features/chat/viewmodels/chat_view_model.dart`
- Modify: `lib/features/chat/repositories/chat_realtime_repository.dart`

**Interfaces:**

- Consumes: `RealtimeEvent`
- Produces: `receipt.delivered`
- Produces: `receipt.read`
- Produces: `typing.started`
- Produces: `typing.stopped`

- [ ] Subscribe to `chat:{conversation_id}` when chat view opens.
- [ ] Insert received `message.created` into SQLite.
- [ ] Dedupe by `client_message_id`.
- [ ] Publish `receipt.delivered` after local save.
- [ ] Publish `receipt.read` when conversation is visible.
- [ ] Render message bubbles from SQLite stream.
- [ ] Render pending, delivered, read, failed, rejected, and persisted states.
- [ ] Add typing indicator publish with debounce.
- [ ] Run widget tests for chat view states.

```bash
flutter test test/features/chat
flutter analyze
```

Expected: tests and analyzer pass.

- [ ] Commit.

```bash
git add lib/features/chat test/features/chat
git commit -m "feat: receive messages and receipts"
```

---

## Task 13: App Open Sync And Lifecycle Handling

**Files:**

- Create: `lib/features/chat/repositories/chat_remote_repository.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/features/inbox/repositories/inbox_repository.dart`
- Modify: `lib/features/chat/repositories/chat_local_repository.dart`

**Interfaces:**

- Produces: `ChatRemoteRepository.fetchMessagesAfter(conversationId, cursor)`
- Produces: `ChatLocalRepository.mergeRemoteMessages(messages)`
- Produces: `sync_cursors` updates

- [ ] On app start, restore Supabase session.
- [ ] Open SQLite.
- [ ] Fetch conversations.
- [ ] Fetch messages newer than `sync_cursors.last_server_created_at`.
- [ ] Merge remote messages into SQLite.
- [ ] Connect Ably after local sync starts.
- [ ] On foreground resume, repeat sync and queue flush.
- [ ] Run tests and analyzer.

```bash
flutter test
flutter analyze
```

Expected: all tests and analyzer pass.

- [ ] Commit.

```bash
git add lib test
git commit -m "feat: sync missed messages on app resume"
```

---

## Task 14: Push Registration And Notification Routing

**Files:**

- Create: `supabase/functions/register-device/index.ts`
- Create: `supabase/functions/send-push/index.ts`
- Create: `lib/core/notifications/push_notification_service.dart`
- Modify: `lib/app/router.dart`

**Interfaces:**

- Produces: `PushNotificationService.registerDevice()`
- Produces: `PushNotificationService.handleNotificationTap(payload)`
- Produces backend device rows in `devices`

- [ ] Register push token after user signs in.
- [ ] Store `device_id`, `platform`, `push_token`, and `push_provider`.
- [ ] Implement `register-device` Edge Function.
- [ ] Implement `send-push` Edge Function.
- [ ] Route notification tap payload to `conversation_id`.
- [ ] On notification tap, fetch missed messages from Supabase before rendering.
- [ ] Run analyzer.

```bash
flutter analyze
supabase functions serve register-device
supabase functions serve send-push
```

Expected: analyzer passes; functions start locally.

- [ ] Commit.

```bash
git add supabase/functions/register-device supabase/functions/send-push lib/core/notifications lib/app/router.dart
git commit -m "feat: add push notification routing"
```

---

## Task 15: Media Messages

**Files:**

- Create: `supabase/migrations/0004_storage_policies.sql`
- Create: `lib/features/media/models/media_upload_model.dart`
- Create: `lib/features/media/repositories/media_repository.dart`
- Create: `lib/features/media/viewmodels/media_upload_view_model.dart`
- Modify: `lib/features/chat/views/widgets/message_input.dart`
- Modify: `lib/features/chat/views/widgets/message_bubble.dart`

**Interfaces:**

- Produces: `MediaRepository.uploadChatAttachment(conversationId, file)`
- Produces message type: `image`
- Produces attachment metadata rows in `attachments`

- [ ] Create Supabase Storage bucket policy for chat media.
- [ ] Implement image picker flow.
- [ ] Upload image to Supabase Storage path `chat/{conversation_id}/{client_message_id}/{filename}`.
- [ ] Send `message.created` with attachment metadata.
- [ ] Render image message preview.
- [ ] Persist attachment metadata through `persist-message`.
- [ ] Run analyzer and chat tests.

```bash
flutter test test/features/chat
flutter analyze
```

Expected: tests and analyzer pass.

- [ ] Commit.

```bash
git add supabase/migrations/0004_storage_policies.sql lib/features/media lib/features/chat
git commit -m "feat: add media messages"
```

---

## Task 16: Production Hardening

**Files:**

- Modify: `supabase/functions/*/index.ts`
- Modify: `lib/core/realtime/ably_client_provider.dart`
- Modify: `lib/features/chat/repositories/chat_realtime_repository.dart`
- Modify: `lib/features/chat/viewmodels/chat_view_model.dart`
- Create: `md/release-checklist.md`

**Interfaces:**

- Produces rate-limited Edge Functions
- Produces retry backoff for outgoing messages
- Produces release checklist

- [ ] Add payload size checks to `persist-message`.
- [ ] Add attachment MIME and size checks.
- [ ] Add rate limits to `ably-token`, `send-invitation`, and `persist-message`.
- [ ] Add exponential backoff for outgoing queue.
- [ ] Add UI for rejected messages.
- [ ] Add forced reauthorization when `user:{user_id}` receives `token.refresh_required`.
- [ ] Add release checklist covering auth, RLS, Storage policies, token TTL, push, and offline queue.
- [ ] Run full verification.

```bash
flutter test
flutter analyze
supabase db reset
```

Expected: all commands exit `0`.

- [ ] Commit.

```bash
git add lib supabase md/release-checklist.md
git commit -m "chore: harden chat app for release"
```

---

## Implementation Order

- [ ] Complete Task 1 before any feature work.
- [ ] Complete Tasks 2 and 3 before repositories.
- [ ] Complete Task 4 before ViewModels.
- [ ] Complete Task 5 before token or contacts work.
- [ ] Complete Task 6 before direct conversations from contacts.
- [ ] Complete Task 7 before any signed-in frontend workflow testing.
- [ ] Complete Task 7.1 before enabling the Profile tab for real users.
- [ ] Complete Task 7.2 before enabling the Contacts tab for real users.
- [ ] Complete Task 8 before realtime chat.
- [ ] Complete Task 9 before chat list UI.
- [ ] Complete Tasks 10 through 13 for text-chat MVP.
- [ ] Complete Task 14 for closed-app notification behavior.
- [ ] Complete Task 15 for image/media support.
- [ ] Complete Task 16 before beta release.

## Final Verification

- [ ] Run all Flutter tests.

```bash
flutter test
```

- [ ] Run static analysis.

```bash
flutter analyze
```

- [ ] Run formatter check.

```bash
dart format --set-exit-if-changed lib test
```

- [ ] Run Supabase database reset.

```bash
supabase db reset
```

- [ ] Manually test these flows:
  - Sign up.
  - Sign in.
  - Sign in with Google.
  - Sign in with Apple.
  - Send friend invitation.
  - Accept friend invitation.
  - Open direct conversation.
  - Send message while both users are online.
  - Send message while recipient app is closed.
  - Open app from push notification.
  - Send message while sender is offline.
  - Reconnect and flush queued message.
  - Upload image message.
  - Remove user from conversation and verify token refresh removes access.
