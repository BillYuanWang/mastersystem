import test from "node:test";
import assert from "node:assert/strict";
import { actionNames, resourceNames } from "../contracts.js";
import type { JsonValue } from "../contracts.js";
import { resourceSpecs } from "../resources.js";
import { MasterDanceAdminSDK, normalizeUSPhone } from "../service.js";
import type { SupabaseAdminClient } from "../supabase.js";

test("every public resource has a definition", () => {
  assert.deepEqual(Object.keys(resourceSpecs).sort(), [...resourceNames].sort());
});

test("hidden course categories are not exposed", () => {
  assert.equal(resourceNames.includes("course_categories" as never), false);
  assert.equal(resourceSpecs.courses.createFields.includes("category_id"), false);
  assert.equal(resourceSpecs.courses.updateFields.includes("category_id"), false);
});

test("issued billing records are immutable", () => {
  for (const name of ["billing_invoices", "billing_invoice_items", "billing_payments", "billing_artifacts"] as const) {
    assert.equal(resourceSpecs[name].createFields.length, 0);
    assert.equal(resourceSpecs[name].updateFields.length, 0);
    assert.equal(resourceSpecs[name].deleteStrategy.kind, "none");
  }
  assert.equal(actionNames.includes("issue_invoice"), true);
  assert.equal(actionNames.includes("record_payment"), true);
});

test("US phone normalization matches the product format", () => {
  assert.equal(normalizeUSPhone("9495550123"), "+1 (949) 555-0123");
  assert.equal(normalizeUSPhone("+1 949-555-0123"), "+1 (949) 555-0123");
});

test("guardian contact remains required unless the Admin override is explicit", async () => {
  let writtenBody: JsonValue | undefined;
  const client = {
    identity: async () => ({
      userId: "00000000-0000-4000-8000-000000000001",
      organizationId: "00000000-0000-4000-8000-000000000002",
      displayName: "Admin",
      role: "administrator" as const
    }),
    postgrest: async <T>(_method: string, _table: string, options: { body?: JsonValue }) => {
      writtenBody = options.body;
      return [options.body] as T;
    }
  } as unknown as SupabaseAdminClient;
  const sdk = new MasterDanceAdminSDK(client);

  await assert.rejects(
    sdk.createRecord("guardians", { display_name: "Pending Family" }),
    /email is required/i
  );

  const result = await sdk.createRecord(
    "guardians",
    { display_name: "Pending Family" },
    { allowIncompleteGuardianContact: true }
  );
  assert.equal((writtenBody as { email?: unknown }).email, null);
  assert.equal((writtenBody as { phone?: unknown }).phone, null);
  assert.equal(result.warnings.length, 1);
});

test("guardian invitation stays blocked until both contact fields are valid", async () => {
  let rpcCalled = false;
  const guardianID = "00000000-0000-4000-8000-000000000003";
  const client = {
    identity: async () => ({
      userId: "00000000-0000-4000-8000-000000000001",
      organizationId: "00000000-0000-4000-8000-000000000002",
      displayName: "Admin",
      role: "administrator" as const
    }),
    postgrest: async <T>() => ([{
      id: guardianID,
      organization_id: "00000000-0000-4000-8000-000000000002",
      display_name: "Pending Family",
      email: null,
      phone: null
    }] as T),
    rpc: async <T>() => {
      rpcCalled = true;
      return {} as T;
    }
  } as unknown as SupabaseAdminClient;
  const sdk = new MasterDanceAdminSDK(client);

  await assert.rejects(
    sdk.runAction("issue_guardian_link_code", { guardian_id: guardianID }),
    /valid guardian email and phone/i
  );
  assert.equal(rpcCalled, false);
});

test("incomplete contact override cannot clear a linked guardian account", async () => {
  let patchCalled = false;
  const guardianID = "00000000-0000-4000-8000-000000000003";
  const client = {
    identity: async () => ({
      userId: "00000000-0000-4000-8000-000000000001",
      organizationId: "00000000-0000-4000-8000-000000000002",
      displayName: "Admin",
      role: "administrator" as const
    }),
    postgrest: async <T>(method: string) => {
      if (method === "PATCH") patchCalled = true;
      return [{
        id: guardianID,
        organization_id: "00000000-0000-4000-8000-000000000002",
        profile_user_id: "00000000-0000-4000-8000-000000000004",
        display_name: "Linked Family",
        email: "parent@example.com",
        phone: "+1 (949) 555-0123"
      }] as T;
    }
  } as unknown as SupabaseAdminClient;
  const sdk = new MasterDanceAdminSDK(client);

  await assert.rejects(
    sdk.updateRecord(
      "guardians",
      guardianID,
      { phone: null },
      { allowIncompleteGuardianContact: true }
    ),
    /only before a guardian account is linked/i
  );
  assert.equal(patchCalled, false);
});

test("legacy deterministic PostgreSQL UUIDs remain writable", async () => {
  const importedCourseID = "49e45d55-7819-b85b-4dfc-3abc8d6d9cac";
  let savedCourseID: JsonValue | undefined;
  const client = {
    identity: async () => ({
      userId: "00000000-0000-4000-8000-000000000001",
      organizationId: "00000000-0000-4000-8000-000000000002",
      displayName: "Admin",
      role: "administrator" as const
    }),
    postgrest: async <T>() => [] as T,
    rpc: async <T>(_name: string, input: Record<string, JsonValue>) => {
      savedCourseID = input.target_course_id;
      return input as T;
    }
  } as unknown as SupabaseAdminClient;
  const sdk = new MasterDanceAdminSDK(client);

  await sdk.runAction("save_enrollment", {
    term_id: "00000000-0000-4000-8000-000000000003",
    course_id: importedCourseID,
    student_id: "00000000-0000-4000-8000-000000000004"
  });

  assert.equal(savedCourseID, importedCourseID);
});
