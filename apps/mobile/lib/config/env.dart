class Env {
  Env._();

  /// Matches web `NEXT_PUBLIC_SUPABASE_*` for local runs without dart-define.
  /// Override in CI/release with `--dart-define=SUPABASE_URL=...`.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://koijsvwsjsmjrzmpuvxp.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtvaWpzdndzanNtanJ6bXB1dnhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkzNjY3MzQsImV4cCI6MjEwNDk0MjczNH0.rmqMopmjfLPZm_YFQVG7xaxBkXFY6dqAD1sI9U1z6-A',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project') &&
      supabaseAnonKey != 'your-anon-key';
}
