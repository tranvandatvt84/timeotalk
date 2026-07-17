import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

  const body = await request.json().catch(() => null);
  const rawQuery = typeof body?.query === "string" ? body.query : "";
  const query = normalizeQuery(rawQuery);

  if (query.length < 2) {
    return json({ profiles: [] });
  }

  const pattern = `%${query}%`;
  const { data: profiles, error } = await supabase
    .from("profiles")
    .select("id,display_name,handle,avatar_url")
    .neq("id", user.id)
    .or(`handle.ilike.${pattern},display_name.ilike.${pattern}`)
    .order("display_name", { ascending: true })
    .limit(20);

  if (error) {
    return json({ error: error.message }, 400);
  }

  return json({ profiles });
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

function normalizeQuery(value: string) {
  const trimmed = value.trim();
  const withoutPrefix = trimmed.startsWith("@")
    ? trimmed.slice(1)
    : trimmed;

  return withoutPrefix.toLowerCase().replace(/[^a-z0-9_ ]/g, "").trim();
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
