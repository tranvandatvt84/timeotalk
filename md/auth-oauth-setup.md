# Auth OAuth Setup

Task 7 wires the frontend to Supabase Auth. The app can call Google and Apple
OAuth now, but the providers and redirect URL still must be configured outside
Flutter before a real device can complete the sign-in loop.

## Supabase Auth Providers

In Supabase project settings:

- Enable Google provider.
- Add the Google OAuth client id and client secret.
- Enable Apple provider.
- Add the Apple Services ID, Team ID, Key ID, and private key.
- Add the app callback URL to the allowed redirect URLs.

Use one callback URL per environment. Example local/dev callback:

```text
io.supabase.timeotalk://login-callback
```

## Flutter Runtime Defines

The app includes public client defaults for click-run development:

- Supabase project URL
- Supabase anon key
- `io.supabase.timeotalk://login-callback`

For staging or production builds, override those values with runtime defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY \
  --dart-define=AUTH_REDIRECT_URI=io.supabase.timeotalk://login-callback
```

`AUTH_REDIRECT_URI` is passed to `SupabaseAuthRepository.signInWithOAuth`.
If it is empty, Supabase uses its default redirect behavior.

## VS Code Click Run

Local click-run settings can live in `.vscode/launch.json`. Select
`TimeoTalk Dev` in VS Code's Run and Debug panel, then press Run. The app also
has public client defaults, so the regular Flutter run button can initialize
Supabase during development.

## Mobile Deep Links

Configure the mobile app to open the callback URL:

- iOS: add the `io.supabase.timeotalk` URL scheme in `ios/Runner/Info.plist`.
- Android: add an intent filter for `io.supabase.timeotalk://login-callback` in
  `android/app/src/main/AndroidManifest.xml`.

After OAuth completes, Supabase restores the session from the redirect. The
app listens to `authStateChanges()` and `AuthGate` switches from login to the
signed-in screen when the session user arrives.

## Manual Test

- Start the app with the runtime defines above.
- Tap `Continue with Google`.
- Complete the Google sign-in screen.
- Confirm the app returns through `io.supabase.timeotalk://login-callback`.
- Confirm the login screen changes to `Inbox`.
- Repeat with `Continue with Apple`.
