// Shared runtime configuration for the Edge Functions.
// Model ids can be overridden with `supabase secrets set` without redeploying.

/** OpenRouter slug for the Claude model used for analysis and digests. */
export const DEFAULT_CLAUDE_MODEL = "anthropic/claude-haiku-4.5";

/** xAI model id used for X/Twitter post extraction. */
export const DEFAULT_GROK_MODEL = "grok-4-1-fast";

function envOrDefault(name: string, fallback: string): string {
  const value = Deno.env.get(name)?.trim();
  return value ? value : fallback;
}

export const CLAUDE_MODEL = envOrDefault("CLAUDE_MODEL", DEFAULT_CLAUDE_MODEL);
export const GROK_MODEL = envOrDefault("GROK_MODEL", DEFAULT_GROK_MODEL);
