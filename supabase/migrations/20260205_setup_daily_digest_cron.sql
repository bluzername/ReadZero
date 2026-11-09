-- ============================================
-- ENABLE REQUIRED EXTENSIONS
-- ============================================
-- pg_cron: For scheduling jobs
-- pg_net: For making HTTP requests from PostgreSQL

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Grant usage to postgres user
GRANT USAGE ON SCHEMA cron TO postgres;

-- ============================================
-- DAILY DIGEST CRON JOB
-- ============================================
-- Runs every day at 8 AM UTC
-- Calls the generate-digest Edge Function
--
-- Before running: replace <SUPABASE_URL> with the project URL
-- (https://<project-ref>.supabase.co) and <SUPABASE_ANON_KEY> with the
-- project's anon key. The key is intentionally not committed here so that it
-- is never baked into the repository or the cron job definition by accident.
-- To avoid storing the key in cron.job at all, store it in Supabase Vault
-- (select vault.create_secret('<key>', 'supabase_anon_key')) and build the
-- header from (select decrypted_secret from vault.decrypted_secrets
-- where name = 'supabase_anon_key') instead of the literal below.

-- First, remove any existing job with the same name
SELECT cron.unschedule('generate-daily-digests') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'generate-daily-digests'
);

-- Schedule the daily digest generation
SELECT cron.schedule(
    'generate-daily-digests',
    '0 8 * * *',  -- Every day at 8:00 AM UTC
    $$
    SELECT net.http_post(
        url := '<SUPABASE_URL>/functions/v1/generate-digest',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer <SUPABASE_ANON_KEY>'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- Verify the job was created
SELECT * FROM cron.job WHERE jobname = 'generate-daily-digests';
