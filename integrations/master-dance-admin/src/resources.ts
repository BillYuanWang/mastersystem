import type { JsonObject, ResourceName } from "./contracts.js";

export type DeleteStrategy =
  | { kind: "none" }
  | { kind: "direct" }
  | { kind: "managed"; recordKind: string }
  | { kind: "guardian_household" }
  | { kind: "media"; bucket: string; pathFields: string[] }
  | { kind: "news_article" };

export interface ResourceSpec {
  table: string;
  label: string;
  readFields: readonly string[];
  createFields: readonly string[];
  updateFields: readonly string[];
  requiredCreate: readonly string[];
  searchFields: readonly string[];
  defaultSort: readonly { field: string; ascending: boolean }[];
  organizationScoped: boolean;
  generateId: boolean;
  deleteStrategy: DeleteStrategy;
  createDefaults?: JsonObject;
  sensitiveFields?: readonly string[];
  notes?: string;
}

const lifecycle = ["id", "organization_id", "created_at", "updated_at"] as const;

export const resourceSpecs: Record<ResourceName, ResourceSpec> = {
  organizations: {
    table: "organizations",
    label: "学校资料",
    readFields: ["id", "name", "slug", "timezone", "created_at", "updated_at"],
    createFields: [],
    updateFields: ["name", "slug", "timezone"],
    requiredCreate: [],
    searchFields: ["name", "slug"],
    defaultSort: [{ field: "name", ascending: true }],
    organizationScoped: false,
    generateId: false,
    deleteStrategy: { kind: "none" }
  },
  profiles: {
    table: "profiles",
    label: "帐号权限",
    readFields: ["user_id", "organization_id", "role", "display_name", "appearance", "is_active", "created_at", "updated_at"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["display_name"],
    defaultSort: [{ field: "display_name", ascending: true }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" },
    notes: "Use update_profile_access for supported authorization changes."
  },
  terms: {
    table: "terms",
    label: "学期",
    readFields: [...lifecycle, "name", "starts_on", "ends_on", "status"],
    createFields: ["id", "name", "starts_on", "ends_on", "status"],
    updateFields: ["name", "starts_on", "ends_on", "status"],
    requiredCreate: ["name", "starts_on", "ends_on"],
    searchFields: ["name"],
    defaultSort: [{ field: "starts_on", ascending: false }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "managed", recordKind: "term" },
    createDefaults: { status: "draft" }
  },
  term_holidays: {
    table: "term_holidays",
    label: "假期",
    readFields: [...lifecycle, "term_id", "name", "starts_on", "ends_on", "notes"],
    createFields: ["id", "term_id", "name", "starts_on", "ends_on", "notes"],
    updateFields: ["term_id", "name", "starts_on", "ends_on", "notes"],
    requiredCreate: ["term_id", "name", "starts_on", "ends_on"],
    searchFields: ["name", "notes"],
    defaultSort: [{ field: "starts_on", ascending: true }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "managed", recordKind: "term_holiday" }
  },
  course_types: {
    table: "course_types",
    label: "课程种类",
    readFields: [...lifecycle, "name", "is_private", "notes", "is_active"],
    createFields: ["id", "name", "is_private", "notes", "is_active"],
    updateFields: ["name", "is_private", "notes", "is_active"],
    requiredCreate: ["name", "is_private"],
    searchFields: ["name", "notes"],
    defaultSort: [{ field: "name", ascending: true }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "managed", recordKind: "course_type" },
    createDefaults: { is_active: true }
  },
  age_groups: {
    table: "age_groups",
    label: "年龄段",
    readFields: [...lifecycle, "name", "notes", "is_active"],
    createFields: ["id", "name", "notes", "is_active"],
    updateFields: ["name", "notes", "is_active"],
    requiredCreate: ["name"],
    searchFields: ["name", "notes"],
    defaultSort: [{ field: "name", ascending: true }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "managed", recordKind: "age_group" },
    createDefaults: { is_active: true }
  },
  rooms: {
    table: "rooms",
    label: "教室",
    readFields: [...lifecycle, "name", "is_active"],
    createFields: ["id", "name", "is_active"],
    updateFields: ["name", "is_active"],
    requiredCreate: ["name"],
    searchFields: ["name"],
    defaultSort: [{ field: "name", ascending: true }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "managed", recordKind: "room" },
    createDefaults: { is_active: true }
  },
  instructors: {
    table: "instructors",
    label: "老师",
    readFields: [...lifecycle, "display_name", "notes", "is_active"],
    createFields: ["id", "display_name", "notes", "is_active"],
    updateFields: ["display_name", "notes", "is_active"],
    requiredCreate: ["display_name"],
    searchFields: ["display_name", "notes"],
    defaultSort: [{ field: "display_name", ascending: true }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "managed", recordKind: "instructor" },
    createDefaults: { is_active: true }
  },
  courses: {
    table: "courses",
    label: "课程",
    readFields: [...lifecycle, "term_id", "name", "age_group_id", "default_room_id", "default_instructor_id", "course_type_id", "format", "pricing_status", "unit_price_cents", "drop_in_unit_price_cents", "notes", "is_active"],
    createFields: ["id", "term_id", "name", "age_group_id", "default_room_id", "default_instructor_id", "course_type_id", "format", "pricing_status", "unit_price_cents", "drop_in_unit_price_cents", "notes", "is_active"],
    updateFields: ["term_id", "name", "age_group_id", "default_room_id", "default_instructor_id", "course_type_id", "format", "pricing_status", "unit_price_cents", "drop_in_unit_price_cents", "notes", "is_active"],
    requiredCreate: ["term_id", "name", "age_group_id", "default_room_id", "default_instructor_id", "course_type_id", "format"],
    searchFields: ["name", "notes"],
    defaultSort: [{ field: "name", ascending: true }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "managed", recordKind: "course" },
    createDefaults: { pricing_status: "pending", unit_price_cents: null, drop_in_unit_price_cents: null, is_active: true },
    notes: "The hidden legacy category is supplied internally and is never exposed to callers."
  },
  class_sessions: {
    table: "class_sessions",
    label: "课次",
    readFields: [...lifecycle, "course_id", "starts_at", "ends_at", "instructor_override_id", "room_override_id", "effective_instructor_id", "effective_room_id", "status"],
    createFields: ["id", "course_id", "starts_at", "ends_at", "instructor_override_id", "room_override_id", "status"],
    updateFields: ["starts_at", "ends_at", "instructor_override_id", "room_override_id", "status"],
    requiredCreate: ["course_id", "starts_at", "ends_at"],
    searchFields: [],
    defaultSort: [{ field: "starts_at", ascending: true }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "direct" },
    createDefaults: { status: "scheduled" }
  },
  guardians: {
    table: "guardians",
    label: "监护人",
    readFields: [...lifecycle, "profile_user_id", "display_name", "email", "secondary_email", "phone", "address"],
    createFields: ["id", "display_name", "email", "secondary_email", "phone", "address"],
    updateFields: ["display_name", "email", "secondary_email", "phone", "address"],
    requiredCreate: ["display_name", "email", "phone"],
    searchFields: ["display_name", "email", "secondary_email", "phone"],
    defaultSort: [{ field: "display_name", ascending: true }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "guardian_household" },
    sensitiveFields: ["email", "secondary_email", "phone", "address"],
    notes: "Email and phone are normally required. Before an account is linked, an explicit Admin-only incomplete-contact override may temporarily leave either value null; invitation codes remain blocked until both are valid."
  },
  students: {
    table: "students",
    label: "学员档案",
    readFields: [...lifecycle, "guardian_id", "profile_user_id", "display_name", "legal_name", "birth_date", "kind", "is_active"],
    createFields: ["guardian_id", "display_name", "legal_name", "birth_date", "kind"],
    updateFields: ["display_name", "legal_name", "birth_date", "kind", "is_active"],
    requiredCreate: ["guardian_id", "display_name", "kind"],
    searchFields: ["display_name", "legal_name"],
    defaultSort: [{ field: "display_name", ascending: true }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "managed", recordKind: "student" },
    sensitiveFields: ["legal_name", "birth_date"],
    notes: "Creation is routed through create_student_for_guardian to keep family links atomic."
  },
  guardian_students: {
    table: "guardian_students",
    label: "监护人学员关联",
    readFields: ["organization_id", "guardian_id", "student_id", "relationship_label", "is_primary", "created_at"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: [],
    defaultSort: [{ field: "created_at", ascending: true }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" }
  },
  enrollments: {
    table: "enrollments",
    label: "报名",
    readFields: [...lifecycle, "term_id", "course_id", "student_id", "enrolled_at", "status", "registration_mode", "pricing_status", "billing_starts_on", "unit_price_cents", "trial_fee_cents", "discount_name", "discount_kind", "discount_value", "billing_notes"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["billing_notes", "discount_name"],
    defaultSort: [{ field: "enrolled_at", ascending: false }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "direct" },
    notes: "Use save_enrollment for create and update so per-session selections stay atomic."
  },
  enrollment_session_selections: {
    table: "enrollment_session_selections",
    label: "按次报名课次",
    readFields: ["organization_id", "enrollment_id", "session_id", "created_at"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: [],
    defaultSort: [{ field: "created_at", ascending: true }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" }
  },
  attendance: {
    table: "attendance",
    label: "签到",
    readFields: [...lifecycle, "session_id", "student_id", "enrollment_id", "makeup_for_session_id", "status", "recorded_at", "recorded_by", "note"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["note"],
    defaultSort: [{ field: "recorded_at", ascending: false }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "direct" },
    notes: "Use set_attendance and clear_attendance."
  },
  leave_requests: {
    table: "leave_requests",
    label: "请假",
    readFields: [...lifecycle, "session_id", "student_id", "enrollment_id", "source", "status", "submitted_at", "submitted_by", "resolved_at", "resolved_by", "note"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["note"],
    defaultSort: [{ field: "submitted_at", ascending: false }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "direct" },
    notes: "Use save_leave_request for create and update."
  },
  contract_documents: {
    table: "contract_documents",
    label: "合同版本",
    readFields: [...lifecycle, "term_id", "version", "title", "body_text", "storage_path", "status", "published_at", "created_by"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["title", "version", "body_text"],
    defaultSort: [{ field: "published_at", ascending: false }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" },
    notes: "Published legal revisions are immutable. Use publish_contract_revision."
  },
  contract_consents: {
    table: "contract_consents",
    label: "合同签署记录",
    readFields: [...lifecycle, "contract_document_id", "term_id", "enrollment_id", "scope", "signer_user_id", "signer_kind", "signer_display_name", "consented_at"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["signer_display_name"],
    defaultSort: [{ field: "consented_at", ascending: false }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" }
  },
  contract_consent_signatures: {
    table: "contract_consent_signatures",
    label: "合同签名图",
    readFields: ["id", "organization_id", "contract_consent_id", "storage_path", "mime_type", "pixel_width", "pixel_height", "byte_count", "source", "created_at"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: [],
    defaultSort: [{ field: "created_at", ascending: false }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" }
  },
  news_articles: {
    table: "news_articles",
    label: "新闻",
    readFields: [...lifecycle, "title", "summary", "body_text", "author_name", "status", "published_at", "created_by"],
    createFields: ["id", "title", "summary", "body_text", "author_name", "status", "published_at"],
    updateFields: ["title", "summary", "body_text", "author_name", "status", "published_at"],
    requiredCreate: ["title", "body_text", "author_name"],
    searchFields: ["title", "summary", "body_text", "author_name"],
    defaultSort: [{ field: "created_at", ascending: false }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "news_article" },
    createDefaults: { summary: "", status: "draft", published_at: null }
  },
  news_article_images: {
    table: "news_article_images",
    label: "新闻图片",
    readFields: [...lifecycle, "article_id", "kind", "storage_path", "mime_type", "caption", "sort_order", "placement_after_paragraph"],
    createFields: ["id", "article_id", "kind", "storage_path", "mime_type", "caption", "sort_order", "placement_after_paragraph"],
    updateFields: ["kind", "storage_path", "mime_type", "caption", "sort_order", "placement_after_paragraph"],
    requiredCreate: ["article_id", "kind", "storage_path", "mime_type"],
    searchFields: ["caption"],
    defaultSort: [{ field: "sort_order", ascending: true }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "media", bucket: "news-media", pathFields: ["storage_path"] },
    createDefaults: { sort_order: 0, placement_after_paragraph: null }
  },
  advertisements: {
    table: "advertisements",
    label: "广告",
    readFields: [...lifecycle, "slot_number", "advertiser_name", "copy_text", "starts_on", "ends_on", "monthly_rate_cents", "status", "thumbnail_storage_path", "thumbnail_mime_type", "thumbnail_width", "thumbnail_height", "thumbnail_byte_count", "poster_storage_path", "poster_mime_type", "poster_width", "poster_height", "poster_byte_count", "created_by"],
    createFields: ["id", "slot_number", "advertiser_name", "copy_text", "starts_on", "ends_on", "monthly_rate_cents", "status", "thumbnail_storage_path", "thumbnail_mime_type", "thumbnail_width", "thumbnail_height", "thumbnail_byte_count", "poster_storage_path", "poster_mime_type", "poster_width", "poster_height", "poster_byte_count"],
    updateFields: ["slot_number", "advertiser_name", "copy_text", "starts_on", "ends_on", "monthly_rate_cents", "status", "thumbnail_storage_path", "thumbnail_mime_type", "thumbnail_width", "thumbnail_height", "thumbnail_byte_count", "poster_storage_path", "poster_mime_type", "poster_width", "poster_height", "poster_byte_count"],
    requiredCreate: ["slot_number", "advertiser_name", "copy_text", "starts_on", "ends_on"],
    searchFields: ["advertiser_name", "copy_text"],
    defaultSort: [{ field: "slot_number", ascending: true }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "media", bucket: "advertisement-media", pathFields: ["thumbnail_storage_path", "poster_storage_path"] },
    createDefaults: { monthly_rate_cents: 9900, status: "draft" }
  },
  notifications: {
    table: "notifications",
    label: "通知",
    readFields: [...lifecycle, "recipient_user_id", "kind", "channel", "title", "body", "scheduled_at", "sent_at", "status", "read_at"],
    createFields: ["id", "recipient_user_id", "kind", "channel", "title", "body", "scheduled_at", "sent_at", "status", "read_at"],
    updateFields: ["title", "body", "scheduled_at", "sent_at", "status", "read_at"],
    requiredCreate: ["recipient_user_id", "kind", "channel", "title", "body"],
    searchFields: ["title", "body"],
    defaultSort: [{ field: "created_at", ascending: false }],
    organizationScoped: true,
    generateId: true,
    deleteStrategy: { kind: "direct" },
    createDefaults: { status: "pending" }
  },
  billing_invoices: {
    table: "billing_invoices",
    label: "账单",
    readFields: ["id", "organization_id", "created_at", "guardian_id", "term_id", "learner_ids", "invoice_number", "version", "school_year_label", "issued_at", "currency", "amount_due_cents", "notes", "supersedes_invoice_id", "superseded_by_invoice_id", "created_by"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["invoice_number", "school_year_label", "notes"],
    defaultSort: [{ field: "issued_at", ascending: false }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" },
    notes: "Issued invoices are immutable. Use issue_invoice to create the next version."
  },
  billing_invoice_items: {
    table: "billing_invoice_items",
    label: "账单明细",
    readFields: ["id", "organization_id", "created_at", "invoice_id", "student_id", "enrollment_id", "kind", "title", "detail", "quantity", "unit_amount_cents", "amount_cents", "included_in_amount_due", "sort_order"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["title", "detail"],
    defaultSort: [{ field: "sort_order", ascending: true }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" }
  },
  billing_payments: {
    table: "billing_payments",
    label: "付款记录",
    readFields: ["id", "organization_id", "created_at", "invoice_id", "amount_cents", "processing_fee_cents", "method", "received_at", "note", "recorded_by"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["note"],
    defaultSort: [{ field: "received_at", ascending: false }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" },
    notes: "Recorded payments are immutable. Use record_payment."
  },
  billing_artifacts: {
    table: "billing_artifacts",
    label: "账单与收据文件",
    readFields: ["id", "organization_id", "invoice_id", "payment_id", "kind", "storage_path", "mime_type", "generated_by", "generated_at"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["storage_path"],
    defaultSort: [{ field: "generated_at", ascending: false }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" }
  },
  audit_events: {
    table: "audit_events",
    label: "审计日志",
    readFields: ["id", "organization_id", "table_name", "record_key", "action", "actor_user_id", "transaction_id", "occurred_at"],
    createFields: [],
    updateFields: [],
    requiredCreate: [],
    searchFields: ["table_name", "record_key", "action"],
    defaultSort: [{ field: "occurred_at", ascending: false }],
    organizationScoped: true,
    generateId: false,
    deleteStrategy: { kind: "none" }
  }
};

export function resourceSpec(name: ResourceName): ResourceSpec {
  return resourceSpecs[name];
}
