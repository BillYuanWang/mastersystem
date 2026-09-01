export type JsonPrimitive = string | number | boolean | null;
export type JsonValue = JsonPrimitive | JsonObject | JsonValue[];
export type JsonObject = { [key: string]: JsonValue };

export const resourceNames = [
  "organizations",
  "profiles",
  "terms",
  "term_holidays",
  "course_types",
  "age_groups",
  "rooms",
  "instructors",
  "courses",
  "class_sessions",
  "guardians",
  "students",
  "guardian_students",
  "enrollments",
  "enrollment_session_selections",
  "attendance",
  "leave_requests",
  "contract_documents",
  "contract_consents",
  "contract_consent_signatures",
  "news_articles",
  "news_article_images",
  "advertisements",
  "notifications",
  "billing_invoices",
  "billing_invoice_items",
  "billing_payments",
  "billing_artifacts",
  "audit_events"
] as const;

export type ResourceName = (typeof resourceNames)[number];

export const actionNames = [
  "set_course_pricing",
  "save_enrollment",
  "set_attendance",
  "clear_attendance",
  "save_leave_request",
  "create_student_for_guardian",
  "link_student_to_guardian",
  "issue_guardian_link_code",
  "publish_contract_revision",
  "update_profile_access",
  "upload_media",
  "remove_media",
  "issue_invoice",
  "record_payment"
] as const;

export type ActionName = (typeof actionNames)[number];

export const filterOperators = [
  "eq",
  "neq",
  "gt",
  "gte",
  "lt",
  "lte",
  "like",
  "ilike",
  "is",
  "in"
] as const;

export type FilterOperator = (typeof filterOperators)[number];

export interface RecordFilter {
  field: string;
  operator?: FilterOperator;
  value: JsonValue;
}

export interface SortRule {
  field: string;
  ascending?: boolean;
}

export interface ListRecordsOptions {
  filters?: RecordFilter[];
  sort?: SortRule[];
  limit?: number;
  offset?: number;
  search?: string;
}

export interface RecordMutationOptions {
  allowIncompleteGuardianContact?: boolean;
}

export interface AdminIdentity {
  userId: string;
  organizationId: string;
  displayName: string;
  role: "administrator";
}

export interface AdminResult<T extends JsonValue = JsonValue> {
  ok: true;
  result: T;
  warnings: string[];
}

export interface AdminErrorBody {
  ok: false;
  error: {
    code: string;
    message: string;
    details?: JsonValue;
  };
}

export interface CoursePricingInput {
  course_id: string;
  pricing_status: "pending" | "priced" | "free" | "review_required";
  full_term_unit_price_cents?: number | null;
  per_session_unit_price_cents?: number | null;
}

export interface SaveEnrollmentInput {
  id?: string;
  term_id: string;
  course_id: string;
  student_id: string;
  enrolled_at?: string;
  status?: "active" | "withdrawn" | "completed";
  registration_mode?: "full_term" | "per_session";
  pricing_status?: "pending" | "ready" | "review_required";
  billing_starts_on?: string | null;
  unit_price_cents?: number | null;
  trial_fee_cents?: number;
  discount_name?: string | null;
  discount_kind?: "percentage" | "fixed_amount" | null;
  discount_value?: number | null;
  billing_notes?: string | null;
  selected_session_ids?: string[];
}

export interface SetAttendanceInput {
  id?: string;
  session_id: string;
  student_id: string;
  enrollment_id?: string | null;
  makeup_for_session_id?: string | null;
  status: "present" | "absent" | "excused" | "makeup" | "trial";
  recorded_at?: string;
  note?: string | null;
}

export interface SaveLeaveRequestInput {
  id?: string;
  session_id: string;
  student_id: string;
  enrollment_id?: string | null;
  submitted_at?: string;
  note?: string | null;
}

export interface BillingLineItemInput {
  id?: string;
  student_id?: string | null;
  enrollment_id?: string | null;
  kind: "tuition" | "trial" | "registration" | "discount" | "balance_credit" | "prior_balance" | "manual";
  title: string;
  detail?: string | null;
  quantity: number;
  unit_amount_cents: number;
  amount_cents: number;
  paid: boolean;
  sort_order?: number;
}

export interface IssueInvoiceInput {
  invoice_id?: string;
  guardian_id: string;
  term_id: string;
  learner_ids: string[];
  invoice_number: string;
  version: number;
  school_year_label: string;
  issued_at?: string;
  notes?: string | null;
  supersedes_invoice_id?: string | null;
  bilingual_png_path: string;
  english_png_path: string;
  items: BillingLineItemInput[];
}

export interface RecordPaymentInput {
  payment_id?: string;
  invoice_id: string;
  amount_cents: number;
  processing_fee_cents?: number;
  method: "cash" | "check" | "zelle" | "card";
  received_at?: string;
  note?: string | null;
  bilingual_png_path: string;
  english_png_path: string;
}
