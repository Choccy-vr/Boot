// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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

interface reqPayload {
  shipId: number;
}

interface HackClubUserInfo {
  sub: string;
  email: string;
  name?: string;
  given_name?: string;
  family_name?: string;
  preferred_username?: string;
  birthdate?: string;
  address?: {
    street_address?: string;
    locality?: string;
    region?: string;
    country?: string;
    postal_code?: string;
  };
}

const AIRTABLE_TOKEN = Deno.env.get("AIRTABLE_PAT") ?? "";
const AIRTABLE_BASE_ID = Deno.env.get("AIRTABLE_BASE_ID") ?? "";

const logFailure = (step: string, details?: unknown) => {
  if (details === undefined) {
    console.error(`[ship-thingy] ${step}`);
    return;
  }

  console.error(`[ship-thingy] ${step}`, details);
};

const extractGithubUsername = (repoUrl: unknown): string => {
  if (typeof repoUrl !== "string" || repoUrl.trim() === "") {
    return "";
  }

  const normalized = repoUrl.startsWith("http://") || repoUrl.startsWith("https://")
    ? repoUrl
    : `https://${repoUrl}`;

  try {
    const parsed = new URL(normalized);
    const hostname = parsed.hostname.toLowerCase();

    if (hostname !== "github.com" && hostname !== "www.github.com") {
      return "";
    }

    const parts = parsed.pathname.split("/").filter(Boolean);
    if (parts.length < 1) {
      return "";
    }

    return parts[0];
  } catch {
    return "";
  }
};

const fromBase64 = (base64: string) =>
  Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));

const extractBearerToken = (authorizationHeader: string): string => {
  const normalizedHeader = authorizationHeader.trim();
  const bearerPrefix = /^Bearer\s+/i;

  if (!bearerPrefix.test(normalizedHeader)) {
    return "";
  }

  return normalizedHeader.replace(bearerPrefix, "").trim();
};

const fetchWithTimeout = (url: string, options: RequestInit & { timeout?: number } = {}) => {
  const { timeout = 10000, ...fetchOptions } = options;
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);
  
  return fetch(url, { ...fetchOptions, signal: controller.signal })
    .then(res => {
      clearTimeout(timeoutId);
      return res;
    })
    .catch(err => {
      clearTimeout(timeoutId);
      throw err;
    });
};

const decryptAccessToken = async (encryptedToken: string): Promise<string> => {
  const masterKeyB64 = Deno.env.get("ACCESS_TOKEN_SECRET") ?? "";
  if (!masterKeyB64) {
    logFailure("Missing ACCESS_TOKEN_SECRET");
    throw new Error("Missing ACCESS_TOKEN_SECRET");
  }

  const [ivB64, ciphertextB64] = encryptedToken.split(":");
  if (!ivB64 || !ciphertextB64) {
    logFailure("Invalid encrypted token format");
    throw new Error("Invalid encrypted token format");
  }

  const keyBytes = fromBase64(masterKeyB64);
  if (keyBytes.length !== 32) {
    logFailure("ACCESS_TOKEN_SECRET must decode to 32 bytes");
    throw new Error("ACCESS_TOKEN_SECRET must decode to 32 bytes");
  }

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "AES-GCM" },
    false,
    ["decrypt"]
  );

  const iv = fromBase64(ivB64);
  const ciphertext = fromBase64(ciphertextB64);

  const plaintextBuffer = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    cryptoKey,
    ciphertext
  );

  return new TextDecoder().decode(plaintextBuffer);
};

async function insertAirtableRow(table: string, fields: Record<string, unknown>) {
  logFailure("Airtable insert starting", { table });
  
  if (!AIRTABLE_TOKEN) {
    logFailure("Missing AIRTABLE_PAT - skipping Airtable insert");
    return;
  }

  if (!AIRTABLE_BASE_ID) {
    logFailure("Missing AIRTABLE_BASE_ID - skipping Airtable insert");
    return;
  }

  const res = await fetchWithTimeout('https://api.airtable.com/v0/' + AIRTABLE_BASE_ID + '/' + encodeURIComponent(table), {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${AIRTABLE_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ fields, typecast: true }),
    timeout: 10000
  });

  if(!res.ok) {
    const errorText = await res.text();
    logFailure("Airtable insert failed", { table, status: res.status, errorText });
    throw new Error(`Airtable insert failed: ${res.status} ${errorText}`);
  }
  logFailure("Airtable insert succeeded", { table });
  return await res.json();

}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const corsHeaders = buildCorsHeaders(origin);

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const now = new Date();
  const BOOT_FULLY_LOCKED = new Date("2026-06-08T23:59:00-04:00");
  if (now > BOOT_FULLY_LOCKED) {
    logFailure("Action blocked - Boot is fully locked");
    return new Response(JSON.stringify({ message: "Boot is fully locked. No further modifications are allowed." }), {
      status: 403,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (req.method !== "POST") {
    logFailure("Method not allowed", { method: req.method });
    return new Response(JSON.stringify({ message: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      logFailure("Missing auth header");
      return new Response(JSON.stringify({ message: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authToken = extractBearerToken(authHeader);
    const isServiceRole = authToken !== "" && authToken === serviceRoleKey.trim();

    if (!serviceRoleKey) {
      logFailure("Missing SUPABASE_SERVICE_ROLE_KEY in function environment");
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      serviceRoleKey
    );

    if (!isServiceRole) {
      const supabaseUser = createClient(
        Deno.env.get("SUPABASE_URL") ?? "",
        Deno.env.get("SUPABASE_ANON_KEY") ?? "",
        { global: { headers: { Authorization: authHeader } } }
      );

      const {
        data: { user },
      } = await supabaseUser.auth.getUser();

      if (!user) {
        logFailure("Auth token did not resolve to a user", {
          authHeaderPresent: true,
          serviceRoleMatch: isServiceRole,
        });
        return new Response(JSON.stringify({ message: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const { data: roleRow } = await supabaseAdmin
        .from("users")
        .select("role")
        .eq("id", user.id)
        .maybeSingle();

      if (!roleRow || !["admin", "reviewer"].includes(roleRow.role)) {
        logFailure("Forbidden: user is not an admin or reviewer", {
          userId: user.id,
          role: roleRow?.role,
        });
        return new Response(JSON.stringify({ message: "Forbidden" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const { shipId }: reqPayload = await req.json();

    if (!shipId) {
      logFailure("Missing shipId in request body");
      return new Response(JSON.stringify({ message: "shipId required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get ship (single row)
    const { data: shipRows, error: shipFetchError } = await supabaseAdmin
      .from("ships")
      .select("*")
      .eq("id", shipId);

    if (shipFetchError) {
      logFailure("Failed to fetch ship", { shipId, error: shipFetchError });
      throw shipFetchError;
    }
    if (!shipRows || shipRows.length === 0) {
      logFailure("Ship not found", { shipId });
      throw new Error("Ship not found");
    }

    let ship = shipRows[0];

    // Update the project's shipped status to false whether the ship is denied or approved
    const { error: shippedUpdateError } = await supabaseAdmin
      .from("projects")
      .update({ shipped: false })
      .eq("id", ship.project);

    if (shippedUpdateError) {
      logFailure("Failed to update project shipped status", { shipId, projectId: ship.project, error: shippedUpdateError });
      throw shippedUpdateError;
    }

    if (!ship.approved) {
      logFailure("Ship not approved", { shipId });
      throw new Error("Not Approved");
    }

    const { data: project_temp, error: projectError } = await supabaseAdmin
      .from("projects")
      .select("*")
      .eq("id", ship.project)
      .maybeSingle();

    if (projectError) {
      logFailure("Failed to fetch project", { shipId, projectId: ship.project, error: projectError });
      throw projectError;
    }
    if (!project_temp) {
      logFailure("Project not found", { shipId, projectId: ship.project });
      throw new Error("Project Not Found");
    }

    let project = project_temp;

    let multiplier = 1;

    let technicality = ship.technicality;
    let functionality = ship.functionality;
    let ux = ship.ux;

    if (project.level == "scratch") {
      multiplier = 1.5 + (technicality + functionality + ux) / 15;
    } else {
      multiplier = 1 + (technicality + functionality + ux) / 15;
    }

    let bountyCoins = 0;
    const keys: string[] = [];

    const challengesCompleted: number[] = Array.isArray(
      ship.challenges_completed
    )
      ? ship.challenges_completed
      : [];

    if (challengesCompleted.length > 0) {
      // Batch fetch challenges
      const { data: challengeRows, error: challengeError } =
        await supabaseAdmin
          .from("challenges")
          .select("id, coins, key")
          .in("id", challengesCompleted);

      if (challengeError) {
        logFailure("Failed to fetch challenges", { shipId, challengeIds: challengesCompleted, error: challengeError });
        throw challengeError;
      }
      const safeChallengeRows = Array.isArray(challengeRows)
        ? challengeRows
        : [];
      const projectChallenges: number[] = Array.isArray(project.challenges)
        ? project.challenges
        : [];
      const projectPending: number[] = Array.isArray(
        project.pending_challenges
      )
        ? project.pending_challenges
        : [];

      for (let i = 0; i < safeChallengeRows.length; i++) {
        const row = safeChallengeRows[i];
        if (row?.coins && row.coins !== 0) {
          bountyCoins += row.coins;
        } else if (row?.key && row.key !== "") {
          keys.push(row.key);
        }

        if (row?.id != null && !projectChallenges.includes(row.id)) {
          projectChallenges.push(row.id);
        }
        const indexToRemove = projectPending.indexOf(row?.id);

        if (indexToRemove > -1) {
          projectPending.splice(indexToRemove, 1);
        }
      }

      project.challenges = projectChallenges;
      project.pending_challenges = projectPending;

      const { error: projectUpdateError } = await supabaseAdmin
        .from("projects")
        .update({
          challenges: projectChallenges,
          pending_challenges: projectPending,
        })
        .eq("id", project.id);

      if (projectUpdateError) {
        logFailure("Failed to update project challenge state", { shipId, projectId: project.id, error: projectUpdateError });
        throw projectUpdateError;
      }
    }

    let coinsEarned: number;

    // Compute coins earned and round up
    if (ship.override_hours == 0 || ship.override_hours == null) {
      const coinsEarnedFloat = (Number(ship.time) || 0) * 30 * multiplier;
      coinsEarned = Math.ceil(coinsEarnedFloat);
    } else {
      const overrideCoinsEarnedFloat =
        (Number(ship.override_hours) || 0) * 30 * multiplier;
      coinsEarned = Math.ceil(overrideCoinsEarnedFloat);
    }

    coinsEarned += bountyCoins;

    // Safety check: ensure integers for bigint columns
    if (!Number.isInteger(coinsEarned)) {
      logFailure("Rounded coins were not an integer", { shipId, coinsEarned });
      throw new Error("Rounded values are not integers");
    }

    // write to ships; return updated row to validate the write
    const { data: updatedShip, error: shipWriteError } = await supabaseAdmin
      .from("ships")
      .update({ multiplier: multiplier, earned: coinsEarned })
      .eq("id", shipId)
      .eq("earned", 0) // Only update if earned & multipler is still 0/1
      .eq("multiplier", 1)
      .select("*")
      .maybeSingle();

    if (shipWriteError) {
      logFailure("Failed to update ship", { shipId, error: shipWriteError });
      throw shipWriteError;
    }
    if (!updatedShip) {
      logFailure("Ship update affected no rows", { shipId });
      throw new Error("Ship update affected no rows");
    }

    // Get user (single)
    const { data: userRow, error: userError } = await supabaseAdmin
      .from("users")
      .select("*")
      .eq("id", project.owner)
      .maybeSingle();

    if (userError) {
      logFailure("Failed to fetch project owner user", { shipId, userId: project.owner, error: userError });
      throw userError;
    }
    if (!userRow) {
      logFailure("User not found", { shipId, userId: project.owner });
      throw new Error("User Not Found");
    }

    //write to airtable
    // decrypt HCA access token
    const encryptedAccessToken =
      userRow.access_token_encrypted ?? userRow.encrypted_access_token;

    if(!encryptedAccessToken) {
      logFailure("User is missing encrypted Hack Club access token", { shipId, userId: userRow.id });
      throw new Error("User has no encrypted Hack Club access token");
    }

    const accessToken = await decryptAccessToken(encryptedAccessToken);
    
    // make HCA calls to get address, name, email and bday
    logFailure("[HCA] Starting userinfo fetch", { shipId });
    const userInfoResponse = await fetchWithTimeout(
      "https://auth.hackclub.com/oauth/userinfo",
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
        timeout: 10000
      }
    );

    if (!userInfoResponse.ok) {
      logFailure("[HCA] Userinfo fetch failed", {
        shipId,
        status: userInfoResponse.status,
        errorText: await userInfoResponse.text(),
      });
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

    logFailure("[HCA] Parsing userinfo JSON", { shipId });
    const userInfo: HackClubUserInfo = await userInfoResponse.json();
    logFailure("[HCA] Userinfo received successfully", { shipId });

    if (!userInfo.sub || !userInfo.email || !userInfo.birthdate || !userInfo.name || !userInfo.address) {
      logFailure("[HCA] Userinfo missing required fields", { shipId, userInfo });
      return new Response(
        JSON.stringify({ error: "Invalid user info: missing sub, email, birthdate, name, or address" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const githubUsername = extractGithubUsername(project.github_repo);

    // call airtable api; log failures but don't block the response
    try {
      await insertAirtableRow('YSWS Project Submission', {
        'Code URL': project.github_repo,
        'Playable URL': project.github_repo,
        'How did you hear about this?': updatedShip.where_feedback,
        'What are we doing well?': updatedShip.good_feedback,
        'How can we improve?': updatedShip.improve_feedback,
        'First Name': userInfo.given_name,
        'Last Name': userInfo.family_name,
        'Email': userInfo.email,
        'Screenshot': [{ url: updatedShip.screenshot_url }],
        'Description': project.description,
        'GitHub Username': githubUsername,
        'Address (Line 1)': userInfo.address.street_address,
        'City': userInfo.address.locality,
        'State / Province': userInfo.address.region,
        'Country': userInfo.address.country,
        'ZIP / Postal Code': userInfo.address.postal_code,
        'Birthday': userInfo.birthdate,
        'Automation - Submit to Unified YSWS': false,
        ...(updatedShip.override_hours != null
      ? {
          "Optional - Override Hours Spent": updatedShip.override_hours,
          "Optional - Override Hours Spent Justification":
            `This project was submitted by ${userRow.username} on ${updatedShip.created_at}.
This project was approved for ${updatedShip.time} hours.
Justification for override hours: ${updatedShip.override_justification}"}

[INSERT Description Here]

This project has ${updatedShip.time} Hackatime-tracked hours.

The Hackatime projects were: 
${(project.hackatime_projects || []).length > 0 ? (project.hackatime_projects).map((hp: string) => `- ${hp}`).join("\n") : "None tracked"}

The project was approved by 'Ginobeano' on ${new Date().toLocaleDateString()}..`
        }
      : {
          "Optional - Override Hours Spent": updatedShip.time,
          "Optional - Override Hours Spent Justification":
  `This project was submitted by ${userRow.username} on ${updatedShip.created_at}.
This project was approved for ${updatedShip.time} hours.

[INSERT Description Here]

This project has ${updatedShip.time} Hackatime-tracked hours.

The Hackatime projects were: 
${(project.hackatime_projects || []).length > 0 ? (project.hackatime_projects).map((hp: string) => `- ${hp}`).join("\n") : "None tracked"}

The project was approved by 'Ginobeano' on ${new Date().toLocaleDateString()}..`
      }),
      });
    } catch (airtableError) {
      logFailure("Airtable insert failed but continuing with response", {
        shipId,
        error: airtableError instanceof Error ? airtableError.message : String(airtableError),
      });
    }



    

    // write coins to user; return updated user row
    const newBootCoins = Number(userRow.boot_coins || 0) + coinsEarned;
    const existingKeys = Array.isArray(userRow.keys) ? userRow.keys : [];
    const newKeys = [...existingKeys, ...keys];

    const { data: updatedUser, error: userWriteError } = await supabaseAdmin
      .from("users")
      .update({ boot_coins: newBootCoins, keys: newKeys })
      .eq("id", userRow.id)
      .select("*")
      .maybeSingle();

    if (userWriteError) {
      logFailure("Failed to update user coins and keys", { shipId, userId: userRow.id, error: userWriteError });
      throw userWriteError;
    }
    if (!updatedUser) {
      logFailure("User update affected no rows", { shipId, userId: userRow.id });
      throw new Error("User update affected no rows");
    }

    return new Response(
      JSON.stringify({
        ship: updatedShip,
        user: updatedUser,
        project,
        multiplier: multiplier,
        coinsEarned,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err: any) {
    console.error("[ship-thingy] Function error:", err);
    return new Response(
      JSON.stringify({ message: err?.message ?? String(err) }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});