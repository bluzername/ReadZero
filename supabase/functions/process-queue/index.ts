// supabase/functions/process-queue/index.ts
// Processes pending articles from the queue

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MAX_CONCURRENT = 5;
const MAX_RETRIES = 3;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Get pending jobs from queue
    const { data: pendingJobs, error: fetchError } = await supabase
      .from("processing_queue")
      .select(`
        id,
        article_id,
        job_type,
        attempts,
        articles!inner(url)
      `)
      .eq("status", "pending")
      .lt("attempts", MAX_RETRIES)
      .order("created_at", { ascending: true })
      .limit(MAX_CONCURRENT);

    if (fetchError) throw fetchError;

    if (!pendingJobs || pendingJobs.length === 0) {
      return new Response(
        JSON.stringify({ message: "No pending jobs" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Processing ${pendingJobs.length} jobs...`);

    // Mark jobs as processing
    const jobIds = pendingJobs.map(j => j.id);
    await supabase
      .from("processing_queue")
      .update({ 
        status: "processing",
        started_at: new Date().toISOString(),
      })
      .in("id", jobIds);

    // Process jobs concurrently
    const results = await Promise.allSettled(
      pendingJobs.map(async (job: any) => {
        try {
          if (job.job_type === "extract") {
            // Call extract-article function
            const response = await fetch(
              `${SUPABASE_URL}/functions/v1/extract-article`,
              {
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                },
                body: JSON.stringify({
                  article_id: job.article_id,
                  url: job.articles.url,
                }),
              }
            );

            if (!response.ok) {
              const error = await response.text();
              throw new Error(error);
            }

            // Mark job as completed
            await supabase
              .from("processing_queue")
              .update({
                status: "completed",
                completed_at: new Date().toISOString(),
              })
              .eq("id", job.id);

            return { job_id: job.id, success: true };
          }

          throw new Error(`Unknown job type: ${job.job_type}`);
        } catch (error) {
          console.error(`Job ${job.id} failed:`, error);

          // Update job with error
          await supabase
            .from("processing_queue")
            .update({
              status: "pending", // Reset to pending for retry
              attempts: job.attempts + 1,
              last_error: error.message,
            })
            .eq("id", job.id);

          // If max retries reached, mark as failed
          if (job.attempts + 1 >= MAX_RETRIES) {
            await supabase
              .from("processing_queue")
              .update({ status: "failed" })
              .eq("id", job.id);
          }

          return { job_id: job.id, success: false, error: error.message };
        }
      })
    );

    const summary = results.map((r, i) => ({
      job_id: pendingJobs[i].id,
      status: r.status,
      result: r.status === "fulfilled" ? r.value : r.reason?.message,
    }));

    return new Response(
      JSON.stringify({ processed: results.length, summary }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Queue processing error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});
