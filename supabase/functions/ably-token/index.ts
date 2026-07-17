import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const tokenTtlMs = 30 * 60 * 1000;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabase = adminClient();
  const user = await requireUser(request, supabase);
  if ("error" in user) {
    return json({ error: user.error }, user.status);
  }

  const memberships = await loadMemberships(supabase, user.id);
  if ("error" in memberships) {
    return json({ error: memberships.error }, 400);
  }

  const tokenRequest = await createTokenRequest({
    apiKey: requiredEnv("ABLY_API_KEY"),
    clientId: user.id,
    capability: buildCapability(user.id, memberships.conversationIds),
    ttl: tokenTtlMs,
  });

  return json(tokenRequest);
});

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceRoleKey) {
    throw new Error("Missing Supabase function environment.");
  }

  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

async function requireUser(
  request: Request,
  supabase: ReturnType<typeof adminClient>,
) {
  const authHeader = request.headers.get("Authorization");
  const token = authHeader?.replace("Bearer ", "");

  if (!token) {
    return { error: "Missing bearer token", status: 401 };
  }

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    return { error: "Invalid bearer token", status: 401 };
  }

  return data.user;
}

async function loadMemberships(
  supabase: ReturnType<typeof adminClient>,
  userId: string,
) {
  const { data, error } = await supabase
    .from("conversation_members")
    .select("conversation_id")
    .eq("user_id", userId)
    .is("left_at", null);

  if (error) {
    return { error: error.message };
  }

  return {
    conversationIds: (data ?? [])
      .map((row) => row.conversation_id)
      .filter((id): id is string => typeof id === "string"),
  };
}

function buildCapability(userId: string, conversationIds: string[]) {
  const capability: Record<string, string[]> = {
    [`user:${userId}`]: ["subscribe"],
  };

  for (const conversationId of conversationIds) {
    capability[`chat:${conversationId}`] = ["publish", "subscribe", "history"];
    capability[`typing:${conversationId}`] = ["publish", "subscribe"];
    capability[`receipt:${conversationId}`] = ["publish", "subscribe"];
    capability[`presence:${conversationId}`] = ["presence", "subscribe"];
  }

  return JSON.stringify(capability);
}

async function createTokenRequest({
  apiKey,
  clientId,
  capability,
  ttl,
}: {
  apiKey: string;
  clientId: string;
  capability: string;
  ttl: number;
}) {
  const [keyName, keySecret] = apiKey.split(":");
  if (!keyName || !keySecret) {
    throw new Error("ABLY_API_KEY must be formatted as keyName:keySecret.");
  }

  const timestamp = Date.now();
  const nonce = crypto.randomUUID().replaceAll("-", "");
  const mac = await signTokenRequest({
    keySecret,
    keyName,
    ttl,
    capability,
    clientId,
    timestamp,
    nonce,
  });

  return { keyName, ttl, capability, clientId, timestamp, nonce, mac };
}

async function signTokenRequest({
  keySecret,
  keyName,
  ttl,
  capability,
  clientId,
  timestamp,
  nonce,
}: {
  keySecret: string;
  keyName: string;
  ttl: number;
  capability: string;
  clientId: string;
  timestamp: number;
  nonce: string;
}) {
  const canonicalRequest = [
    keyName,
    ttl.toString(),
    capability,
    clientId,
    timestamp.toString(),
    nonce,
  ].join("\n") + "\n";

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(keySecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(canonicalRequest),
  );

  return base64(signature);
}

function base64(buffer: ArrayBuffer) {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

function requiredEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing ${name}.`);
  }
  return value;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
