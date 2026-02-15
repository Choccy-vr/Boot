// Edge function to handle complete Hack Club OIDC flow
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

const redirectAllowlist = (Deno.env.get("HACKCLUB_REDIRECT_ALLOWLIST") ?? "")
  .split(",")
  .map((u) => u.trim().replace(/^['\"]|['\"]$/g, ""))
  .filter(Boolean);

const normalizeRedirectUri = (value: string): string | null => {
  const raw = value.trim().replace(/^['\"]|['\"]$/g, "");
  const variants = [raw];

  try {
    const decoded = decodeURIComponent(raw);
    if (decoded !== raw) {
      variants.push(decoded);
    }
  } catch {
    // Keep raw variant only when decoding fails
  }

  for (const variant of variants) {
    try {
      const parsed = new URL(variant);
      const pathname = parsed.pathname.replace(/\/+$/, "") || "/";
      const hasDefaultHttpPort = parsed.protocol === "http:" && parsed.port === "80";
      const hasDefaultHttpsPort = parsed.protocol === "https:" && parsed.port === "443";
      const port =
        parsed.port && !hasDefaultHttpPort && !hasDefaultHttpsPort
          ? `:${parsed.port}`
          : "";

      return `${parsed.protocol}//${parsed.hostname.toLowerCase()}${port}${pathname}${parsed.search}`;
    } catch {
      // Try next variant
    }
  }

  return null;
};

const normalizedRedirectAllowlist = redirectAllowlist
  .map((u) => normalizeRedirectUri(u))
  .filter((u): u is string => Boolean(u));

const buildCorsHeaders = (origin: string | null) => {
  const isAllowed = origin && allowedOrigins.includes(origin);
  return {
    "Access-Control-Allow-Origin": isAllowed ? origin : "null",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
};

interface TokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token?: string;
  id_token?: string;
}

interface HackClubUserInfo {
  sub: string; // ident!xxx
  email: string;
  email_verified: boolean;
  name?: string;
  given_name?: string;
  family_name?: string;
  nickname?: string;
  slack_id?: string;
  verification_status?: string;
  ysws_eligible?: boolean;
}

serve(async (req) => {
  const origin = req.headers.get("origin");
  const corsHeaders = buildCorsHeaders(origin);

  // Handle CORS preflight
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
    const { code, redirect_uri } = await req.json();
    const normalizedRedirectUri = normalizeRedirectUri(redirect_uri ?? "");

    if (!code || !redirect_uri) {
      return new Response(
        JSON.stringify({ error: "Missing code or redirect_uri" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!normalizedRedirectUri) {
      return new Response(
        JSON.stringify({ error: "Invalid redirect_uri format" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (
      normalizedRedirectAllowlist.length > 0 &&
      !normalizedRedirectAllowlist.includes(normalizedRedirectUri)
    ) {
      return new Response(
        JSON.stringify({
          error: "Invalid redirect_uri",
          redirect_uri,
          normalized_redirect_uri: normalizedRedirectUri,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const clientId = Deno.env.get("HACKCLUB_CLIENT_ID");
    const clientSecret = Deno.env.get("HACKCLUB_CLIENT_SECRET");

    if (!clientId || !clientSecret) {
      console.error("Missing Hack Club credentials");
      return new Response(
        JSON.stringify({ error: "Server configuration error" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Step 1: Exchange authorization code for tokens
    const tokenResponse = await fetch("https://auth.hackclub.com/oauth/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirect_uri,
        code: code,
        grant_type: "authorization_code",
      }),
    });

    if (!tokenResponse.ok) {
      console.error("Token exchange failed:", await tokenResponse.text());
      return new Response(
        JSON.stringify({
          error: "Failed to exchange code for tokens",
        }),
        {
          status: tokenResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const tokens: TokenResponse = await tokenResponse.json();

    // Step 2: Fetch user info from Hack Club
    const userInfoResponse = await fetch(
      "https://auth.hackclub.com/oauth/userinfo",
      {
        headers: {
          Authorization: `Bearer ${tokens.access_token}`,
        },
      }
    );

    if (!userInfoResponse.ok) {
      console.error("UserInfo fetch failed:", await userInfoResponse.text());
      return new Response(
        JSON.stringify({
          error: "Failed to fetch user info",
        }),
        {
          status: userInfoResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const userInfo: HackClubUserInfo = await userInfoResponse.json();

    // Validate user info
    if (!userInfo.sub || !userInfo.email) {
      return new Response(
        JSON.stringify({ error: "Invalid user info: missing sub or email" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Step 3: Create Supabase admin client
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // Step 4: Check if user exists by hc_user_id (since email column is removed from public.users)
    const { data: existingUsers, error: getUserError } = await supabaseAdmin
      .from("users")
      .select("id, slack_user_id")
      .eq("hc_user_id", userInfo.sub)
      .limit(1);

    if (getUserError) {
      console.error("Error checking existing user:", getUserError);
    }

    let supabaseUserId: string;

    if (existingUsers && existingUsers.length > 0) {
      // User exists - update their Hack Club metadata
      supabaseUserId = existingUsers[0].id;

      // Update user metadata
      const updateData = {
        slack_user_id: userInfo.slack_id || existingUsers[0].slack_user_id,
        hc_user_id: userInfo.sub,
        ysws_eligible: userInfo.ysws_eligible ?? null,
        verification_status: userInfo.verification_status === "verified",
      };

      const { error: updateError } = await supabaseAdmin
        .from("users")
        .update(updateData)
        .eq("id", supabaseUserId);

      if (updateError) {
        console.error("Error updating user:", updateError);
      }

      // Update auth user metadata
      await supabaseAdmin.auth.admin.updateUserById(supabaseUserId, {
        user_metadata: {
          hackclub_id: userInfo.sub,
          slack_id: userInfo.slack_id,
          verification_status: userInfo.verification_status,
          ysws_eligible: userInfo.ysws_eligible,
        },
      });
    } else {
      // Step 5: Create new Supabase auth user
      const { data: authData, error: authError } =
        await supabaseAdmin.auth.admin.createUser({
          email: userInfo.email,
          email_confirm: userInfo.email_verified,
          user_metadata: {
            hackclub_id: userInfo.sub,
            name: userInfo.name,
            given_name: userInfo.given_name,
            family_name: userInfo.family_name,
            nickname: userInfo.nickname,
            slack_id: userInfo.slack_id,
            verification_status: userInfo.verification_status,
            ysws_eligible: userInfo.ysws_eligible,
          },
        });

      if (authError) {
        // If user already exists, try to recover the user ID
        if (authError.message.includes("already been registered")) {
          const { data: linkData, error: linkError } =
            await supabaseAdmin.auth.admin.generateLink({
              type: "magiclink",
              email: userInfo.email,
            });

          if (linkError || !linkData.user) {
            console.error("Failed to recover existing user:", linkError);
            return new Response(
              JSON.stringify({
                error: "User exists in Auth but failed to recover details",
              }),
              {
                status: 500,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
              }
            );
          }

          const authUser = linkData.user;
          supabaseUserId = authUser.id;

          await supabaseAdmin.auth.admin.updateUserById(supabaseUserId, {
            user_metadata: {
              hackclub_id: userInfo.sub,
              slack_id: userInfo.slack_id,
              verification_status: userInfo.verification_status,
              ysws_eligible: userInfo.ysws_eligible,
            },
          });
        } else {
          console.error("Error creating Supabase user:", authError);
          return new Response(
            JSON.stringify({
              error: "Failed to create Supabase user",
            }),
            {
              status: 500,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }
      } else if (!authData.user) {
        return new Response(
          JSON.stringify({
            error: "Failed to obtain user object after creation",
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      } else {
        supabaseUserId = authData.user.id;
      }

      // Create user record in users table
      const insertData = {
        id: supabaseUserId,
        username:
          userInfo.nickname ||
          userInfo.name ||
          userInfo.email.split("@")[0] ||
          `user_${supabaseUserId.slice(0, 8)}`,
        bio: "Nothing Yet",
        boot_coins: 0,
        profile_picture_url: "",
        total_projects: 0,
        total_devlogs: 0,
        total_votes: 0,
        slack_user_id: userInfo.slack_id || "",
        hc_user_id: userInfo.sub,
        ysws_eligible: userInfo.ysws_eligible ?? null,
        verification_status: userInfo.verification_status === "verified",
      };

      const { error: insertError } = await supabaseAdmin
        .from("users")
        .insert(insertData);

      if (insertError) {
        console.error("Error creating user record:", insertError);
        return new Response(
          JSON.stringify({
            error: "Failed to create user record",
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    }

    // Step 6: Generate a session using magic link approach
    const tempPassword = crypto.randomUUID();

    const { error: passwordError } =
      await supabaseAdmin.auth.admin.updateUserById(supabaseUserId, {
        password: tempPassword,
      });

    if (passwordError) {
      console.error("Error setting password:", passwordError);
      return new Response(
        JSON.stringify({
          error: "Failed to set user password",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { data: signInData, error: signInError } =
      await supabaseAdmin.auth.signInWithPassword({
        email: userInfo.email,
        password: tempPassword,
      });

    if (signInError || !signInData?.session) {
      console.error("Error signing in user:", signInError);
      return new Response(
        JSON.stringify({
          error: "Failed to create session",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({
        access_token: signInData.session.access_token,
        refresh_token: signInData.session.refresh_token,
        expires_in: signInData.session.expires_in || 3600,
        token_type: "bearer",
        user: {
          id: supabaseUserId,
          email: userInfo.email,
          user_metadata: {
            hackclub_id: userInfo.sub,
            name: userInfo.name,
            slack_id: userInfo.slack_id,
            verification_status: userInfo.verification_status,
            ysws_eligible: userInfo.ysws_eligible,
          },
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({
        error: "Internal server error",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});