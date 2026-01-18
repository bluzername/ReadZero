-- Readwise Database Schema
-- Run this in your Supabase SQL editor

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================
-- TABLES
-- ============================================

-- Users table (extends Supabase auth)
CREATE TABLE IF NOT EXISTS public.user_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    digest_time TIME DEFAULT '08:00:00',
    timezone TEXT DEFAULT 'America/Los_Angeles',
    analyze_images BOOLEAN DEFAULT true,
    include_comments BOOLEAN DEFAULT true,
    push_notifications BOOLEAN DEFAULT true,
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Articles table
CREATE TABLE IF NOT EXISTS public.articles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    url TEXT NOT NULL,
    title TEXT,
    description TEXT,
    content TEXT, -- Extracted markdown content
    image_url TEXT,
    site_name TEXT,
    author TEXT,
    images JSONB DEFAULT '[]'::jsonb, -- Array of {url, alt, caption, ai_description}
    comments JSONB DEFAULT '[]'::jsonb, -- Array of comment objects
    analysis JSONB, -- AI analysis results
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'extracting', 'analyzing', 'ready', 'failed')),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ,
    is_archived BOOLEAN DEFAULT false,
    
    -- Unique constraint to prevent duplicate URLs per user
    UNIQUE(user_id, url)
);

-- Daily digests table
CREATE TABLE IF NOT EXISTS public.digests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date DATE NOT NULL,
    overall_summary TEXT NOT NULL,
    top_themes TEXT[] DEFAULT '{}',
    articles JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of digest article summaries
    ai_insights TEXT, -- Cross-article insights
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_read BOOLEAN DEFAULT false,
    
    -- One digest per user per day
    UNIQUE(user_id, date)
);

-- Processing queue for background jobs
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

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_articles_user_id ON public.articles(user_id);
CREATE INDEX IF NOT EXISTS idx_articles_created_at ON public.articles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_status ON public.articles(status);
CREATE INDEX IF NOT EXISTS idx_digests_user_id ON public.digests(user_id);
CREATE INDEX IF NOT EXISTS idx_digests_date ON public.digests(date DESC);
CREATE INDEX IF NOT EXISTS idx_processing_queue_status ON public.processing_queue(status);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.digests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.processing_queue ENABLE ROW LEVEL SECURITY;

-- User settings policies
CREATE POLICY "Users can view own settings"
    ON public.user_settings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings"
    ON public.user_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own settings"
    ON public.user_settings FOR UPDATE
    USING (auth.uid() = user_id);

-- Articles policies
CREATE POLICY "Users can view own articles"
    ON public.articles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own articles"
    ON public.articles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own articles"
    ON public.articles FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own articles"
    ON public.articles FOR DELETE
    USING (auth.uid() = user_id);

-- Digests policies
CREATE POLICY "Users can view own digests"
    ON public.digests FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own digests"
    ON public.digests FOR UPDATE
    USING (auth.uid() = user_id);

-- Service role policy for processing queue (only accessible by backend)
CREATE POLICY "Service role can manage processing queue"
    ON public.processing_queue
    USING (true)
    WITH CHECK (true);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to create user settings on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_settings (user_id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to queue article for processing
CREATE OR REPLACE FUNCTION public.queue_article_processing()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.processing_queue (article_id, job_type)
    VALUES (NEW.id, 'extract');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-queue new articles
DROP TRIGGER IF EXISTS on_article_created ON public.articles;
CREATE TRIGGER on_article_created
    AFTER INSERT ON public.articles
    FOR EACH ROW EXECUTE FUNCTION public.queue_article_processing();

-- Function to update article status
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

-- ============================================
-- SCHEDULED JOBS (pg_cron)
-- ============================================

-- Schedule daily digest generation at 8 AM UTC (adjust for your timezone)
-- This calls a Supabase Edge Function
SELECT cron.schedule(
    'generate-daily-digests',
    '0 8 * * *', -- Every day at 8:00 AM UTC
    $$
    SELECT net.http_post(
        url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/generate-digest',
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
        body := '{}'::jsonb
    );
    $$
);

-- Schedule processing queue worker every minute
SELECT cron.schedule(
    'process-article-queue',
    '* * * * *', -- Every minute
    $$
    SELECT net.http_post(
        url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-queue',
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
        body := '{}'::jsonb
    );
    $$
);

-- ============================================
-- REALTIME
-- ============================================

-- Enable realtime for articles and digests
ALTER PUBLICATION supabase_realtime ADD TABLE public.articles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.digests;
