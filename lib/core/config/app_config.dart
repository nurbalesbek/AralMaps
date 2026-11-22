/// Build-time configuration, passed with
/// `flutter run --dart-define-from-file=env/supabase.json`
/// (see env/supabase.example.json). Never committed: env/*.json is ignored.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The publishable ("anon") key. It is meant to ship inside apps; access
  /// is limited by Row Level Security (supabase/schema.sql). The secret /
  /// service_role key must never be used here.
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Accounts are optional: a build without keys works fully offline,
  /// just without sign-in and sync.
  static bool get accountsEnabled =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
