// Edge function to handle complete Hack Club OAuth flow
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { code, redirect_uri } = await req.json();

    if (!code || !redirect_uri) {
      return new Response(
        JSON.stringify({ error: "Missing code or redirect_uri" }),
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
      const errorText = await tokenResponse.text();
      console.error("Token exchange failed:", errorText);
      return new Response(
        JSON.stringify({
          error: "Failed to exchange code for tokens",
          details: errorText,
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
      const errorText = await userInfoResponse.text();
      console.error("UserInfo fetch failed:", errorText);
      return new Response(
        JSON.stringify({
          error: "Failed to fetch user info",
          details: errorText,
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

    // Step 4: Check if user exists by email
    const { data: existingUsers, error: getUserError } = await supabaseAdmin
      .from("users")
      .select("id, email, slack_user_id")
      .eq("email", userInfo.email)
      .limit(1);

    if (getUserError) {
      console.error("Error checking existing user:", getUserError);
    }

    let supabaseUserId: string;

    if (existingUsers && existingUsers.length > 0) {
      // User exists - update their Hack Club metadata
      supabaseUserId = existingUsers[0].id;
      console.log(`Found existing user: ${supabaseUserId}`);

      // Update user metadata
      const { error: updateError } = await supabaseAdmin
        .from("users")
        .update({
          slack_user_id: userInfo.slack_id || existingUsers[0].slack_user_id,
        })
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

      if (authError || !authData.user) {
        console.error("Error creating Supabase user:", authError);
        return new Response(
          JSON.stringify({
            error: "Failed to create Supabase user",
            details: authError?.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      supabaseUserId = authData.user.id;
      console.log(`Created new Supabase user: ${supabaseUserId}`);

      // Create user record in users table
      const { error: insertError } = await supabaseAdmin.from("users").insert({
        id: supabaseUserId,
        email: userInfo.email,
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
      });

      if (insertError) {
        console.error("Error creating user record:", insertError);
        return new Response(
          JSON.stringify({
            error: "Failed to create user record",
            details: insertError.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    }

    // Step 6: Generate a session using magic link approach
    // Set a temporary password and immediately sign in
    const tempPassword = crypto.randomUUID();
    
    const { error: passwordError } = await supabaseAdmin.auth.admin.updateUserById(
      supabaseUserId,
      { password: tempPassword }
    );

    if (passwordError) {
      console.error("Error setting password:", passwordError);
      return new Response(
        JSON.stringify({
          error: "Failed to set user password",
          details: passwordError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Sign in with the temporary password to get a real session
    const { data: signInData, error: signInError } = await supabaseAdmin.auth.signInWithPassword({
      email: userInfo.email,
      password: tempPassword,
    });

    if (signInError || !signInData?.session) {
      console.error("Error signing in user:", signInError);
      return new Response(
        JSON.stringify({
          error: "Failed to create session",
          details: signInError?.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Return session tokens
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
        details: error.message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
