#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import type { AdminResult, JsonObject, JsonValue } from "../contracts.js";
import { filterOperators, resourceNames } from "../contracts.js";
import { errorBody } from "../errors.js";
import { createMasterDanceAdminSDK } from "../factory.js";

const sdk = createMasterDanceAdminSDK();
const server = new McpServer(
  { name: "master-dance-admin", version: "0.1.0" },
  {
    instructions:
      "Master Dance production admin data. Read the target record before writing and state the exact intended change. Writes require an active administrator and remain subject to Supabase RLS, validation, audit, and dependency rules. Ask the user to confirm deletion, contract publication, invoice issuance, payment recording, or media removal. Money is integer USD cents. Issued invoices/payments and signed legal records are immutable; corrections create a new version. Never request or reveal passwords, tokens, or service keys. Course category is hidden compatibility data."
  }
);

const successOutput = {
  ok: z.literal(true),
  result: z.unknown(),
  warnings: z.array(z.string())
};

server.registerTool(
  "md_capabilities",
  {
    title: "Master Dance capabilities",
    description: "List supported Master Dance resources, actions, current admin identity, and protected invariants.",
    inputSchema: {},
    outputSchema: successOutput,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false }
  },
  async () => execute(() => sdk.capabilities())
);

server.registerTool(
  "md_list_records",
  {
    title: "List Master Dance records",
    description: "Query an allowed Master Dance resource with validated filters, text search, sorting, and pagination.",
    inputSchema: {
      resource: z.enum(resourceNames),
      filters: z.array(z.object({
        field: z.string().min(1),
        operator: z.enum(filterOperators).default("eq"),
        value: z.unknown()
      })).optional(),
      sort: z.array(z.object({
        field: z.string().min(1),
        ascending: z.boolean().default(true)
      })).optional(),
      search: z.string().min(1).optional(),
      limit: z.number().int().min(1).max(500).default(100),
      offset: z.number().int().min(0).default(0)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false }
  },
  async ({ resource, filters, sort, search, limit, offset }) => execute(() => sdk.listRecords(resource, {
    filters: filters as never,
    sort,
    search,
    limit,
    offset
  }))
);

server.registerTool(
  "md_get_record",
  {
    title: "Get Master Dance record",
    description: "Read one Master Dance record by its stable id.",
    inputSchema: {
      resource: z.enum(resourceNames),
      id: z.string().min(1)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false }
  },
  async ({ resource, id }) => execute(() => sdk.getRecord(resource, id))
);

server.registerTool(
  "md_create_record",
  {
    title: "Create Master Dance record",
    description: "Create a mutable Master Dance resource. Organization, ids, defaults, and hidden compatibility fields are supplied safely. For a new unlinked guardian only, the explicit incomplete-contact override may temporarily leave email or phone blank.",
    inputSchema: {
      resource: z.enum(resourceNames),
      values: z.record(z.string(), z.unknown()),
      allow_incomplete_guardian_contact: z.boolean().default(false)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false }
  },
  async ({ resource, values, allow_incomplete_guardian_contact }) => execute(() => sdk.createRecord(
    resource,
    toJsonObject(values),
    { allowIncompleteGuardianContact: allow_incomplete_guardian_contact }
  ))
);

server.registerTool(
  "md_update_record",
  {
    title: "Update Master Dance record",
    description: "Update only the supported fields of a mutable Master Dance record. Read it first and send the smallest possible patch. For an unlinked guardian only, the explicit incomplete-contact override may clear email or phone temporarily.",
    inputSchema: {
      resource: z.enum(resourceNames),
      id: z.string().min(1),
      changes: z.record(z.string(), z.unknown()),
      allow_incomplete_guardian_contact: z.boolean().default(false)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  async ({ resource, id, changes, allow_incomplete_guardian_contact }) => execute(() => sdk.updateRecord(
    resource,
    id,
    toJsonObject(changes),
    { allowIncompleteGuardianContact: allow_incomplete_guardian_contact }
  ))
);

server.registerTool(
  "md_delete_record",
  {
    title: "Delete Master Dance record",
    description: "Delete a supported record through dependency-aware rules. Linked or protected records are rejected instead of cascaded silently.",
    inputSchema: {
      resource: z.enum(resourceNames),
      id: z.string().min(1)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  async ({ resource, id }) => execute(() => sdk.deleteRecord(resource, id))
);

server.registerTool(
  "md_set_course_pricing",
  {
    title: "Set course pricing",
    description: "Set a course pricing state and integer USD-cent prices. Private lessons accept per-session pricing only.",
    inputSchema: {
      course_id: z.string().uuid(),
      pricing_status: z.enum(["pending", "priced", "free", "review_required"]),
      full_term_unit_price_cents: z.number().int().min(0).nullable().optional(),
      per_session_unit_price_cents: z.number().int().min(0).nullable().optional()
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("set_course_pricing", toJsonObject(input)))
);

server.registerTool(
  "md_save_enrollment",
  {
    title: "Save enrollment",
    description: "Create or update one course x learner enrollment atomically, including pricing snapshot and per-session selections.",
    inputSchema: {
      id: z.string().uuid().optional(),
      term_id: z.string().uuid(),
      course_id: z.string().uuid(),
      student_id: z.string().uuid(),
      enrolled_at: z.string().datetime().optional(),
      status: z.enum(["active", "withdrawn", "completed"]).default("active"),
      registration_mode: z.enum(["full_term", "per_session"]).default("full_term"),
      pricing_status: z.enum(["pending", "ready", "review_required"]).default("pending"),
      billing_starts_on: z.string().date().nullable().optional(),
      unit_price_cents: z.number().int().min(0).nullable().optional(),
      trial_fee_cents: z.number().int().min(0).default(0),
      discount_name: z.string().max(80).nullable().optional(),
      discount_kind: z.enum(["percentage", "fixed_amount"]).nullable().optional(),
      discount_value: z.number().int().positive().nullable().optional(),
      billing_notes: z.string().max(1000).nullable().optional(),
      selected_session_ids: z.array(z.string().uuid()).default([])
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("save_enrollment", toJsonObject(input)))
);

server.registerTool(
  "md_set_attendance",
  {
    title: "Set attendance",
    description: "Set or replace one learner's attendance for one class session, including trial and makeup semantics.",
    inputSchema: {
      id: z.string().uuid().optional(),
      session_id: z.string().uuid(),
      student_id: z.string().uuid(),
      enrollment_id: z.string().uuid().nullable().optional(),
      makeup_for_session_id: z.string().uuid().nullable().optional(),
      status: z.enum(["present", "absent", "excused", "makeup", "trial"]),
      recorded_at: z.string().datetime().optional(),
      note: z.string().max(1000).nullable().optional()
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("set_attendance", toJsonObject(input)))
);

server.registerTool(
  "md_clear_attendance",
  {
    title: "Clear attendance",
    description: "Undo an attendance state by id or by class session plus learner.",
    inputSchema: {
      id: z.string().uuid().optional(),
      session_id: z.string().uuid().optional(),
      student_id: z.string().uuid().optional()
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("clear_attendance", toJsonObject(input)))
);

server.registerTool(
  "md_save_leave_request",
  {
    title: "Save administrator leave request",
    description: "Create or update an administrator-recorded leave request at any time. The database records it as leave without approval workflow.",
    inputSchema: {
      id: z.string().uuid().optional(),
      session_id: z.string().uuid(),
      student_id: z.string().uuid(),
      enrollment_id: z.string().uuid().nullable().optional(),
      submitted_at: z.string().datetime().optional(),
      note: z.string().max(1000).nullable().optional()
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("save_leave_request", toJsonObject(input)))
);

server.registerTool(
  "md_create_student_for_guardian",
  {
    title: "Create learner profile",
    description: "Create a child or adult learner profile under an existing guardian while keeping family links atomic.",
    inputSchema: {
      guardian_id: z.string().uuid(),
      display_name: z.string().min(1).max(120),
      legal_name: z.string().max(120).nullable().optional(),
      birth_date: z.string().date().nullable().optional(),
      kind: z.enum(["child", "adult"])
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("create_student_for_guardian", toJsonObject(input)))
);

server.registerTool(
  "md_link_student_to_guardian",
  {
    title: "Move learner to guardian",
    description: "Link or move an existing learner profile to an existing guardian using the protected family operation.",
    inputSchema: {
      guardian_id: z.string().uuid(),
      student_id: z.string().uuid()
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("link_student_to_guardian", toJsonObject(input)))
);

server.registerTool(
  "md_issue_guardian_link_code",
  {
    title: "Issue guardian invitation code",
    description: "Create a one-time guardian registration invitation code. The raw code is returned only by this action.",
    inputSchema: {
      guardian_id: z.string().uuid(),
      validity_days: z.number().int().min(1).max(90).default(14)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("issue_guardian_link_code", toJsonObject(input)))
);

server.registerTool(
  "md_publish_contract_revision",
  {
    title: "Publish contract revision",
    description: "Publish a new immutable text agreement revision for a term and retire the prior published version.",
    inputSchema: {
      term_id: z.string().uuid(),
      title: z.string().min(1).max(160),
      body_text: z.string().min(20).max(50_000)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("publish_contract_revision", toJsonObject(input)))
);

server.registerTool(
  "md_update_profile_access",
  {
    title: "Update account access",
    description: "Change an existing profile's display name or active state. The final active administrator remains protected.",
    inputSchema: {
      user_id: z.string().uuid(),
      display_name: z.string().min(1).max(120),
      is_active: z.boolean().default(true)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("update_profile_access", toJsonObject(input)))
);

server.registerTool(
  "md_upload_media",
  {
    title: "Upload Master Dance media",
    description: "Upload an already-prepared local file to an allowed private Supabase bucket under the active school prefix.",
    inputSchema: {
      bucket: z.enum(["news-media", "advertisement-media", "contracts", "billing-documents"]),
      storage_path: z.string().min(3),
      file_path: z.string().min(1),
      mime_type: z.string().min(3),
      upsert: z.boolean().default(false)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("upload_media", toJsonObject(input)))
);

server.registerTool(
  "md_remove_media",
  {
    title: "Remove Master Dance media",
    description: "Remove private Supabase storage objects under the active school prefix after confirming no live record needs them.",
    inputSchema: {
      bucket: z.enum(["news-media", "advertisement-media", "contracts", "billing-documents"]),
      storage_paths: z.array(z.string().min(3)).min(1)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("remove_media", toJsonObject(input)))
);

const billingItemSchema = z.object({
  id: z.string().uuid().optional(),
  student_id: z.string().uuid().nullable().optional(),
  enrollment_id: z.string().uuid().nullable().optional(),
  kind: z.enum(["tuition", "trial", "registration", "discount", "balance_credit", "prior_balance", "manual"]),
  title: z.string().min(1).max(160),
  detail: z.string().max(500).nullable().optional(),
  quantity: z.number().int().min(1).max(999),
  unit_amount_cents: z.number().int(),
  amount_cents: z.number().int(),
  paid: z.boolean(),
  sort_order: z.number().int().optional()
});

server.registerTool(
  "md_issue_invoice",
  {
    title: "Issue immutable invoice version",
    description: "Upload bilingual and English PNGs and issue one immutable family-term-learner invoice version. Paid line items remain displayed but are excluded from current amount due.",
    inputSchema: {
      invoice_id: z.string().uuid().optional(),
      guardian_id: z.string().uuid(),
      term_id: z.string().uuid(),
      learner_ids: z.array(z.string().uuid()).min(1),
      invoice_number: z.string().min(1).max(80),
      version: z.number().int().min(1),
      school_year_label: z.string().min(1).max(40),
      issued_at: z.string().datetime().optional(),
      notes: z.string().max(2000).nullable().optional(),
      supersedes_invoice_id: z.string().uuid().nullable().optional(),
      bilingual_png_path: z.string().min(1),
      english_png_path: z.string().min(1),
      items: z.array(billingItemSchema).min(1)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("issue_invoice", toJsonObject(input)))
);

server.registerTool(
  "md_record_payment",
  {
    title: "Record immutable payment",
    description: "Upload bilingual and English receipt PNGs and append an immutable payment to an issued invoice.",
    inputSchema: {
      payment_id: z.string().uuid().optional(),
      invoice_id: z.string().uuid(),
      amount_cents: z.number().int().positive(),
      processing_fee_cents: z.number().int().min(0).default(0),
      method: z.enum(["cash", "check", "zelle", "card"]),
      received_at: z.string().datetime().optional(),
      note: z.string().max(1000).nullable().optional(),
      bilingual_png_path: z.string().min(1),
      english_png_path: z.string().min(1)
    },
    outputSchema: successOutput,
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false }
  },
  async (input) => execute(() => sdk.runAction("record_payment", toJsonObject(input)))
);

const transport = new StdioServerTransport();
await server.connect(transport);

process.on("SIGINT", async () => {
  await server.close();
  process.exit(0);
});

async function execute(
  task: () => Promise<AdminResult<JsonValue>>
): Promise<CallToolResult> {
  try {
    const payload = await task();
    return {
      content: [{ type: "text", text: JSON.stringify(payload, null, 2) }],
      structuredContent: payload as unknown as Record<string, unknown>
    };
  } catch (error) {
    const payload = errorBody(error);
    return {
      isError: true,
      content: [{ type: "text", text: JSON.stringify(payload, null, 2) }]
    };
  }
}

function toJsonObject(value: unknown): JsonObject {
  const serialized = JSON.parse(JSON.stringify(value)) as unknown;
  if (serialized === null || Array.isArray(serialized) || typeof serialized !== "object") {
    throw new Error("MCP input must be an object.");
  }
  return serialized as JsonObject;
}
