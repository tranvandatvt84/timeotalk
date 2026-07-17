import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const receiverActions = new Set(["accepted", "declined"]);

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
  const invitationId = body?.invitation_id;
  const action = body?.action;

  if (typeof invitationId !== "string" || invitationId.length === 0) {
    return json({ error: "invitation_id is required" }, 400);
  }

  if (
    action !== "accepted" && action !== "declined" && action !== "canceled"
  ) {
    return json({ error: "Unsupported invitation action" }, 400);
  }

  const { data: invitation, error: loadError } = await supabase
    .from("invitations")
    .select()
    .eq("id", invitationId)
    .single();

  if (loadError || !invitation) {
    return json({ error: "Invitation not found" }, 404);
  }

  if (invitation.status !== "pending") {
    return json({ error: "Invitation is no longer pending" }, 409);
  }

  if (receiverActions.has(action) && invitation.receiver_id !== user.id) {
    return json({ error: "Only the receiver can respond" }, 403);
  }

  if (action === "canceled" && invitation.sender_id !== user.id) {
    return json({ error: "Only the sender can cancel" }, 403);
  }

  const respondedAt = new Date().toISOString();
  const { data: updatedInvitation, error: updateError } = await supabase
    .from("invitations")
    .update({ status: action, responded_at: respondedAt })
    .eq("id", invitationId)
    .select()
    .single();

  if (updateError) {
    return json({ error: updateError.message }, 400);
  }

  if (action === "accepted") {
    const { error: contactsError } = await supabase.from("contacts").upsert(
      [
        {
          owner_id: invitation.sender_id,
          contact_user_id: invitation.receiver_id,
          created_from_invitation_id: invitation.id,
        },
        {
          owner_id: invitation.receiver_id,
          contact_user_id: invitation.sender_id,
          created_from_invitation_id: invitation.id,
        },
      ],
      { onConflict: "owner_id,contact_user_id" },
    );

    if (contactsError) {
      return json({ error: contactsError.message }, 400);
    }
  }

  return json({ invitation: updatedInvitation });
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
