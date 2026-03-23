import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((o: string) => o.trim())
  .filter(Boolean);

const buildCorsHeaders = (origin: string | null) => {
  const isAllowed = origin && allowedOrigins.includes(origin);
  return {
    "Access-Control-Allow-Origin": isAllowed ? origin : "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
};

const jsonResponse = (
  payload: Record<string, unknown>,
  status: number,
  corsHeaders: Record<string, string>,
) => {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
};

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");
  const corsHeaders = buildCorsHeaders(origin);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, corsHeaders);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Unauthorized" }, 401, corsHeaders);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    if (!supabaseUrl || !supabaseAnonKey) {
      return jsonResponse(
        { error: "Server configuration error" },
        500,
        corsHeaders,
      );
    }

    // Require a valid authenticated Supabase user to call token exchange.
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401, corsHeaders);
    }

    const body = await req.json();
    const clientId = String(body?.client_id ?? "").trim();
    const code = String(body?.code ?? "").trim();
    const redirectUri = String(body?.redirect_uri ?? "").trim();
    const codeVerifier = String(body?.code_verifier ?? "").trim();

    if (!clientId || !code || !redirectUri || !codeVerifier) {
      return jsonResponse(
        {
          error:
            "Missing required fields: client_id, code, redirect_uri, code_verifier",
        },
        400,
        corsHeaders,
      );
    }

    const form = new URLSearchParams({
      client_id: clientId,
      code,
      redirect_uri: redirectUri,
      grant_type: "authorization_code",
      code_verifier: codeVerifier,
    });

    const tokenResponse = await fetch("https://hackatime.hackclub.com/oauth/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form,
    });

    const rawBody = await tokenResponse.text();
    let parsedBody: unknown = null;

    if (rawBody) {
      try {
        parsedBody = JSON.parse(rawBody);
      } catch {
        parsedBody = { raw: rawBody };
      }
    }

    if (!tokenResponse.ok) {
      console.error("Hackatime token exchange failed", {
        status: tokenResponse.status,
        body: parsedBody,
      });

      return jsonResponse(
        {
          error: "Hackatime token exchange failed",
          status: tokenResponse.status,
          details: parsedBody,
        },
        tokenResponse.status,
        corsHeaders,
      );
    }

    return jsonResponse(
      (parsedBody as Record<string, unknown>) ?? {},
      200,
      corsHeaders,
    );
  } catch (error) {
    console.error("Unhandled hackatime_auth error", error);
    return jsonResponse(
      {
        error: "Unexpected error during Hackatime token exchange",
      },
      500,
      corsHeaders,
    );
  }
});
