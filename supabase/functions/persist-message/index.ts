import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type MessageCreatedPayload = {
  event: "message.created";
  client_message_id: string;
  conversation_id: string;
  sender_id?: string;
  sender_device_id?: string;
  type: string;
  body: Record<string, unknown>;
  attachments: AttachmentPayload[];
  reply_to_message_id?: string | null;
  reply_to?: string | null;
  client_created_at?: string | null;
};

type AttachmentPayload = {
  storage_path: string;
  mime_type: string;
  size_bytes: number;
  width?: number | null;
  height?: number | null;
  duration_ms?: number | null;
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

  const input = await request.json().catch(() => null);
  const validation = validateMessageCreated(input);
  if ("error" in validation) {
    return json({ error: validation.error }, validation.status);
  }

  const payload = validation.payload;
  const channelName = `chat:${payload.conversation_id}`;

  if (payload.sender_id && payload.sender_id !== user.id) {
    await publishRejected(channelName, payload, "Sender does not match user");
    return json({ error: "Sender does not match user" }, 403);
  }

  const membership = await verifyMembership(
    supabase,
    user.id,
    payload.conversation_id,
  );
  if ("error" in membership) {
    return json({ error: membership.error }, 400);
  }

  if (!membership.isMember) {
    await publishRejected(channelName, payload, "Sender is not a member");
    return json({ error: "Sender is not a member" }, 403);
  }

  const persisted = await persistMessage(supabase, payload, user.id);
  if ("error" in persisted) {
    await publishRejected(channelName, payload, persisted.error);
    return json({ error: persisted.error }, 400);
  }

  await publishAbly(
    channelName,
    "message.persisted",
    persistedMessageEvent(payload, persisted.message, persisted.attachments),
  );

  return json({
    message: persistedMessageEvent(
      payload,
      persisted.message,
      persisted.attachments,
    ),
  });
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

function validateMessageCreated(input: unknown):
  | { payload: MessageCreatedPayload }
  | { error: string; status: number } {
  const payload = extractPayload(input);
  if (!payload) {
    return { error: "Invalid JSON payload", status: 400 };
  }

  const event = payload.event ?? payload.name;
  if (event !== "message.created") {
    return { error: "Expected message.created event", status: 400 };
  }

  const clientMessageId = nonEmptyString(payload.client_message_id);
  const conversationId = nonEmptyString(payload.conversation_id);
  const type = nonEmptyString(payload.type);
  const body = asRecord(payload.body) ?? {};
  const attachments = validateAttachments(payload.attachments);

  if (!clientMessageId) {
    return { error: "client_message_id is required", status: 400 };
  }

  if (!conversationId) {
    return { error: "conversation_id is required", status: 400 };
  }

  if (!type) {
    return { error: "type is required", status: 400 };
  }

  if ("error" in attachments) {
    return { error: attachments.error, status: 400 };
  }

  return {
    payload: {
      event: "message.created",
      client_message_id: clientMessageId,
      conversation_id: conversationId,
      sender_id: nonEmptyString(payload.sender_id),
      sender_device_id: nonEmptyString(payload.sender_device_id),
      type,
      body,
      attachments: attachments.attachments,
      reply_to_message_id: nonEmptyString(payload.reply_to_message_id) ??
        null,
      reply_to: nonEmptyString(payload.reply_to) ?? null,
      client_created_at: nonEmptyString(payload.client_created_at) ?? null,
    },
  };
}

async function verifyMembership(
  supabase: ReturnType<typeof adminClient>,
  userId: string,
  conversationId: string,
) {
  const { data, error } = await supabase
    .from("conversation_members")
    .select("conversation_id")
    .eq("conversation_id", conversationId)
    .eq("user_id", userId)
    .is("left_at", null)
    .maybeSingle();

  if (error) {
    return { error: error.message };
  }

  return { isMember: Boolean(data) };
}

async function persistMessage(
  supabase: ReturnType<typeof adminClient>,
  payload: MessageCreatedPayload,
  userId: string,
) {
  const { data: message, error } = await supabase
    .from("messages")
    .upsert({
      client_message_id: payload.client_message_id,
      conversation_id: payload.conversation_id,
      sender_id: userId,
      sender_device_id: payload.sender_device_id ?? null,
      type: payload.type,
      body: payload.body,
      reply_to_message_id: payload.reply_to_message_id ??
        payload.reply_to ??
        null,
    }, { onConflict: "conversation_id,client_message_id" })
    .select(
      "id,client_message_id,conversation_id,sender_id,sender_device_id,type,body,reply_to_message_id,created_at",
    )
    .single();

  if (error) {
    return { error: error.message };
  }

  const attachments = await persistAttachments(
    supabase,
    payload,
    userId,
    message.id,
  );
  if ("error" in attachments) {
    return { error: attachments.error };
  }

  return { message, attachments: attachments.attachments };
}

async function persistAttachments(
  supabase: ReturnType<typeof adminClient>,
  payload: MessageCreatedPayload,
  userId: string,
  messageId: string,
) {
  const { error: deleteError } = await supabase
    .from("attachments")
    .delete()
    .eq("message_id", messageId);

  if (deleteError) {
    return { error: deleteError.message };
  }

  if (payload.attachments.length === 0) {
    return { attachments: [] };
  }

  const rows = payload.attachments.map((attachment) => ({
    message_id: messageId,
    conversation_id: payload.conversation_id,
    uploaded_by: userId,
    storage_path: attachment.storage_path,
    mime_type: attachment.mime_type,
    size_bytes: attachment.size_bytes,
    width: attachment.width ?? null,
    height: attachment.height ?? null,
    duration_ms: attachment.duration_ms ?? null,
  }));

  const { data, error } = await supabase
    .from("attachments")
    .insert(rows)
    .select(
      "id,storage_path,mime_type,size_bytes,width,height,duration_ms,created_at",
    );

  if (error) {
    return { error: error.message };
  }

  return { attachments: data ?? [] };
}

async function publishRejected(
  channelName: string,
  payload: MessageCreatedPayload,
  error: string,
) {
  await publishAbly(channelName, "message.rejected", {
    event: "message.rejected",
    version: 1,
    client_message_id: payload.client_message_id,
    conversation_id: payload.conversation_id,
    sender_id: payload.sender_id,
    sender_device_id: payload.sender_device_id,
    type: payload.type,
    body: payload.body,
    attachments: payload.attachments,
    persistence_status: "rejected",
    error,
  });
}

function persistedMessageEvent(
  original: MessageCreatedPayload,
  message: Record<string, unknown>,
  attachments: Record<string, unknown>[],
) {
  return {
    event: "message.persisted",
    version: 1,
    client_message_id: original.client_message_id,
    server_message_id: message.id,
    conversation_id: message.conversation_id,
    sender_id: message.sender_id,
    sender_device_id: message.sender_device_id,
    type: message.type,
    body: message.body,
    attachments: attachments.map((attachment) => ({
      id: attachment.id,
      storage_path: attachment.storage_path,
      mime_type: attachment.mime_type,
      size_bytes: attachment.size_bytes,
      width: attachment.width,
      height: attachment.height,
      duration_ms: attachment.duration_ms,
    })),
    reply_to_message_id: message.reply_to_message_id,
    persistence_status: "persisted",
    client_created_at: original.client_created_at,
    server_created_at: message.created_at,
    updated_at: message.created_at,
  };
}

async function publishAbly(
  channelName: string,
  eventName: "message.persisted" | "message.rejected",
  data: Record<string, unknown>,
) {
  const response = await fetch(
    `https://rest.ably.io/channels/${encodeURIComponent(channelName)}/messages`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(requiredEnv("ABLY_API_KEY"))}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ name: eventName, data }),
    },
  );

  if (!response.ok) {
    throw new Error(`Failed to publish ${eventName}: ${response.status}`);
  }
}

function extractPayload(input: unknown) {
  const record = asRecord(input);
  if (!record) {
    return null;
  }

  const data = asRecord(record.data);
  if (data) {
    return data;
  }

  return record;
}

function validateAttachments(input: unknown):
  | { attachments: AttachmentPayload[] }
  | { error: string } {
  if (input == null) {
    return { attachments: [] };
  }

  if (!Array.isArray(input)) {
    return { error: "attachments must be an array" };
  }

  const attachments: AttachmentPayload[] = [];
  for (const item of input) {
    const attachment = asRecord(item);
    const storagePath = nonEmptyString(attachment?.storage_path);
    const mimeType = nonEmptyString(attachment?.mime_type);
    const sizeBytes = positiveNumber(attachment?.size_bytes);

    if (!attachment || !storagePath || !mimeType || !sizeBytes) {
      return { error: "attachments contain invalid metadata" };
    }

    attachments.push({
      storage_path: storagePath,
      mime_type: mimeType,
      size_bytes: sizeBytes,
      width: optionalNumber(attachment.width),
      height: optionalNumber(attachment.height),
      duration_ms: optionalNumber(attachment.duration_ms),
    });
  }

  return { attachments };
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  return value as Record<string, unknown>;
}

function nonEmptyString(value: unknown) {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function positiveNumber(value: unknown) {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) && number > 0 ? number : undefined;
}

function optionalNumber(value: unknown) {
  if (value == null) {
    return null;
  }

  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : null;
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
