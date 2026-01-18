/// Environment configuration
/// Replace these values with your actual credentials
class Env {
  // Supabase
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // Jina Reader API (for article extraction)
  static const String jinaApiKey = 'YOUR_JINA_API_KEY';
  
  // Claude API (stored in Supabase Edge Function secrets, not here)
  // Set via: supabase secrets set ANTHROPIC_API_KEY=your_key
}
