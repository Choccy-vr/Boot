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

const AIRTABLE_TOKEN = Deno.env.get("AIRTABLE_PAT")!;
const AIRTABLE_BASE_ID = Deno.env.get("AIRTABLE_BASE_ID")!;

const fromBase64 = (base64: string) =>
  Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));

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
  const res = await fetch('https://api.airtable.com/v0/' + AIRTABLE_BASE_ID + '/' + encodeURIComponent(table), {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${AIRTABLE_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ fields, typecast: true })
  });

  if(!res.ok) throw new Error(`Airtable insert failed: ${res.status} ${await res.text()}`);
  return await res.json();

}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const corsHeaders = buildCorsHeaders(origin);

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ message: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ message: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const {
      data: { user },
    } = await supabaseUser.auth.getUser();

    if (!user) {
      return new Response(JSON.stringify({ message: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: roleRow } = await supabaseAdmin
      .from("users")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();

    if (!roleRow || !["admin", "reviewer"].includes(roleRow.role)) {
      return new Response(JSON.stringify({ message: "Forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { shipId }: reqPayload = await req.json();

    if (!shipId) {
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

    if (shipFetchError) throw shipFetchError;
    if (!shipRows || shipRows.length === 0) throw new Error("Ship not found");

    let ship = shipRows[0];

    if (!ship.approved) throw new Error("Not Approved");

    const { data: project_temp, error: projectError } = await supabaseAdmin
      .from("projects")
      .select("*")
      .eq("id", ship.project)
      .maybeSingle();

    if (projectError) throw projectError;
    if (!project_temp) throw new Error("Project Not Found");

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

      if (challengeError) throw challengeError;
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

      if (projectUpdateError) throw projectUpdateError;
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

    if (shipWriteError) throw shipWriteError;
    if (!updatedShip) throw new Error("Ship update affected no rows");

    // Get user (single)
    const { data: userRow, error: userError } = await supabaseAdmin
      .from("users")
      .select("*")
      .eq("id", project.owner)
      .maybeSingle();

    if (userError) throw userError;
    if (!userRow) throw new Error("User Not Found");

    //write to airtable
    // decrypt HCA access token
    const encryptedAccessToken =
      userRow.access_token_encrypted ?? userRow.encrypted_access_token;

    if(!encryptedAccessToken) {
      throw new Error("User has no encrypted Hack Club access token");
    }

    const accessToken = await decryptAccessToken(encryptedAccessToken);
    // make HCA calls to get address, name, email and bday
    const userInfoResponse = await fetch(
      "https://auth.hackclub.com/oauth/userinfo",
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
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

    if (!userInfo.sub || !userInfo.email || !userInfo.birthday || !userInfo.name || !userInfo.address) {
      return new Response(
        JSON.stringify({ error: "Invalid user info: missing sub, email, birthday, name, or address" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }


    //call airtable api
    insertAirtableRow('YSWS Project Submissions', {
      'Code URL': project.github_repo,
      'Playable URL': project.github_repo,
      'How did you hear about this?': updatedShip.where_feedback,
      'What are we doing well?': updatedShip.good_feedback,
      'How can we improve?': updatedShip.improve_feedback,
      'First Name': userInfo.given_name,
      'Last Name': userInfo.family_name,
      'Email': userInfo.email,
      //Screenshot?
      'Description': project.description,
      //Github Username?
      'Address (Line 1)': userInfo.address.street_address,
      'City': userInfo.address.locality,
      'State / Province': userInfo.address.region,
      'Country': userInfo.address.country,
      'ZIP / Postal Code': userInfo.address.postal_code,
      'Birthday': userInfo.birthday,
      'Automation - Submit to Unified YSWS': false, //FOR TESTING ONLY - set to true when ready
      ...(updatedShip.override_hours != null
    ? {
        "Optional - Override Hours Spent": updatedShip.override_hours,
        "Optional - Override Hours Spent Justification":
          updatedShip.override_hours_justification,
      }
    : {}),
    });



    

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

    if (userWriteError) throw userWriteError;
    if (!updatedUser) throw new Error("User update affected no rows");

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
    console.error("Function error:", err);
    return new Response(
      JSON.stringify({ message: err?.message ?? String(err) }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});