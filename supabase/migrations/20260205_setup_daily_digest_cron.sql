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
        url := 'https://bioiacixxauufpvswlxe.supabase.co/functions/v1/generate-digest',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpb2lhY2l4eGF1dWZwdnN3bHhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2OTc2MzAsImV4cCI6MjA4NTI3MzYzMH0.rALzbiI5ggIQYOrcPC8VeRVyJO_0KNVtQCaVKz7d9cQ'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- Verify the job was created
SELECT * FROM cron.job WHERE jobname = 'generate-daily-digests';
