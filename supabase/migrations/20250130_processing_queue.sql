-- Processing queue, triggers and helper functions used by the
-- process-queue and extract-article Edge Functions.
--
-- These objects were previously defined only in the legacy
-- 001_initial_schema.sql (removed). They are kept here so a fresh
-- `supabase db push` produces a schema the Edge Functions can run against.
-- Every statement is idempotent, so applying it to a database that already
-- has these objects is safe.

-- ============================================
-- ARTICLES: error_message column
-- ============================================

ALTER TABLE public.articles ADD COLUMN IF NOT EXISTS error_message TEXT;

-- ============================================
-- PROCESSING QUEUE
-- ============================================

CREATE TABLE IF NOT EXISTS public.processing_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID REFERENCES public.articles(id) ON DELETE CASCADE NOT NULL,
    job_type TEXT NOT NULL CHECK (job_type IN ('extract', 'analyze')),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    attempts INTEGER DEFAULT 0,
    last_error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_processing_queue_status ON public.processing_queue(status);

ALTER TABLE public.processing_queue ENABLE ROW LEVEL SECURITY;

-- Only the service role (Edge Functions) touches the queue.
DROP POLICY IF EXISTS "Service role can manage processing queue" ON public.processing_queue;
CREATE POLICY "Service role can manage processing queue"
    ON public.processing_queue
    USING (auth.jwt()->>'role' = 'service_role')
    WITH CHECK (auth.jwt()->>'role' = 'service_role');

-- ============================================
-- FUNCTIONS AND TRIGGERS
-- ============================================

-- Create a user_settings row for every new auth user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_settings (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Queue every newly saved article for extraction
CREATE OR REPLACE FUNCTION public.queue_article_processing()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.processing_queue (article_id, job_type)
    VALUES (NEW.id, 'extract');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_article_created ON public.articles;
CREATE TRIGGER on_article_created
    AFTER INSERT ON public.articles
    FOR EACH ROW EXECUTE FUNCTION public.queue_article_processing();

-- Helper used by backend jobs to record article status transitions
CREATE OR REPLACE FUNCTION public.update_article_status(
    p_article_id UUID,
    p_status TEXT,
    p_error_message TEXT DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    UPDATE public.articles
    SET
        status = p_status,
        error_message = p_error_message
    WHERE id = p_article_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
