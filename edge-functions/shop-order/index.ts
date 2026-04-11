// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((o: string) => o.trim())
  .filter(Boolean);

const buildCorsHeaders = (origin: string | null) => {
  const isAllowed = origin && allowedOrigins.includes(origin);
  return {
    "Access-Control-Allow-Origin": isAllowed ? origin : "null",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
};

const AIRTABLE_TOKEN = Deno.env.get("AIRTABLE_PAT")!;
const AIRTABLE_BASE_ID = Deno.env.get("AIRTABLE_BASE_ID")!;

type SupabaseClientType = ReturnType<typeof createClient>;

interface PrizeInput {
  id: string | number;
}

interface SelectedOptionValueInput {
  id: string | number;
}

interface ShopOrderPayload {
  prize: PrizeInput;
  selectedOptionValues?: Array<SelectedOptionValueInput | string | number>;
  quantity?: number;
}

interface PrizeRow {
  id: string;
  title: string;
  cost: number;
  stock: number;
  type: string;
  key: string | null;
}

interface PrizeOptionRow {
  id: string;
  prize_id: string;
  name: string;
}

interface PrizeOptionValueRow {
  id: number;
  option_id: string;
  label: string;
  price_modifier: number;
  stock: number;
}

interface UserRow {
  id: string;
  boot_coins: number;
  keys: string[] | null;
  access_token_encrypted: string | null;
  slack_user_id: string | null;
  verification_status: boolean | null;
  ysws_eligible: boolean | null;
}

interface SelectedOptionValueResult {
  id: number;
  optionId: string;
  optionName: string;
  label: string;
  priceModifier: number;
}

interface BuiltOrder {
  prize: PrizeRow;
  quantity: number;
  basePricePerItem: number;
  optionModifierPerItem: number;
  pricePerItem: number;
  totalCost: number;
  selectedOptionValues: SelectedOptionValueResult[];
}

interface StockMutationResult {
  user_id: string;
  boot_coins: number;
  prize_id: string;
  prize_stock: number;
  option_value_stocks: Array<{ id: number; stock: number }>;
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
  verification_status?: boolean;
  ysws_eligible?: boolean;
  slack_id?: string;
}

class HttpError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

const toInt = (value: unknown): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return 0;
  }
  return Math.trunc(parsed);
};

const parsePositiveQuantity = (value: unknown): number => {
  if (value === undefined || value === null) {
    return 1;
  }

  const quantity = Number(value);
  if (!Number.isInteger(quantity) || quantity <= 0) {
    throw new HttpError(400, "quantity must be a positive integer");
  }

  return quantity;
};

const parseSelectedOptionValueIds = (
  selectedOptionValues: Array<SelectedOptionValueInput | string | number> = []
): number[] => {
  const ids: number[] = [];

  for (const entry of selectedOptionValues) {
    const rawId = typeof entry === "object" && entry !== null
      ? (entry as SelectedOptionValueInput).id
      : entry;

    if (rawId === undefined || rawId === null || String(rawId).trim() === "") {
      continue;
    }

    const id = Number(rawId);
    if (!Number.isInteger(id) || id <= 0) {
      throw new HttpError(400, `Invalid selected option value id: ${rawId}`);
    }

    ids.push(id);
  }

  return [...new Set(ids)];
};

const buildOrderFromPrize = async (
  supabaseAdmin: SupabaseClientType,
  prizeInput: PrizeInput,
  selectedOptionValuesInput: Array<SelectedOptionValueInput | string | number> = [],
  quantityInput: unknown
): Promise<BuiltOrder> => {
  const prizeId = String(prizeInput?.id ?? "").trim();
  if (!prizeId) {
    throw new HttpError(400, "prize.id is required");
  }

  const quantity = parsePositiveQuantity(quantityInput);

  const { data: prizeRow, error: prizeError } = await supabaseAdmin
    .from("prizes")
    .select("id, title, cost, stock, type, key")
    .eq("id", prizeId)
    .maybeSingle<PrizeRow>();

  if (prizeError) {
    throw prizeError;
  }

  if (!prizeRow) {
    throw new HttpError(404, "Prize not found");
  }

  const prizeType = String(prizeRow.type ?? "normal").toLowerCase();
  if (prizeType === "reward") {
    throw new HttpError(400, "Reward prizes cannot be purchased");
  }

  const prizeStock = toInt(prizeRow.stock);
  if (prizeStock <= 0) {
    throw new HttpError(400, "Prize is out of stock");
  }
  if (prizeStock < quantity) {
    throw new HttpError(400, "Insufficient prize stock");
  }

  const selectedOptionValueIds = parseSelectedOptionValueIds(
    selectedOptionValuesInput
  );

  let optionModifierPerItem = 0;
  const selectedOptionValues: SelectedOptionValueResult[] = [];

  if (selectedOptionValueIds.length > 0) {
    const { data: valueRowsRaw, error: valueRowsError } = await supabaseAdmin
      .from("prize_option_values")
      .select("id, option_id, label, price_modifier, stock")
      .in("id", selectedOptionValueIds);

    if (valueRowsError) {
      throw valueRowsError;
    }

    const valueRows = (valueRowsRaw ?? []) as PrizeOptionValueRow[];
    if (valueRows.length !== selectedOptionValueIds.length) {
      throw new HttpError(400, "One or more selected option values were not found");
    }

    const optionIds = [...new Set(valueRows.map((row) => String(row.option_id)))];
    const { data: optionRowsRaw, error: optionRowsError } = await supabaseAdmin
      .from("prize_options")
      .select("id, prize_id, name")
      .in("id", optionIds);

    if (optionRowsError) {
      throw optionRowsError;
    }

    const optionRows = (optionRowsRaw ?? []) as PrizeOptionRow[];
    const optionRowsById = new Map<string, PrizeOptionRow>(
      optionRows.map((row) => [String(row.id), row])
    );

    const seenOptionIds = new Set<string>();

    for (const valueRow of valueRows) {
      const optionId = String(valueRow.option_id);
      const optionRow = optionRowsById.get(optionId);

      if (!optionRow || String(optionRow.prize_id) !== prizeId) {
        throw new HttpError(400, "Selected option value does not belong to this prize");
      }

      if (seenOptionIds.has(optionId)) {
        throw new HttpError(400, "Only one value can be selected per option");
      }
      seenOptionIds.add(optionId);

      const valueStock = toInt(valueRow.stock);
      if (valueStock <= 0) {
        throw new HttpError(400, `Selected option value ${valueRow.id} is out of stock`);
      }
      if (valueStock < quantity) {
        throw new HttpError(
          400,
          `Insufficient stock for selected option value ${valueRow.id}`
        );
      }

      const priceModifier = toInt(valueRow.price_modifier);
      optionModifierPerItem += priceModifier;
      selectedOptionValues.push({
        id: toInt(valueRow.id),
        optionId,
        optionName: optionRow.name,
        label: String(valueRow.label ?? ""),
        priceModifier,
      });
    }
  }

  const basePricePerItem = toInt(prizeRow.cost);
  const pricePerItem = basePricePerItem + optionModifierPerItem;
  const totalCost = pricePerItem * quantity;

  if (totalCost < 0) {
    throw new HttpError(400, "Order total cannot be negative");
  }

  return {
    prize: {
      id: String(prizeRow.id),
      title: String(prizeRow.title ?? ""),
      cost: basePricePerItem,
      stock: prizeStock,
      type: prizeType,
      key: prizeRow.key ? String(prizeRow.key) : null,
    },
    quantity,
    basePricePerItem,
    optionModifierPerItem,
    pricePerItem,
    totalCost,
    selectedOptionValues,
  };
};

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

Deno.serve(async (req: Request) => {
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

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
      throw new Error("Missing required Supabase environment variables");
    }

    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
    } = await supabaseUser.auth.getUser();

    if (!user) {
      return new Response(JSON.stringify({ message: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let payload: ShopOrderPayload;
    try {
      payload = await req.json();
    } catch {
      throw new HttpError(400, "Invalid JSON request body");
    }

    if (!payload?.prize?.id) {
      throw new HttpError(400, "prize.id is required");
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    const { data: userRow, error: userRowError } = await supabaseAdmin
      .from("users")
      .select(
        "id, boot_coins, keys, access_token_encrypted, slack_user_id, verification_status, ysws_eligible"
      )
      .eq("id", user.id)
      .maybeSingle<UserRow>();

    if (userRowError) {
      throw userRowError;
    }

    if (!userRow) {
      throw new HttpError(404, "User not found");
    }

    const order = await buildOrderFromPrize(
      supabaseAdmin,
      payload.prize,
      payload.selectedOptionValues,
      payload.quantity
    );

    if (order.prize.type === "keyed") {
      if (!order.prize.key) {
        throw new HttpError(400, "This keyed prize is missing its required key");
      }

      const userKeys = Array.isArray(userRow.keys)
        ? userRow.keys.map((key: string) => String(key))
        : [];

      if (!userKeys.includes(order.prize.key)) {
        throw new HttpError(403, "Missing required key for this prize");
      }
    }

    const userBalance = toInt(userRow.boot_coins);
    if (userBalance < order.totalCost) {
      throw new HttpError(400, "Insufficient balance");
    }

    const encryptedAccessToken = userRow.access_token_encrypted;

    if(!encryptedAccessToken) {
      throw new Error("User has no encrypted Hack Club access token");
    }
    const accessToken = await decryptAccessToken(encryptedAccessToken);
    // make HCA calls to get address, and other
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

    if (!userInfo.sub || !userInfo.email || !userInfo.birthdate || !userInfo.name || !userInfo.address) {
      throw new HttpError(400, "Invalid user info: missing sub, email, birthdate, name, or address");
    }

    const finalVerificationStatus =
      userInfo.verification_status ?? userRow.verification_status;
    const finalYswsEligible = userInfo.ysws_eligible ?? userRow.ysws_eligible;

    if (!finalVerificationStatus || !finalYswsEligible) {
      throw new HttpError(403, "User is not verified or eligible for this prize");
    }

    const { data: mutationResult, error: mutationError } = await supabaseAdmin.rpc(
      "apply_shop_order_mutations",
      {
        p_user_id: user.id,
        p_prize_id: order.prize.id,
        p_quantity: order.quantity,
        p_total_cost: order.totalCost,
        p_selected_option_value_ids: order.selectedOptionValues.map(
          (value) => value.id
        ),
      }
    );

    if (mutationError) {
      const errorMessage = String(mutationError.message ?? "").toUpperCase();

      if (errorMessage.includes("INSUFFICIENT_BALANCE")) {
        throw new HttpError(409, "Insufficient balance");
      }
      if (errorMessage.includes("INSUFFICIENT_PRIZE_STOCK")) {
        throw new HttpError(409, "Insufficient prize stock");
      }
      if (errorMessage.includes("INSUFFICIENT_OPTION_STOCK")) {
        throw new HttpError(409, "Insufficient selected option stock");
      }

      throw mutationError;
    }

    const stockMutation = (mutationResult ?? {}) as Partial<StockMutationResult>;
    const updatedBootCoins = toInt(stockMutation.boot_coins);

    try {
      await insertAirtableRow("Orders", {
        boot_user_id: user.id,
        total_cost: order.totalCost,
        prize: order.prize.title,
        prize_options: order.selectedOptionValues.map((v) => v.label).join(", "),
        quantity: order.quantity,
        name: userInfo.name,
        email: userInfo.email,
        "Slack Id": userRow.slack_user_id ?? userInfo.slack_id,
        "Address (Line 1)": userInfo.address.street_address,
        City: userInfo.address.locality,
        "State / Province": userInfo.address.region,
        Country: userInfo.address.country,
        "ZIP / Postal Code": userInfo.address.postal_code,
      });
    } catch (airtableError) {
      console.error("Airtable order insert failed:", airtableError);
    }

    return new Response(
      JSON.stringify({
        message: "Order validation passed and user balance updated",
        order: {
          prizeId: order.prize.id,
          quantity: order.quantity,
          basePricePerItem: order.basePricePerItem,
          optionModifierPerItem: order.optionModifierPerItem,
          pricePerItem: order.pricePerItem,
          totalCost: order.totalCost,
          selectedOptionValues: order.selectedOptionValues,
        },
        user: {
          id: user.id,
          boot_coins: updatedBootCoins,
        },
        stock: {
          prize_stock: toInt(stockMutation.prize_stock),
          option_value_stocks: Array.isArray(stockMutation.option_value_stocks)
            ? stockMutation.option_value_stocks
            : [],
        },
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err: unknown) {
    if (err instanceof HttpError) {
      return new Response(JSON.stringify({ message: err.message }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: err.status,
      });
    }

    console.error("Function error:", err);
    return new Response(
      JSON.stringify({ message: err instanceof Error ? err.message : String(err) }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});