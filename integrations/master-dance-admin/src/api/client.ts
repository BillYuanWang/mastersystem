import type {
  ActionName,
  AdminResult,
  JsonObject,
  JsonValue,
  ListRecordsOptions,
  RecordMutationOptions,
  ResourceName
} from "../contracts.js";
import { AdminIntegrationError } from "../errors.js";

export interface MasterDanceAdminApiClientOptions {
  baseUrl?: string;
  token: string;
}

export class MasterDanceAdminApiClient {
  readonly baseUrl: string;
  private readonly token: string;

  constructor(options: MasterDanceAdminApiClientOptions) {
    this.baseUrl = (options.baseUrl ?? "http://127.0.0.1:4688").replace(/\/$/, "");
    this.token = options.token;
  }

  capabilities(): Promise<AdminResult<JsonValue>> {
    return this.request("GET", "/v1/capabilities");
  }

  list(resource: ResourceName, options: ListRecordsOptions = {}): Promise<AdminResult<JsonValue>> {
    const query = new URLSearchParams();
    if (options.filters) query.set("filters", JSON.stringify(options.filters));
    if (options.sort) query.set("sort", JSON.stringify(options.sort));
    if (options.limit !== undefined) query.set("limit", String(options.limit));
    if (options.offset !== undefined) query.set("offset", String(options.offset));
    if (options.search) query.set("search", options.search);
    const suffix = query.size ? `?${query}` : "";
    return this.request("GET", `/v1/resources/${resource}${suffix}`);
  }

  get(resource: ResourceName, id: string): Promise<AdminResult<JsonValue>> {
    return this.request("GET", `/v1/resources/${resource}/${encodeURIComponent(id)}`);
  }

  create(
    resource: ResourceName,
    values: JsonObject,
    options: RecordMutationOptions = {}
  ): Promise<AdminResult<JsonValue>> {
    return this.request("POST", this.mutationPath(`/v1/resources/${resource}`, options), values);
  }

  update(
    resource: ResourceName,
    id: string,
    changes: JsonObject,
    options: RecordMutationOptions = {}
  ): Promise<AdminResult<JsonValue>> {
    return this.request(
      "PATCH",
      this.mutationPath(`/v1/resources/${resource}/${encodeURIComponent(id)}`, options),
      changes
    );
  }

  delete(resource: ResourceName, id: string): Promise<AdminResult<JsonValue>> {
    return this.request("DELETE", `/v1/resources/${resource}/${encodeURIComponent(id)}`);
  }

  action(name: ActionName, input: JsonObject): Promise<AdminResult<JsonValue>> {
    return this.request("POST", `/v1/actions/${name}`, input);
  }

  private mutationPath(path: string, options: RecordMutationOptions): string {
    return options.allowIncompleteGuardianContact
      ? `${path}?allow_incomplete_guardian_contact=true`
      : path;
  }

  private async request(
    method: string,
    path: string,
    body?: JsonObject
  ): Promise<AdminResult<JsonValue>> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${this.token}`,
        Accept: "application/json",
        ...(body ? { "Content-Type": "application/json" } : {})
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(60_000)
    });
    const payload = await response.json() as AdminResult<JsonValue> | {
      ok: false;
      error: { code: string; message: string; details?: JsonValue };
    };
    if (!response.ok || !payload.ok) {
      const error = "error" in payload ? payload.error : undefined;
      throw new AdminIntegrationError(
        error?.code ?? `api_${response.status}`,
        error?.message ?? `Master Dance Admin API failed (${response.status}).`,
        { status: response.status, details: error?.details }
      );
    }
    return payload;
  }
}
