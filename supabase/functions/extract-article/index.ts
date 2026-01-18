// supabase/functions/extract-article/index.ts
// Extracts article content using Jina Reader API and analyzes with Claude

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const JINA_API_KEY = Deno.env.get("JINA_API_KEY");
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ExtractRequest {
  article_id: string;
  url: string;
}

interface JinaResponse {
  data: {
    title: string;
    description: string;
    content: string;
    images: Array<{
      src: string;
      alt?: string;
    }>;
    url: string;
    publishedTime?: string;
    author?: string;
    siteName?: string;
  };
}

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { article_id, url }: ExtractRequest = await req.json();

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Update status to extracting
    await supabase
      .from("articles")
      .update({ status: "extracting" })
      .eq("id", article_id);

    // 1. Extract content using Jina Reader API
    console.log(`Extracting content from: ${url}`);
    
    const jinaResponse = await fetch(`https://r.jina.ai/${url}`, {
      headers: {
        "Accept": "application/json",
        "X-With-Images-Summary": "true",
        "X-With-Links-Summary": "true",
        ...(JINA_API_KEY ? { "Authorization": `Bearer ${JINA_API_KEY}` } : {}),
      },
    });

    if (!jinaResponse.ok) {
      throw new Error(`Jina extraction failed: ${jinaResponse.statusText}`);
    }

    const jinaData: JinaResponse = await jinaResponse.json();
    const { data: extracted } = jinaData;

    // Extract comments if it's a discussion site (Reddit, HN, etc.)
    let comments: any[] = [];
    const isDiscussionSite = url.includes("reddit.com") || 
                            url.includes("news.ycombinator.com") ||
                            url.includes("twitter.com") ||
                            url.includes("x.com");
    
    if (isDiscussionSite) {
      // For discussion sites, the content often includes comments
      // We could use a more sophisticated extraction here
      comments = extractCommentsFromContent(extracted.content);
    }

    // 2. Update article with extracted content
    await supabase
      .from("articles")
      .update({
        title: extracted.title,
        description: extracted.description,
        content: extracted.content,
        image_url: extracted.images?.[0]?.src,
        site_name: extracted.siteName,
        author: extracted.author,
        images: extracted.images?.map(img => ({
          url: img.src,
          alt: img.alt,
        })) || [],
        comments: comments,
        status: "analyzing",
      })
      .eq("id", article_id);

    // 3. Analyze content with Claude
    console.log("Analyzing with Claude...");
    
    const analysis = await analyzeWithClaude(
      extracted.title,
      extracted.content,
      extracted.images || [],
      comments
    );

    // 4. Update article with analysis
    await supabase
      .from("articles")
      .update({
        analysis: analysis,
        status: "ready",
      })
      .eq("id", article_id);

    console.log(`Article ${article_id} processed successfully`);

    return new Response(
      JSON.stringify({ success: true, article_id }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error processing article:", error);

    // Try to update article status to failed
    try {
      const { article_id } = await req.json();
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
      await supabase
        .from("articles")
        .update({ 
          status: "failed",
          error_message: error.message 
        })
        .eq("id", article_id);
    } catch {}

    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    );
  }
});

function extractCommentsFromContent(content: string): any[] {
  // Simple extraction - in production, use more sophisticated parsing
  // This is a placeholder that would need to be customized per site
  const comments: any[] = [];
  
  // Look for common comment patterns
  const commentPatterns = [
    /(?:^|\n)(?:[-•>]|\d+\.)\s*(.+?)(?=\n(?:[-•>]|\d+\.)|\n\n|$)/g,
  ];
  
  // For now, return empty - would need site-specific parsing
  return comments;
}

async function analyzeWithClaude(
  title: string,
  content: string,
  images: Array<{ src: string; alt?: string }>,
  comments: any[]
): Promise<any> {
  
  // Prepare messages for Claude
  const messages: any[] = [];
  
  // Text analysis
  const textPrompt = `Analyze this article and provide a structured analysis.

Title: ${title}

Content:
${content.slice(0, 15000)} ${content.length > 15000 ? '...[truncated]' : ''}

${comments.length > 0 ? `
Discussion/Comments Summary:
${JSON.stringify(comments.slice(0, 10))}
` : ''}

Provide your analysis in the following JSON format:
{
  "summary": "A concise 2-3 sentence summary of the main points",
  "key_points": ["Key point 1", "Key point 2", "Key point 3", "Key point 4", "Key point 5"],
  "topics": ["topic1", "topic2", "topic3"],
  "sentiment": "positive|negative|neutral|mixed",
  "reading_time_minutes": <estimated reading time>,
  "comments_summary": "Brief summary of the discussion if comments exist, or null"
}

Return ONLY the JSON, no other text.`;

  messages.push({
    role: "user",
    content: textPrompt,
  });

  // Call Claude API
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY!,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1024,
      messages: messages,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Claude API error: ${error}`);
  }

  const claudeResponse = await response.json();
  const analysisText = claudeResponse.content[0].text;
  
  // Parse JSON from response
  const analysis = JSON.parse(analysisText);

  // Analyze images if present (multi-modal)
  if (images.length > 0) {
    analysis.image_analyses = await analyzeImages(images.slice(0, 5));
  }

  return analysis;
}

async function analyzeImages(
  images: Array<{ src: string; alt?: string }>
): Promise<any[]> {
  const analyses: any[] = [];

  for (const image of images) {
    try {
      // Fetch image and convert to base64
      const imageResponse = await fetch(image.src);
      if (!imageResponse.ok) continue;

      const imageBuffer = await imageResponse.arrayBuffer();
      const base64 = btoa(String.fromCharCode(...new Uint8Array(imageBuffer)));
      
      // Determine media type
      const contentType = imageResponse.headers.get("content-type") || "image/jpeg";

      // Call Claude with image
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY!,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-haiku-4-5-20251001",
          max_tokens: 512,
          messages: [{
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: contentType,
                  data: base64,
                },
              },
              {
                type: "text",
                text: `Describe this image briefly and explain how it relates to the article. Return JSON:
{
  "description": "Brief description of what's in the image",
  "objects": ["object1", "object2"],
  "relevance": "How this image relates to the article content"
}
Return ONLY JSON.`,
              },
            ],
          }],
        }),
      });

      if (response.ok) {
        const claudeResponse = await response.json();
        const imageAnalysis = JSON.parse(claudeResponse.content[0].text);
        analyses.push({
          image_url: image.src,
          ...imageAnalysis,
        });
      }
    } catch (e) {
      console.error(`Failed to analyze image ${image.src}:`, e);
    }
  }

  return analyses;
}
