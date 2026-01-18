// supabase/functions/generate-digest/index.ts
// Generates daily digest summaries for all users

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface DigestRequest {
  user_id?: string; // Optional: generate for specific user
  date?: string;    // Optional: specific date (defaults to yesterday)
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body: DigestRequest = req.method === "POST" 
      ? await req.json() 
      : {};

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Determine date range (yesterday by default)
    const targetDate = body.date 
      ? new Date(body.date) 
      : new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    const startOfDay = new Date(targetDate);
    startOfDay.setHours(0, 0, 0, 0);
    
    const endOfDay = new Date(targetDate);
    endOfDay.setHours(23, 59, 59, 999);

    // Get users to process
    let usersQuery = supabase.from("user_settings").select("user_id");
    if (body.user_id) {
      usersQuery = usersQuery.eq("user_id", body.user_id);
    }
    
    const { data: users, error: usersError } = await usersQuery;
    if (usersError) throw usersError;

    const results: any[] = [];

    for (const user of users || []) {
      try {
        const digest = await generateUserDigest(
          supabase,
          user.user_id,
          startOfDay,
          endOfDay,
          targetDate
        );
        
        if (digest) {
          results.push({ user_id: user.user_id, success: true, digest_id: digest.id });
          
          // Send push notification if enabled
          await sendPushNotification(supabase, user.user_id, digest);
        } else {
          results.push({ user_id: user.user_id, success: true, skipped: "no articles" });
        }
      } catch (e) {
        console.error(`Failed to generate digest for user ${user.user_id}:`, e);
        results.push({ user_id: user.user_id, success: false, error: e.message });
      }
    }

    return new Response(
      JSON.stringify({ success: true, results }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error generating digests:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});

async function generateUserDigest(
  supabase: any,
  userId: string,
  startOfDay: Date,
  endOfDay: Date,
  targetDate: Date
): Promise<any> {
  
  // Get articles from the target day
  const { data: articles, error } = await supabase
    .from("articles")
    .select("*")
    .eq("user_id", userId)
    .eq("status", "ready")
    .gte("created_at", startOfDay.toISOString())
    .lte("created_at", endOfDay.toISOString())
    .order("created_at", { ascending: false });

  if (error) throw error;
  if (!articles || articles.length === 0) return null;

  console.log(`Generating digest for user ${userId} with ${articles.length} articles`);

  // Prepare article summaries for Claude
  const articleSummaries = articles.map((article: any) => ({
    id: article.id,
    title: article.title,
    url: article.url,
    summary: article.analysis?.summary || article.description,
    key_points: article.analysis?.key_points || [],
    topics: article.analysis?.topics || [],
    image_url: article.image_url,
  }));

  // Generate digest with Claude
  const prompt = `You are creating a daily reading digest for a user. Analyze these ${articles.length} articles they saved and create an intelligent summary.

Articles saved today:
${JSON.stringify(articleSummaries, null, 2)}

Create a digest in the following JSON format:
{
  "overall_summary": "A 2-3 paragraph narrative summary that weaves together the main themes and insights from all articles. Make it engaging and insightful.",
  "top_themes": ["Theme 1", "Theme 2", "Theme 3", "Theme 4", "Theme 5"],
  "articles": [
    {
      "article_id": "uuid",
      "title": "Article title",
      "image_url": "url or null",
      "summary": "1-2 sentence summary specific to this article",
      "highlights": ["Key highlight 1", "Key highlight 2"],
      "url": "original url"
    }
  ],
  "ai_insights": "An interesting insight, connection, or pattern you noticed across the articles that the reader might find valuable. Be specific and thoughtful."
}

Return ONLY valid JSON, no other text.`;

  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY!,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 2048,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Claude API error: ${error}`);
  }

  const claudeResponse = await response.json();
  const digestContent = JSON.parse(claudeResponse.content[0].text);

  // Save digest to database
  const dateStr = targetDate.toISOString().split('T')[0];
  
  const { data: digest, error: insertError } = await supabase
    .from("digests")
    .upsert({
      user_id: userId,
      date: dateStr,
      overall_summary: digestContent.overall_summary,
      top_themes: digestContent.top_themes,
      articles: digestContent.articles,
      ai_insights: digestContent.ai_insights,
    }, {
      onConflict: "user_id,date",
    })
    .select()
    .single();

  if (insertError) throw insertError;

  return digest;
}

async function sendPushNotification(
  supabase: any, 
  userId: string, 
  digest: any
): Promise<void> {
  try {
    // Get user's FCM token
    const { data: settings } = await supabase
      .from("user_settings")
      .select("fcm_token, push_notifications")
      .eq("user_id", userId)
      .single();

    if (!settings?.push_notifications || !settings?.fcm_token) return;

    // Send notification via Firebase Cloud Messaging
    // This would typically be done via Firebase Admin SDK
    // For now, we'll log it
    console.log(`Would send push notification to user ${userId}:`, {
      title: "Your Daily Digest is Ready",
      body: `${digest.articles.length} articles summarized. ${digest.top_themes.slice(0, 2).join(", ")}`,
    });

    // In production, integrate with Firebase Admin SDK or similar
    // const message = {
    //   token: settings.fcm_token,
    //   notification: {
    //     title: "Your Daily Digest is Ready",
    //     body: `${digest.articles.length} articles summarized`,
    //   },
    //   data: {
    //     digest_id: digest.id,
    //     type: "digest_ready",
    //   },
    // };
    // await admin.messaging().send(message);

  } catch (e) {
    console.error("Failed to send push notification:", e);
  }
}
