import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const COMPUTE_API = "https://compute.googleapis.com/compute/v1";

serve(async (req) => {
  try {
    // 1. Verify the user is authenticated with Supabase
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
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
      error: userError,
    } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized - invalid token" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`User ${user.email} is creating a VM`);

    // 2. Get Google Cloud credentials from environment
    const clientEmail = Deno.env.get("GOOGLE_CLIENT_EMAIL");
    const privateKey = Deno.env.get("GOOGLE_PRIVATE_KEY");
    const projectId = Deno.env.get("GOOGLE_PROJECT_ID");

    if (!clientEmail || !privateKey || !projectId) {
      return new Response(
        JSON.stringify({ error: "Missing Google Cloud credentials" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // 3. Generate a JWT for Google Cloud authentication
    const googleToken = await generateGoogleToken(clientEmail, privateKey);

    // 4. Define VM configuration
    const zone = "us-central1-a";
    const vmName = `boot-vm-${user.id.substring(0, 8)}-${Date.now()}`;
    

    const instanceConfig = {
      name: vmName,
      
      sourceMachineImage: `projects/${projectId}/global/machineImages/boot-vm-image`,
      
      // Set metadata (unique per VM)
      metadata: {
        items: [
          {
            key: "boot-user-id",
            value: user.id,
          },
          {
            key: "boot-user-email",
            value: user.email || "unknown",
          },
        ],
      },
    };

    // 5. Create the VM instance
    const createUrl = `${COMPUTE_API}/projects/${projectId}/zones/${zone}/instances`;

    const response = await fetch(createUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${googleToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(instanceConfig),
    });

    const result = await response.json();

    if (!response.ok) {
      console.error("VM creation failed:", result);
      return new Response(
        JSON.stringify({ error: "Failed to create VM", details: result }),
        { status: response.status, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log("VM creation initiated:", result);

    // 6. Wait for the VM to get an IP (poll the instance)
    let retries = 10;
    let vmDetails = null;

    while (retries > 0) {
      await new Promise((resolve) => setTimeout(resolve, 3000));

      const getUrl = `${COMPUTE_API}/projects/${projectId}/zones/${zone}/instances/${vmName}`;
      const getResponse = await fetch(getUrl, {
        headers: {
          Authorization: `Bearer ${googleToken}`,
        },
      });

      vmDetails = await getResponse.json();

      // Get external IP
      const externalIP =
        vmDetails.networkInterfaces?.[0]?.accessConfigs?.[0]?.natIP;

      if (externalIP) {
        return new Response(
          JSON.stringify({
            success: true,
            vmName: vmName,
            ip: externalIP,
            zone: zone,
            status: vmDetails.status,
            vnc: {
              port: 5901,
              connectionString: `${externalIP}:5901`,
            },
            message: "Your Boot VM is ready! Connect via VNC to start building your OS.",
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      retries--;
    }

    // If we get here, VM was created but no IP yet
    return new Response(
      JSON.stringify({
        success: false,
        vmName: vmName,
        message: "VM created but IP not ready yet. Check back in a minute.",
        status: vmDetails?.status,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error in create-vm function:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

// Helper function to generate random password
function generateRandomPassword(length: number): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*";
  let password = "";
  for (let i = 0; i < length; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return password;
}

// Helper function to generate Google Cloud access token
async function generateGoogleToken(
  clientEmail: string,
  privateKey: string
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600;

  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const claimSet = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/compute",
    aud: "https://oauth2.googleapis.com/token",
    exp: expiry,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(claimSet));

  const signatureInput = `${encodedHeader}.${encodedClaimSet}`;

  const signature = await signWithPrivateKey(signatureInput, privateKey);
  const encodedSignature = base64UrlEncode(signature);

  const jwt = `${signatureInput}.${encodedSignature}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

async function signWithPrivateKey(
  data: string,
  privateKey: string
): Promise<ArrayBuffer> {
  const pemContents = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(data)
  );

  return signature;
}

function base64UrlEncode(data: string | ArrayBuffer): string {
  let base64;
  if (typeof data === "string") {
    base64 = btoa(data);
  } else {
    base64 = btoa(String.fromCharCode(...new Uint8Array(data)));
  }
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}