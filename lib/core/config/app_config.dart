class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.ablyTokenFunctionName,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String ablyTokenFunctionName;

  bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static AppConfig fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://xlymdlnwwerjhtrkwofz.supabase.co',
      ),
      supabaseAnonKey: String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhseW1kbG53d2Vyamh0cmt3b2Z6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NzQyMjcsImV4cCI6MjA5NDQ1MDIyN30.QQXR4M7vvbxsCGeAHXkV5U24osvqJKgLAqagd1Qg8L0',
      ),
      ablyTokenFunctionName: 'ably-token',
    );
  }
}
