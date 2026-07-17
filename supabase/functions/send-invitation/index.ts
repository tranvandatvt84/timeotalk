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
  const receiverId = body?.receiver_id;
  const message = typeof body?.message === "string" ? body.message.trim() : null;

  if (typeof receiverId !== "string" || receiverId.length === 0) {
    return json({ error: "receiver_id is required" }, 400);
  }

  if (receiverId === user.id) {
    return json({ error: "Cannot invite yourself" }, 400);
  }

  const { data: receiver } = await supabase
    .from("profiles")
    .select("id")
    .eq("id", receiverId)
    .maybeSingle();

  if (!receiver) {
    return json({ error: "Receiver profile not found" }, 404);
  }

  const { data: existingContact } = await supabase
    .from("contacts")
    .select("id")
    .eq("owner_id", user.id)
    .eq("contact_user_id", receiverId)
    .maybeSingle();

  if (existingContact) {
    return json({ error: "Users are already contacts" }, 409);
  }

  const { data: sentPending } = await supabase
    .from("invitations")
    .select("id")
    .eq("sender_id", user.id)
    .eq("receiver_id", receiverId)
    .eq("status", "pending")
    .maybeSingle();

  const { data: receivedPending } = await supabase
    .from("invitations")
    .select("id")
    .eq("sender_id", receiverId)
    .eq("receiver_id", user.id)
    .eq("status", "pending")
    .maybeSingle();

  if (sentPending || receivedPending) {
    return json({ error: "A pending invitation already exists" }, 409);
  }

  const { data: invitation, error } = await supabase
    .from("invitations")
    .insert({
      sender_id: user.id,
      receiver_id: receiverId,
      message: message && message.length > 0 ? message : null,
    })
    .select()
    .single();

  if (error) {
    return json({ error: error.message }, 400);
  }

  return json({ invitation });
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

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
