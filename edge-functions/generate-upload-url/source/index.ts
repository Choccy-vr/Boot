import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

const buildCorsHeaders = (origin: string | null) => {
  const isAllowed = origin && allowedOrigins.includes(origin);
  return {
    "Access-Control-Allow-Origin": isAllowed ? origin : "null",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
};

const allowedContentTypes = (Deno.env.get("UPLOAD_ALLOWED_CONTENT_TYPES") ??
  "image/jpeg,image/png,image/webp,image/gif")
  .split(",")
  .map((t) => t.trim())
  .filter(Boolean);

serve(async (req) => {
  const origin = req.headers.get("origin");
  const corsHeaders = buildCorsHeaders(origin);

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("Missing authorization header");
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    const {
      data: { user },
    } = await supabaseClient.auth.getUser();

    if (!user) {
      throw new Error("Unauthorized");
    }

    const { path, contentType } = await req.json();

    if (!path || !contentType) {
      throw new Error("Missing path or contentType");
    }

    if (!allowedContentTypes.includes(contentType)) {
      throw new Error("Invalid content type");
    }

    const requiredPrefix = `profiles/${user.id}/`;
    if (!path.startsWith(requiredPrefix)) {
      throw new Error("Invalid upload path");
    }

    const accountId = Deno.env.get("R2_ACCOUNT_ID");
    const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID");
    const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY");

    if (!accountId || !accessKeyId || !secretAccessKey) {
      throw new Error("R2 credentials not configured");
    }

    const bucket = "boot";
    const region = "us-east-1";
    const host = `${accountId}.r2.cloudflarestorage.com`;
    const sanitizedPath = path
      .split("/")
      .filter((s: string) => s.length > 0)
      .join("/");
    const objectKey = `/${bucket}/${sanitizedPath}`;

    const expiresIn = 900; // 15 minutes
    const timestamp = new Date();
    const amzDate =
      timestamp
        .toISOString()
        .replace(/[:-]|\.\d{3}/g, "")
        .slice(0, -1) + "Z";
    const dateStamp = amzDate.slice(0, 8);

    const credentialScope = `${dateStamp}/${region}/s3/aws4_request`;
    const signedHeaders = "content-type;host";

    const canonicalHeaders = [
      `content-type:${contentType}`,
      `host:${host}`,
      "",
    ].join("\n");

    const queryParams = {
      "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
      "X-Amz-Credential": `${accessKeyId}/${credentialScope}`,
      "X-Amz-Date": amzDate,
      "X-Amz-Expires": expiresIn.toString(),
      "X-Amz-SignedHeaders": signedHeaders,
    };

    const canonicalQueryString = buildCanonicalQuery(queryParams);

    const canonicalRequest = [
      "PUT",
      objectKey,
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      "UNSIGNED-PAYLOAD",
    ].join("\n");

    const encoder = new TextEncoder();
    const canonicalRequestHash = await crypto.subtle.digest(
      "SHA-256",
      encoder.encode(canonicalRequest)
    );
    const canonicalRequestHashHex = Array.from(
      new Uint8Array(canonicalRequestHash)
    )
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    const stringToSign = [
      "AWS4-HMAC-SHA256",
      amzDate,
      credentialScope,
      canonicalRequestHashHex,
    ].join("\n");

    const kDate = await hmacSha256(
      encoder.encode(`AWS4${secretAccessKey}`),
      dateStamp
    );
    const kRegion = await hmacSha256(kDate, region);
    const kService = await hmacSha256(kRegion, "s3");
    const kSigning = await hmacSha256(kService, "aws4_request");
    const signature = await hmacSha256(kSigning, stringToSign);

    const signatureHex = Array.from(new Uint8Array(signature))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    const signedQuery = `${canonicalQueryString}&X-Amz-Signature=${encodeRFC3986(
      signatureHex
    )}`;

    const uploadUrl = `https://${host}${objectKey}?${signedQuery}`;

    return new Response(
      JSON.stringify({
        uploadUrl,
        expiresIn,
        contentType,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function hmacSha256(
  key: Uint8Array | ArrayBuffer,
  data: string
): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  return await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    new TextEncoder().encode(data)
  );
}

function encodeRFC3986(value: string) {
  return encodeURIComponent(value).replace(/[!'()*]/g, (c) =>
    "%" + c.charCodeAt(0).toString(16).toUpperCase()
  );
}

function buildCanonicalQuery(params: Record<string, string>) {
  return Object.keys(params)
    .sort()
    .map((key) => `${encodeRFC3986(key)}=${encodeRFC3986(params[key])}`)
    .join("&");
}