import { randomUUID } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import { isAbsolute } from "node:path";
import type {
  ActionName,
  AdminIdentity,
  AdminResult,
  BillingLineItemInput,
  CoursePricingInput,
  IssueInvoiceInput,
  JsonObject,
  JsonValue,
  ListRecordsOptions,
  RecordMutationOptions,
  RecordPaymentInput,
  ResourceName,
  SaveEnrollmentInput,
  SaveLeaveRequestInput,
  SetAttendanceInput
} from "./contracts.js";
import { actionNames, resourceNames } from "./contracts.js";
import { AdminIntegrationError } from "./errors.js";
import { resourceSpec, resourceSpecs } from "./resources.js";
import { SupabaseAdminClient } from "./supabase.js";

// PostgreSQL accepts canonical UUID text regardless of RFC version/variant bits.
// Legacy imported Master Dance records include deterministic UUIDs with those
// bits unset, so the integration must validate the database format itself.
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const pngSignature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

export class MasterDanceAdminSDK {
  readonly client: SupabaseAdminClient;

  constructor(client: SupabaseAdminClient) {
    this.client = client;
  }

  identity(): Promise<AdminIdentity> {
    return this.client.identity();
  }

  async capabilities(): Promise<AdminResult<JsonValue>> {
    const identity = await this.identity();
    const resources = resourceNames.map((name) => {
      const spec = resourceSpecs[name];
      return {
        name,
        label: spec.label,
        can_create: spec.createFields.length > 0,
        can_update: spec.updateFields.length > 0,
        can_delete: spec.deleteStrategy.kind !== "none",
        notes: spec.notes ?? null
      };
    });
    return ok({
      identity: {
        userId: identity.userId,
        organizationId: identity.organizationId,
        displayName: identity.displayName,
        role: identity.role
      },
      resources,
      actions: [...actionNames],
      invariants: [
        "All writes use an authenticated active administrator and Supabase RLS.",
        "Issued invoices, payments, contract consents, and audit records are immutable.",
        "Linked records use dependency-aware deletion instead of raw hard deletes.",
        "Course categories remain hidden compatibility data."
      ]
    });
  }

  async listRecords(
    resource: ResourceName,
    options: ListRecordsOptions = {}
  ): Promise<AdminResult<JsonValue>> {
    const identity = await this.identity();
    const spec = resourceSpec(resource);
    const query = new URLSearchParams({ select: spec.readFields.join(",") });

    if (spec.organizationScoped) {
      query.append("organization_id", `eq.${identity.organizationId}`);
    } else if (resource === "organizations") {
      query.append("id", `eq.${identity.organizationId}`);
    }

    for (const filter of options.filters ?? []) {
      assertFieldAllowed(spec.readFields, filter.field, "filter");
      query.append(filter.field, encodeFilter(filter.operator ?? "eq", filter.value));
    }

    const search = options.search?.trim();
    if (search) {
      if (spec.searchFields.length === 0) {
        throw new AdminIntegrationError("search_not_supported", `${spec.label} does not expose text search fields.`);
      }
      const escaped = search.replace(/[(),]/g, " ");
      const expression = spec.searchFields.map((field) => `${field}.ilike.*${escaped}*`).join(",");
      query.append("or", `(${expression})`);
    }

    const sort = options.sort?.length ? options.sort : spec.defaultSort;
    for (const item of sort) assertFieldAllowed(spec.readFields, item.field, "sort");
    if (sort.length) {
      query.set("order", sort.map((item) => `${item.field}.${item.ascending === false ? "desc" : "asc"}`).join(","));
    }

    const limit = clampInteger(options.limit ?? 100, 1, 500, "limit");
    const offset = clampInteger(options.offset ?? 0, 0, 1_000_000, "offset");
    query.set("limit", String(limit));
    query.set("offset", String(offset));

    const rows = await this.client.postgrest<JsonValue[]>("GET", spec.table, { query });
    return ok({ resource, count: rows.length, records: rows });
  }

  async getRecord(resource: ResourceName, id: string): Promise<AdminResult<JsonValue>> {
    assertIdentifier(id, "id");
    const spec = resourceSpec(resource);
    if (!spec.readFields.includes("id")) {
      throw new AdminIntegrationError(
        "composite_resource",
        `${spec.label} has no single id. Use listRecords with filters.`
      );
    }
    const identity = await this.identity();
    const query = new URLSearchParams({
      select: spec.readFields.join(","),
      id: `eq.${id}`,
      limit: "1"
    });
    if (spec.organizationScoped) query.append("organization_id", `eq.${identity.organizationId}`);
    if (resource === "organizations" && id !== identity.organizationId) {
      throw new AdminIntegrationError("organization_scope", "Only the active school can be accessed.");
    }
    const rows = await this.client.postgrest<JsonValue[]>("GET", spec.table, { query });
    const record = rows[0];
    if (record === undefined) {
      throw new AdminIntegrationError("record_not_found", `${spec.label} record was not found.`, { status: 404 });
    }
    return ok(record);
  }

  async createRecord(
    resource: ResourceName,
    values: JsonObject,
    options: RecordMutationOptions = {}
  ): Promise<AdminResult<JsonValue>> {
    const spec = resourceSpec(resource);
    assertMutationOptions(resource, options);
    if (spec.createFields.length === 0) {
      throw new AdminIntegrationError(
        "create_not_supported",
        `${spec.label} cannot be created through generic CRUD.${spec.notes ? ` ${spec.notes}` : ""}`
      );
    }
    assertNoUnsupportedFields(values, spec.createFields, spec.label);
    if (resource === "students") {
      return this.runAction("create_student_for_guardian", values);
    }

    const identity = await this.identity();
    const payload: JsonObject = {
      ...(spec.createDefaults ?? {}),
      ...pickFields(values, spec.createFields)
    };
    if (spec.organizationScoped) payload.organization_id = identity.organizationId;
    if (spec.generateId && payload.id === undefined) payload.id = randomUUID();

    for (const field of spec.requiredCreate) {
      if (
        resource === "guardians"
        && options.allowIncompleteGuardianContact
        && (field === "email" || field === "phone")
      ) {
        continue;
      }
      if (payload[field] === undefined || payload[field] === null || payload[field] === "") {
        throw new AdminIntegrationError("required_field", `${field} is required for ${spec.label}.`);
      }
    }

    if (resource === "guardians") {
      normalizeGuardian(payload, false, options.allowIncompleteGuardianContact === true);
    }
    if (resource === "courses") {
      payload.category_id = await this.hiddenCourseCategoryID(identity.organizationId);
      await this.validateCoursePayload(payload);
    }
    normalizePublishState(resource, payload);

    const rows = await this.client.postgrest<JsonValue[]>("POST", spec.table, {
      body: payload,
      prefer: "return=representation"
    });
    const record = rows[0];
    if (record === undefined) throw new AdminIntegrationError("create_failed", `${spec.label} was not returned after creation.`);
    return ok(record, guardianContactWarnings(resource, payload));
  }

  async updateRecord(
    resource: ResourceName,
    id: string,
    changes: JsonObject,
    options: RecordMutationOptions = {}
  ): Promise<AdminResult<JsonValue>> {
    assertIdentifier(id, "id");
    const spec = resourceSpec(resource);
    assertMutationOptions(resource, options);
    if (spec.updateFields.length === 0) {
      throw new AdminIntegrationError(
        "update_not_supported",
        `${spec.label} is immutable or requires a dedicated action.${spec.notes ? ` ${spec.notes}` : ""}`
      );
    }
    const identity = await this.identity();
    assertNoUnsupportedFields(changes, spec.updateFields, spec.label);
    const payload = pickFields(changes, spec.updateFields);
    if (Object.keys(payload).length === 0) {
      throw new AdminIntegrationError("empty_update", `No supported ${spec.label} fields were supplied.`);
    }

    if (resource === "guardians") {
      if (options.allowIncompleteGuardianContact) {
        const current = asObject((await this.getRecord("guardians", id)).result);
        if (current.profile_user_id !== null && current.profile_user_id !== undefined) {
          throw new AdminIntegrationError(
            "linked_guardian_contact_required",
            "The incomplete-contact override is available only before a guardian account is linked."
          );
        }
      }
      normalizeGuardian(payload, true, options.allowIncompleteGuardianContact === true);
    }
    if (resource === "courses") {
      const current = asObject((await this.getRecord("courses", id)).result);
      await this.validateCoursePayload({ ...current, ...payload });
    }
    normalizePublishState(resource, payload);

    const query = new URLSearchParams({ id: `eq.${id}` });
    if (spec.organizationScoped) query.append("organization_id", `eq.${identity.organizationId}`);
    const rows = await this.client.postgrest<JsonValue[]>("PATCH", spec.table, {
      query,
      body: payload,
      prefer: "return=representation"
    });
    const record = rows[0];
    if (record === undefined) {
      throw new AdminIntegrationError("record_not_found", `${spec.label} record was not found.`, { status: 404 });
    }
    return ok(record, guardianContactWarnings(resource, payload));
  }

  async deleteRecord(resource: ResourceName, id: string): Promise<AdminResult<JsonValue>> {
    assertIdentifier(id, "id");
    const spec = resourceSpec(resource);
    const identity = await this.identity();
    const strategy = spec.deleteStrategy;
    const warnings: string[] = [];

    switch (strategy.kind) {
      case "none":
        throw new AdminIntegrationError(
          "delete_not_supported",
          `${spec.label} cannot be deleted through this API.${spec.notes ? ` ${spec.notes}` : ""}`
        );
      case "managed":
        await this.client.rpc("admin_delete_record", {
          target_kind: strategy.recordKind,
          target_id: id
        });
        break;
      case "guardian_household":
        await this.client.rpc("admin_delete_guardian_household", { target_guardian_id: id });
        break;
      case "direct":
        await this.directDelete(spec.table, id, identity.organizationId);
        break;
      case "media": {
        const record = asObject((await this.getRecord(resource, id)).result);
        await this.directDelete(spec.table, id, identity.organizationId);
        const paths = strategy.pathFields
          .map((field) => record[field])
          .filter((value): value is string => typeof value === "string" && value.length > 0);
        await this.cleanupStorage(strategy.bucket, paths, warnings);
        break;
      }
      case "news_article": {
        const images = await this.listRecords("news_article_images", {
          filters: [{ field: "article_id", value: id }],
          limit: 500
        });
        const paths = asObject(images.result).records;
        const storagePaths = Array.isArray(paths)
          ? paths.map((row) => asObject(row).storage_path).filter((value): value is string => typeof value === "string")
          : [];
        await this.directDelete(spec.table, id, identity.organizationId);
        await this.cleanupStorage("news-media", storagePaths, warnings);
        break;
      }
    }

    return { ok: true, result: { resource, id, deleted: true }, warnings };
  }

  async runAction(action: ActionName, input: JsonObject): Promise<AdminResult<JsonValue>> {
    await this.identity();
    switch (action) {
      case "set_course_pricing":
        return this.setCoursePricing(input as unknown as CoursePricingInput);
      case "save_enrollment":
        return this.saveEnrollment(input as unknown as SaveEnrollmentInput);
      case "set_attendance":
        return this.setAttendance(input as unknown as SetAttendanceInput);
      case "clear_attendance":
        return this.clearAttendance(input);
      case "save_leave_request":
        return this.saveLeaveRequest(input as unknown as SaveLeaveRequestInput);
      case "create_student_for_guardian":
        return this.createStudentForGuardian(input);
      case "link_student_to_guardian":
        return this.linkStudentToGuardian(input);
      case "issue_guardian_link_code":
        return this.issueGuardianLinkCode(input);
      case "publish_contract_revision":
        return this.publishContractRevision(input);
      case "update_profile_access":
        return this.updateProfileAccess(input);
      case "upload_media":
        return this.uploadMedia(input);
      case "remove_media":
        return this.removeMedia(input);
      case "issue_invoice":
        return this.issueInvoice(input as unknown as IssueInvoiceInput);
      case "record_payment":
        return this.recordPayment(input as unknown as RecordPaymentInput);
    }
  }

  private async setCoursePricing(input: CoursePricingInput): Promise<AdminResult<JsonValue>> {
    assertUUID(input.course_id, "course_id");
    const course = asObject((await this.getRecord("courses", input.course_id)).result);
    const payload: JsonObject = {
      ...course,
      pricing_status: input.pricing_status,
      unit_price_cents: input.full_term_unit_price_cents ?? null,
      drop_in_unit_price_cents: input.per_session_unit_price_cents ?? null
    };
    await this.validateCoursePayload(payload);
    return this.updateRecord("courses", input.course_id, {
      pricing_status: payload.pricing_status ?? null,
      unit_price_cents: payload.unit_price_cents ?? null,
      drop_in_unit_price_cents: payload.drop_in_unit_price_cents ?? null
    });
  }

  private async saveEnrollment(input: SaveEnrollmentInput): Promise<AdminResult<JsonValue>> {
    assertUUID(input.term_id, "term_id");
    assertUUID(input.course_id, "course_id");
    assertUUID(input.student_id, "student_id");

    let id = input.id;
    if (!id) {
      const existing = await this.listRecords("enrollments", {
        filters: [
          { field: "term_id", value: input.term_id },
          { field: "course_id", value: input.course_id },
          { field: "student_id", value: input.student_id }
        ],
        limit: 1
      });
      const records = asObject(existing.result).records;
      const first = Array.isArray(records) ? records[0] : undefined;
      if (first !== undefined) {
        const existingID = asObject(first).id;
        if (typeof existingID === "string") id = existingID;
      }
    }
    const resolvedID = id ?? randomUUID();
    assertUUID(resolvedID, "id");

    const registrationMode = input.registration_mode ?? "full_term";
    const selectedSessionIDs = input.selected_session_ids ?? [];
    if (registrationMode === "full_term" && selectedSessionIDs.length !== 0) {
      throw new AdminIntegrationError("invalid_enrollment", "Full-term enrollment cannot contain selected sessions.");
    }
    if (registrationMode === "per_session" && selectedSessionIDs.length === 0) {
      throw new AdminIntegrationError("invalid_enrollment", "Per-session enrollment requires at least one selected session.");
    }
    selectedSessionIDs.forEach((value) => assertUUID(value, "selected_session_ids"));

    const row = await this.client.rpc<JsonValue>("admin_save_enrollment", {
      target_id: resolvedID,
      target_term_id: input.term_id,
      target_course_id: input.course_id,
      target_student_id: input.student_id,
      target_enrolled_at: input.enrolled_at ?? new Date().toISOString(),
      target_status: input.status ?? "active",
      target_registration_mode: registrationMode,
      target_pricing_status: input.pricing_status ?? "pending",
      target_billing_starts_on: input.billing_starts_on ?? null,
      target_unit_price_cents: input.unit_price_cents ?? null,
      target_trial_fee_cents: input.trial_fee_cents ?? 0,
      target_discount_name: input.discount_name ?? null,
      target_discount_kind: input.discount_kind ?? null,
      target_discount_value: input.discount_value ?? null,
      target_billing_notes: input.billing_notes ?? null,
      target_selected_session_ids: selectedSessionIDs
    });
    return ok(row);
  }

  private async setAttendance(input: SetAttendanceInput): Promise<AdminResult<JsonValue>> {
    const identity = await this.identity();
    assertUUID(input.session_id, "session_id");
    assertUUID(input.student_id, "student_id");
    if (input.enrollment_id) assertUUID(input.enrollment_id, "enrollment_id");
    if (input.makeup_for_session_id) assertUUID(input.makeup_for_session_id, "makeup_for_session_id");
    if (input.status === "makeup" && !input.makeup_for_session_id) {
      throw new AdminIntegrationError("makeup_source_required", "Makeup attendance requires makeup_for_session_id.");
    }
    if (input.status !== "makeup" && input.makeup_for_session_id) {
      throw new AdminIntegrationError("invalid_makeup_source", "Only makeup attendance may reference a makeup source session.");
    }

    let id = input.id;
    if (!id) {
      const existing = await this.listRecords("attendance", {
        filters: [
          { field: "session_id", value: input.session_id },
          { field: "student_id", value: input.student_id }
        ],
        limit: 1
      });
      const records = asObject(existing.result).records;
      const first = Array.isArray(records) ? records[0] : undefined;
      const value = first === undefined ? undefined : asObject(first).id;
      if (typeof value === "string") id = value;
    }
    const resolvedID = id ?? randomUUID();

    const payload: JsonObject = {
      id: resolvedID,
      organization_id: identity.organizationId,
      session_id: input.session_id,
      student_id: input.student_id,
      enrollment_id: input.enrollment_id ?? null,
      makeup_for_session_id: input.makeup_for_session_id ?? null,
      status: input.status,
      recorded_at: input.recorded_at ?? new Date().toISOString(),
      recorded_by: identity.userId,
      note: input.note ?? null
    };
    const query = new URLSearchParams({ on_conflict: "session_id,student_id" });
    const rows = await this.client.postgrest<JsonValue[]>("POST", "attendance", {
      query,
      body: payload,
      prefer: "resolution=merge-duplicates,return=representation"
    });
    return ok(rows[0] ?? payload);
  }

  private async clearAttendance(input: JsonObject): Promise<AdminResult<JsonValue>> {
    const identity = await this.identity();
    const query = new URLSearchParams({ organization_id: `eq.${identity.organizationId}` });
    const id = stringField(input, "id", false);
    const sessionID = stringField(input, "session_id", false);
    const studentID = stringField(input, "student_id", false);
    if (id) {
      assertUUID(id, "id");
      query.append("id", `eq.${id}`);
    } else if (sessionID && studentID) {
      assertUUID(sessionID, "session_id");
      assertUUID(studentID, "student_id");
      query.append("session_id", `eq.${sessionID}`);
      query.append("student_id", `eq.${studentID}`);
    } else {
      throw new AdminIntegrationError("attendance_identity_required", "Provide id, or both session_id and student_id.");
    }
    const rows = await this.client.postgrest<JsonValue[]>("DELETE", "attendance", {
      query,
      prefer: "return=representation"
    });
    return ok({ deleted: rows.length > 0, records: rows });
  }

  private async saveLeaveRequest(input: SaveLeaveRequestInput): Promise<AdminResult<JsonValue>> {
    const identity = await this.identity();
    assertUUID(input.session_id, "session_id");
    assertUUID(input.student_id, "student_id");
    if (input.enrollment_id) assertUUID(input.enrollment_id, "enrollment_id");

    let id = input.id;
    if (!id) {
      const existing = await this.listRecords("leave_requests", {
        filters: [
          { field: "session_id", value: input.session_id },
          { field: "student_id", value: input.student_id }
        ],
        limit: 1
      });
      const records = asObject(existing.result).records;
      const first = Array.isArray(records) ? records[0] : undefined;
      const value = first === undefined ? undefined : asObject(first).id;
      if (typeof value === "string") id = value;
    }
    const resolvedID = id ?? randomUUID();

    const payload: JsonObject = {
      id: resolvedID,
      organization_id: identity.organizationId,
      session_id: input.session_id,
      student_id: input.student_id,
      enrollment_id: input.enrollment_id ?? null,
      source: "administrator",
      status: "approved",
      submitted_at: input.submitted_at ?? new Date().toISOString(),
      submitted_by: identity.userId,
      resolved_at: null,
      resolved_by: null,
      note: input.note ?? null
    };
    const query = new URLSearchParams({ on_conflict: "session_id,student_id" });
    const rows = await this.client.postgrest<JsonValue[]>("POST", "leave_requests", {
      query,
      body: payload,
      prefer: "resolution=merge-duplicates,return=representation"
    });
    return ok(rows[0] ?? payload);
  }

  private async createStudentForGuardian(input: JsonObject): Promise<AdminResult<JsonValue>> {
    const guardianID = stringField(input, "guardian_id");
    const displayName = stringField(input, "display_name");
    const kind = stringField(input, "kind");
    assertUUID(guardianID, "guardian_id");
    if (kind !== "child" && kind !== "adult") {
      throw new AdminIntegrationError("invalid_student_kind", "kind must be child or adult.");
    }
    const row = await this.client.rpc<JsonValue>("admin_create_student_for_guardian", {
      target_guardian_id: guardianID,
      target_display_name: displayName,
      target_legal_name: nullableString(input.legal_name),
      target_kind: kind,
      target_birth_date: nullableString(input.birth_date)
    });
    return ok(row);
  }

  private async linkStudentToGuardian(input: JsonObject): Promise<AdminResult<JsonValue>> {
    const guardianID = stringField(input, "guardian_id");
    const studentID = stringField(input, "student_id");
    assertUUID(guardianID, "guardian_id");
    assertUUID(studentID, "student_id");
    const row = await this.client.rpc<JsonValue>("admin_link_student_to_guardian", {
      target_guardian_id: guardianID,
      target_student_id: studentID
    });
    return ok(row);
  }

  private async issueGuardianLinkCode(input: JsonObject): Promise<AdminResult<JsonValue>> {
    const guardianID = stringField(input, "guardian_id");
    assertUUID(guardianID, "guardian_id");
    const guardian = asObject((await this.getRecord("guardians", guardianID)).result);
    const email = guardian.email;
    const phone = guardian.phone;
    if (
      typeof email !== "string"
      || !emailPattern.test(email.trim())
      || typeof phone !== "string"
      || !isValidUSPhone(phone)
    ) {
      throw new AdminIntegrationError(
        "incomplete_guardian_contact",
        "Add a valid guardian email and phone before issuing an invitation code."
      );
    }
    const validityDays = clampInteger(numberField(input, "validity_days", false) ?? 14, 1, 90, "validity_days");
    const row = await this.client.rpc<JsonValue>("admin_issue_guardian_link_code", {
      target_guardian_id: guardianID,
      validity_days: validityDays
    });
    return ok(row);
  }

  private async publishContractRevision(input: JsonObject): Promise<AdminResult<JsonValue>> {
    const termID = stringField(input, "term_id");
    const title = stringField(input, "title");
    const bodyText = stringField(input, "body_text");
    assertUUID(termID, "term_id");
    if (bodyText.trim().length < 20 || bodyText.length > 50_000) {
      throw new AdminIntegrationError("invalid_contract_body", "Contract body must contain 20 to 50000 characters.");
    }
    const row = await this.client.rpc<JsonValue>("admin_publish_contract_revision", {
      target_term_id: termID,
      document_title: title,
      document_body_text: bodyText
    });
    return ok(row);
  }

  private async updateProfileAccess(input: JsonObject): Promise<AdminResult<JsonValue>> {
    const userID = stringField(input, "user_id");
    const displayName = stringField(input, "display_name");
    assertUUID(userID, "user_id");
    const isActive = booleanField(input, "is_active", false) ?? true;
    const row = await this.client.rpc<JsonValue>("admin_update_profile_access", {
      target_user_id: userID,
      target_display_name: displayName,
      target_is_active: isActive
    });
    return ok(row);
  }

  private async uploadMedia(input: JsonObject): Promise<AdminResult<JsonValue>> {
    const identity = await this.identity();
    const bucket = stringField(input, "bucket");
    const storagePath = stringField(input, "storage_path");
    const filePath = stringField(input, "file_path");
    const mimeType = stringField(input, "mime_type");
    const upsert = booleanField(input, "upsert", false) ?? false;
    const allowedBuckets = ["news-media", "advertisement-media", "contracts", "billing-documents"];
    if (!allowedBuckets.includes(bucket)) {
      throw new AdminIntegrationError("bucket_not_allowed", `bucket must be one of ${allowedBuckets.join(", ")}.`);
    }
    validateStoragePath(storagePath, identity.organizationId);
    if (!isAbsolute(filePath)) throw new AdminIntegrationError("absolute_path_required", "file_path must be absolute.");
    const fileStat = await stat(filePath);
    const limit = bucket === "contracts" ? 10 * 1024 * 1024 : 8 * 1024 * 1024;
    if (!fileStat.isFile() || fileStat.size < 1 || fileStat.size > limit) {
      throw new AdminIntegrationError("invalid_file_size", `File must be between 1 byte and ${limit} bytes.`);
    }
    const bytes = await readFile(filePath);
    const result = await this.client.uploadStorageObject(bucket, storagePath, bytes, mimeType, upsert);
    return ok({ bucket, storage_path: storagePath, byte_count: bytes.byteLength, upload: result });
  }

  private async removeMedia(input: JsonObject): Promise<AdminResult<JsonValue>> {
    const identity = await this.identity();
    const bucket = stringField(input, "bucket");
    const rawPaths = input.storage_paths;
    if (!Array.isArray(rawPaths) || rawPaths.length === 0 || rawPaths.some((value) => typeof value !== "string")) {
      throw new AdminIntegrationError("storage_paths_required", "storage_paths must be a non-empty string array.");
    }
    const paths = rawPaths as string[];
    paths.forEach((value) => validateStoragePath(value, identity.organizationId));
    const result = await this.client.removeStorageObjects(bucket, paths);
    return ok({ bucket, storage_paths: paths, removal: result });
  }

  private async issueInvoice(input: IssueInvoiceInput): Promise<AdminResult<JsonValue>> {
    const identity = await this.identity();
    assertUUID(input.guardian_id, "guardian_id");
    assertUUID(input.term_id, "term_id");
    if (!Array.isArray(input.learner_ids) || input.learner_ids.length === 0) {
      throw new AdminIntegrationError("learner_scope_required", "At least one learner_id is required.");
    }
    input.learner_ids.forEach((value) => assertUUID(value, "learner_ids"));
    if (!Array.isArray(input.items) || input.items.length === 0) {
      throw new AdminIntegrationError("invoice_items_required", "At least one invoice item is required.");
    }
    if (!Number.isInteger(input.version) || input.version < 1) {
      throw new AdminIntegrationError("invalid_version", "Invoice version must be a positive integer.");
    }

    const invoiceID = input.invoice_id ?? randomUUID();
    assertUUID(invoiceID, "invoice_id");
    const bilingualArtifactID = randomUUID();
    const englishArtifactID = randomUUID();
    const base = `${identity.organizationId}/${input.guardian_id}/${invoiceID}`.toLowerCase();
    const bilingualStoragePath = `${base}/invoice-v${input.version}-zh_en.png`;
    const englishStoragePath = `${base}/invoice-v${input.version}-en.png`;
    const bilingual = await readPNG(input.bilingual_png_path);
    const english = await readPNG(input.english_png_path);
    const uploaded: string[] = [];
    try {
      await this.client.uploadStorageObject("billing-documents", bilingualStoragePath, bilingual, "image/png", false);
      uploaded.push(bilingualStoragePath);
      await this.client.uploadStorageObject("billing-documents", englishStoragePath, english, "image/png", false);
      uploaded.push(englishStoragePath);
      const row = await this.client.rpc<JsonValue>("admin_issue_billing_invoice_scoped_dual", {
        target_invoice_id: invoiceID,
        target_guardian_id: input.guardian_id,
        target_term_id: input.term_id,
        target_learner_ids: input.learner_ids,
        target_invoice_number: input.invoice_number,
        target_version: input.version,
        target_school_year_label: input.school_year_label,
        target_issued_at: input.issued_at ?? new Date().toISOString(),
        target_notes: input.notes ?? "",
        target_supersedes_invoice_id: input.supersedes_invoice_id ?? null,
        target_bilingual_artifact_id: bilingualArtifactID,
        target_bilingual_storage_path: bilingualStoragePath,
        target_english_artifact_id: englishArtifactID,
        target_english_storage_path: englishStoragePath,
        target_items: input.items.map((item, index) => billingItemPayload(item, index))
      });
      return ok(row);
    } catch (error) {
      await this.client.removeStorageObjects("billing-documents", uploaded).catch(() => undefined);
      throw error;
    }
  }

  private async recordPayment(input: RecordPaymentInput): Promise<AdminResult<JsonValue>> {
    assertUUID(input.invoice_id, "invoice_id");
    if (!Number.isInteger(input.amount_cents) || input.amount_cents <= 0) {
      throw new AdminIntegrationError("invalid_payment", "amount_cents must be a positive integer.");
    }
    const processingFee = input.processing_fee_cents ?? 0;
    if (!Number.isInteger(processingFee) || processingFee < 0 || (input.method !== "card" && processingFee !== 0)) {
      throw new AdminIntegrationError("invalid_processing_fee", "Only card payments may include a nonnegative processing fee.");
    }
    const invoice = asObject((await this.getRecord("billing_invoices", input.invoice_id)).result);
    const guardianID = stringField(invoice, "guardian_id");
    const identity = await this.identity();
    const paymentID = input.payment_id ?? randomUUID();
    assertUUID(paymentID, "payment_id");
    const base = `${identity.organizationId}/${guardianID}/${input.invoice_id}`.toLowerCase();
    const bilingualStoragePath = `${base}/receipt-${paymentID.toLowerCase()}-zh_en.png`;
    const englishStoragePath = `${base}/receipt-${paymentID.toLowerCase()}-en.png`;
    const bilingual = await readPNG(input.bilingual_png_path);
    const english = await readPNG(input.english_png_path);
    const uploaded: string[] = [];
    try {
      await this.client.uploadStorageObject("billing-documents", bilingualStoragePath, bilingual, "image/png", false);
      uploaded.push(bilingualStoragePath);
      await this.client.uploadStorageObject("billing-documents", englishStoragePath, english, "image/png", false);
      uploaded.push(englishStoragePath);
      const row = await this.client.rpc<JsonValue>("admin_record_billing_payment_dual", {
        target_payment_id: paymentID,
        target_invoice_id: input.invoice_id,
        target_amount_cents: input.amount_cents,
        target_processing_fee_cents: processingFee,
        target_method: input.method,
        target_received_at: input.received_at ?? new Date().toISOString(),
        target_note: input.note ?? "",
        target_bilingual_artifact_id: randomUUID(),
        target_bilingual_storage_path: bilingualStoragePath,
        target_english_artifact_id: randomUUID(),
        target_english_storage_path: englishStoragePath
      });
      return ok(row);
    } catch (error) {
      await this.client.removeStorageObjects("billing-documents", uploaded).catch(() => undefined);
      throw error;
    }
  }

  private async validateCoursePayload(payload: JsonObject): Promise<void> {
    const format = payload.format;
    const status = payload.pricing_status;
    const fullTerm = payload.unit_price_cents;
    const perSession = payload.drop_in_unit_price_cents;
    if (format !== "group" && format !== "private_lesson") {
      throw new AdminIntegrationError("invalid_course_format", "format must be group or private_lesson.");
    }
    if (!["pending", "priced", "free", "review_required"].includes(String(status))) {
      throw new AdminIntegrationError("invalid_pricing_status", "Course pricing_status is invalid.");
    }
    for (const [name, value] of [["unit_price_cents", fullTerm], ["drop_in_unit_price_cents", perSession]] as const) {
      if (value !== null && value !== undefined && (!Number.isInteger(value) || Number(value) < 0)) {
        throw new AdminIntegrationError("invalid_price", `${name} must be null or a nonnegative integer in USD cents.`);
      }
    }
    if (format === "private_lesson" && fullTerm !== null && fullTerm !== undefined) {
      throw new AdminIntegrationError("private_lesson_pricing", "Private lessons cannot have a full-term unit price.");
    }
    const primaryPrice = format === "private_lesson" ? perSession : fullTerm;
    if (status === "pending" && primaryPrice !== null && primaryPrice !== undefined) {
      throw new AdminIntegrationError("pricing_state_mismatch", "Pending pricing requires the primary course price to be null.");
    }
    if (status === "priced" && (!Number.isInteger(primaryPrice) || Number(primaryPrice) <= 0)) {
      throw new AdminIntegrationError("pricing_state_mismatch", "Priced courses require a positive primary course price.");
    }
    if (status === "free" && primaryPrice !== 0) {
      throw new AdminIntegrationError("pricing_state_mismatch", "Free courses require a zero primary course price.");
    }
  }

  private async hiddenCourseCategoryID(organizationID: string): Promise<string> {
    const query = new URLSearchParams({
      select: "id",
      organization_id: `eq.${organizationID}`,
      is_active: "eq.true",
      order: "created_at.asc",
      limit: "1"
    });
    const rows = await this.client.postgrest<JsonObject[]>("GET", "course_categories", { query });
    const id = rows[0]?.id;
    if (typeof id !== "string") {
      throw new AdminIntegrationError("course_category_missing", "The hidden compatibility course category is unavailable.");
    }
    return id;
  }

  private async directDelete(table: string, id: string, organizationID: string): Promise<void> {
    const query = new URLSearchParams({ id: `eq.${id}`, organization_id: `eq.${organizationID}` });
    await this.client.postgrest<JsonValue[]>("DELETE", table, { query, prefer: "return=representation" });
  }

  private async cleanupStorage(bucket: string, paths: string[], warnings: string[]): Promise<void> {
    if (paths.length === 0) return;
    try {
      await this.client.removeStorageObjects(bucket, paths);
    } catch (error) {
      warnings.push(`Database record was deleted, but ${bucket} cleanup needs retry: ${error instanceof Error ? error.message : "unknown error"}`);
    }
  }
}

function ok(result: JsonValue, warnings: string[] = []): AdminResult<JsonValue> {
  return { ok: true, result, warnings };
}

function pickFields(values: JsonObject, allowed: readonly string[]): JsonObject {
  const result: JsonObject = {};
  for (const field of allowed) {
    if (values[field] !== undefined) result[field] = values[field] as JsonValue;
  }
  return result;
}

function assertNoUnsupportedFields(
  values: JsonObject,
  allowed: readonly string[],
  label: string
): void {
  const unsupported = Object.keys(values).filter((field) => !allowed.includes(field));
  if (unsupported.length > 0) {
    throw new AdminIntegrationError(
      "unsupported_fields",
      `${label} does not accept: ${unsupported.join(", ")}.`
    );
  }
}

function assertFieldAllowed(fields: readonly string[], field: string, purpose: string): void {
  if (!fields.includes(field)) {
    throw new AdminIntegrationError("field_not_allowed", `${field} is not available for ${purpose}.`);
  }
}

function encodeFilter(operator: string, value: JsonValue): string {
  if (operator === "in") {
    if (!Array.isArray(value) || value.length === 0) {
      throw new AdminIntegrationError("invalid_filter", "The in operator requires a non-empty array.");
    }
    const encoded = value.map((item) => {
      if (!["string", "number", "boolean"].includes(typeof item) || String(item).includes(",")) {
        throw new AdminIntegrationError("invalid_filter", "in values must be simple values without commas.");
      }
      return String(item);
    });
    return `in.(${encoded.join(",")})`;
  }
  if (operator === "is") {
    if (value !== null && value !== true && value !== false) {
      throw new AdminIntegrationError("invalid_filter", "The is operator accepts null, true, or false.");
    }
    return `is.${String(value)}`;
  }
  if (Array.isArray(value) || (value !== null && typeof value === "object")) {
    throw new AdminIntegrationError("invalid_filter", `${operator} requires a scalar value.`);
  }
  return `${operator}.${String(value)}`;
}

function normalizeGuardian(
  payload: JsonObject,
  partial = false,
  allowIncompleteContact = false
): void {
  if (payload.email !== undefined) {
    if (payload.email === null || payload.email === "") {
      if (!allowIncompleteContact) {
        throw new AdminIntegrationError("required_field", "Guardian email is required.");
      }
      payload.email = null;
    } else if (typeof payload.email !== "string" || !emailPattern.test(payload.email.trim())) {
      throw new AdminIntegrationError("invalid_email", "Guardian email format is invalid.");
    } else {
      payload.email = payload.email.trim().toLowerCase();
    }
  } else if (!partial && allowIncompleteContact) {
    payload.email = null;
  } else if (!partial) {
    throw new AdminIntegrationError("required_field", "Guardian email is required.");
  }

  if (payload.secondary_email === "") {
    payload.secondary_email = null;
  } else if (payload.secondary_email !== undefined && payload.secondary_email !== null) {
    if (typeof payload.secondary_email !== "string" || !emailPattern.test(payload.secondary_email.trim())) {
      throw new AdminIntegrationError("invalid_email", "Guardian secondary_email format is invalid.");
    }
    payload.secondary_email = payload.secondary_email.trim().toLowerCase();
  }

  if (payload.phone !== undefined) {
    if (payload.phone === null || payload.phone === "") {
      if (!allowIncompleteContact) {
        throw new AdminIntegrationError("required_field", "Guardian phone is required.");
      }
      payload.phone = null;
    } else {
      if (typeof payload.phone !== "string") throw new AdminIntegrationError("invalid_phone", "Guardian phone is invalid.");
      payload.phone = normalizeUSPhone(payload.phone);
    }
  } else if (!partial && allowIncompleteContact) {
    payload.phone = null;
  } else if (!partial) {
    throw new AdminIntegrationError("required_field", "Guardian phone is required.");
  }
}

function assertMutationOptions(resource: ResourceName, options: RecordMutationOptions): void {
  if (options.allowIncompleteGuardianContact && resource !== "guardians") {
    throw new AdminIntegrationError(
      "invalid_option",
      "allowIncompleteGuardianContact is available only for guardians."
    );
  }
}

function guardianContactWarnings(resource: ResourceName, payload: JsonObject): string[] {
  if (resource !== "guardians" || (payload.email !== null && payload.phone !== null)) return [];
  return [
    "Guardian saved with incomplete contact details. Add a valid email and phone before issuing an invitation code."
  ];
}

export function normalizeUSPhone(raw: string): string {
  let digits = raw.replace(/\D/g, "");
  if (digits.length === 11 && digits.startsWith("1")) digits = digits.slice(1);
  if (digits.length !== 10) {
    throw new AdminIntegrationError("invalid_phone", "US phone must contain 10 digits, optionally prefixed by +1.");
  }
  return `+1 (${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
}

function isValidUSPhone(raw: string): boolean {
  try {
    normalizeUSPhone(raw);
    return true;
  } catch {
    return false;
  }
}

function normalizePublishState(resource: ResourceName, payload: JsonObject): void {
  if ((resource === "news_articles" || resource === "advertisements") && payload.status === "published") {
    if (resource === "news_articles" && (payload.published_at === undefined || payload.published_at === null)) {
      payload.published_at = new Date().toISOString();
    }
  }
}

function validateStoragePath(path: string, organizationID: string): void {
  if (path.startsWith("/") || path.includes("..") || !path.startsWith(`${organizationID}/`)) {
    throw new AdminIntegrationError(
      "invalid_storage_path",
      `storage_path must stay under ${organizationID}/ and cannot contain '..'.`
    );
  }
}

async function readPNG(path: string): Promise<Buffer> {
  if (!isAbsolute(path)) throw new AdminIntegrationError("absolute_path_required", "PNG paths must be absolute.");
  const file = await readFile(path);
  if (file.byteLength < pngSignature.byteLength || !file.subarray(0, pngSignature.byteLength).equals(pngSignature)) {
    throw new AdminIntegrationError("invalid_png", `${path} is not a PNG file.`);
  }
  if (file.byteLength > 8 * 1024 * 1024) {
    throw new AdminIntegrationError("invalid_file_size", `${path} exceeds the 8 MB billing artifact limit.`);
  }
  return file;
}

function billingItemPayload(item: BillingLineItemInput, index: number): JsonObject {
  if (!Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > 999) {
    throw new AdminIntegrationError("invalid_invoice_item", "Invoice item quantity must be an integer from 1 to 999.");
  }
  if (!Number.isInteger(item.unit_amount_cents) || !Number.isInteger(item.amount_cents)) {
    throw new AdminIntegrationError("invalid_invoice_item", "Invoice money values must use integer USD cents.");
  }
  if (item.student_id) assertUUID(item.student_id, "student_id");
  if (item.enrollment_id) assertUUID(item.enrollment_id, "enrollment_id");
  return {
    id: item.id ?? randomUUID(),
    student_id: item.student_id ?? null,
    enrollment_id: item.enrollment_id ?? null,
    kind: item.kind,
    title: item.title,
    detail: item.detail ?? null,
    quantity: item.quantity,
    unit_amount_cents: item.unit_amount_cents,
    amount_cents: item.amount_cents,
    included_in_amount_due: !item.paid,
    sort_order: item.sort_order ?? index
  };
}

function clampInteger(value: number, minimum: number, maximum: number, name: string): number {
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new AdminIntegrationError("invalid_number", `${name} must be an integer from ${minimum} to ${maximum}.`);
  }
  return value;
}

function asObject(value: JsonValue): JsonObject {
  if (value === null || Array.isArray(value) || typeof value !== "object") {
    throw new AdminIntegrationError("invalid_response", "Expected a JSON object.");
  }
  return value;
}

function assertUUID(value: string, name: string): void {
  if (!uuidPattern.test(value)) throw new AdminIntegrationError("invalid_uuid", `${name} must be a UUID.`);
}

function assertIdentifier(value: string, name: string): void {
  if (!value || value.length > 200 || /[(),]/.test(value)) {
    throw new AdminIntegrationError("invalid_identifier", `${name} is invalid.`);
  }
}

function stringField(object: JsonObject, name: string, required = true): string {
  const value = object[name];
  if (typeof value === "string" && value.length > 0) return value;
  if (!required && (value === undefined || value === null || value === "")) return "";
  throw new AdminIntegrationError("invalid_field", `${name} must be a non-empty string.`);
}

function nullableString(value: JsonValue | undefined): string | null {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string") throw new AdminIntegrationError("invalid_field", "Expected a string or null.");
  return value;
}

function numberField(object: JsonObject, name: string, required = true): number | undefined {
  const value = object[name];
  if (typeof value === "number") return value;
  if (!required && (value === undefined || value === null)) return undefined;
  throw new AdminIntegrationError("invalid_field", `${name} must be a number.`);
}

function booleanField(object: JsonObject, name: string, required = true): boolean | undefined {
  const value = object[name];
  if (typeof value === "boolean") return value;
  if (!required && (value === undefined || value === null)) return undefined;
  throw new AdminIntegrationError("invalid_field", `${name} must be a boolean.`);
}
