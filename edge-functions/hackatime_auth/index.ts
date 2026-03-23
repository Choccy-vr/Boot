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

const toBase64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes));
const fromBase64 = (base64: string) =>
  Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));

const encryptAccessToken = async (token: string): Promise<string> => {
  const masterKeyB64 = Deno.env.get("ACCESS_TOKEN_SECRET") ?? "";
  if (!masterKeyB64) {
    throw new Error("Missing ACCESS_TOKEN_SECRET");
  }

  const keyBytes = fromBase64(masterKeyB64);
  if (keyBytes.length !== 32) {
    throw new Error("ACCESS_TOKEN_SECRET must decode to 32 bytes");
  }

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );

  const iv = crypto.getRandomValues(new Uint8Array(12));
  const plaintext = new TextEncoder().encode(token);
  const encrypted = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv }, cryptoKey, plaintext),
  );

  return `${toBase64(iv)}:${toBase64(encrypted)}`;
};

const decryptAccessToken = async (encryptedToken: string): Promise<string> => {
  const masterKeyB64 = Deno.env.get("ACCESS_TOKEN_SECRET") ?? "";
  if (!masterKeyB64) {
    throw new Error("Missing ACCESS_TOKEN_SECRET");
  }

  const [ivB64, ciphertextB64] = encryptedToken.split(":");
  if (!ivB64 || !ciphertextB64) {
    throw new Error("Invalid encrypted token format");
  }

  const keyBytes = fromBase64(masterKeyB64);
  if (keyBytes.length !== 32) {
    throw new Error("ACCESS_TOKEN_SECRET must decode to 32 bytes");
  }

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "AES-GCM" },
    false,
    ["decrypt"],
  );

  const iv = fromBase64(ivB64);
  const ciphertext = fromBase64(ciphertextB64);

  const plaintextBuffer = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    cryptoKey,
    ciphertext,
  );

  return new TextDecoder().decode(plaintextBuffer);
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
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
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

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    const { data: userRow, error: userRowError } = await supabaseAdmin
      .from("users")
      .select("hackatime_access_token")
      .eq("id", user.id)
      .maybeSingle();

    if (userRowError) {
      console.error("Failed to read user row", userRowError);
      return jsonResponse(
        { error: "Failed to read user row" },
        500,
        corsHeaders,
      );
    }

    const encryptedStoredToken = String(userRow?.hackatime_access_token ?? "").trim();
    if (encryptedStoredToken.length > 0) {
      try {
        const decryptedToken = await decryptAccessToken(encryptedStoredToken);
        return jsonResponse(
          {
            access_token: decryptedToken,
            token_type: "Bearer",
            source: "stored",
          },
          200,
          corsHeaders,
        );
      } catch (decryptError) {
        console.error("Failed to decrypt stored hackatime token", decryptError);
        return jsonResponse(
          { error: "Failed to decrypt stored hackatime token" },
          500,
          corsHeaders,
        );
      }
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

    const parsedBodyObject = (parsedBody as Record<string, unknown>) ?? {};
    const accessToken = String(parsedBodyObject.access_token ?? "").trim();
    if (!accessToken) {
      return jsonResponse(
        { error: "Hackatime response missing access_token" },
        500,
        corsHeaders,
      );
    }

    const encryptedToken = await encryptAccessToken(accessToken);
    const { error: updateTokenError } = await supabaseAdmin
      .from("users")
      .update({ hackatime_access_token: encryptedToken })
      .eq("id", user.id);

    if (updateTokenError) {
      console.error("Failed to store encrypted hackatime token", updateTokenError);
      return jsonResponse(
        { error: "Failed to store encrypted hackatime token" },
        500,
        corsHeaders,
      );
    }

    return jsonResponse(
      parsedBodyObject,
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
