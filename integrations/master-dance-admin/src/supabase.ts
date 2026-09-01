import type { AdminIdentity, JsonObject, JsonValue } from "./contracts.js";
import type { AdminCredentialConfig } from "./credentials.js";
import { AdminIntegrationError } from "./errors.js";

interface AuthUser {
  id: string;
  email?: string;
}

interface AuthResponse {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
  user: AuthUser;
}

interface ProfileRow {
  user_id: string;
  organization_id: string;
  role: string;
  display_name: string;
  is_active: boolean;
}

export interface PostgrestRequestOptions {
  query?: URLSearchParams;
  body?: JsonValue;
  prefer?: string;
  headers?: Record<string, string>;
}

export class SupabaseAdminClient {
  readonly config: AdminCredentialConfig;
  private accessToken?: string;
  private refreshToken?: string;
  private expiresAt = 0;
  private user?: AuthUser;
  private identityValue?: AdminIdentity;

  constructor(config: AdminCredentialConfig) {
    this.config = config;
    if (config.accessToken) {
      this.accessToken = config.accessToken;
      this.expiresAt = Number.POSITIVE_INFINITY;
    }
  }

  async identity(): Promise<AdminIdentity> {
    if (this.identityValue) return this.identityValue;
    await this.ensureSession();

    const userId = this.user?.id ?? (await this.fetchCurrentUser()).id;
    const query = new URLSearchParams({
      select: "user_id,organization_id,role,display_name,is_active",
      user_id: `eq.${userId}`,
      limit: "1"
    });
    const profiles = await this.postgrest<ProfileRow[]>("GET", "profiles", { query });
    const profile = profiles[0];
    if (!profile || profile.role !== "administrator" || !profile.is_active) {
      throw new AdminIntegrationError(
        "administrator_required",
        "The configured account is not an active Master Dance administrator.",
        { status: 403 }
      );
    }
    this.identityValue = {
      userId: profile.user_id,
      organizationId: profile.organization_id,
      displayName: profile.display_name,
      role: "administrator"
    };
    return this.identityValue;
  }

  async postgrest<T>(
    method: "GET" | "POST" | "PATCH" | "DELETE",
    table: string,
    options: PostgrestRequestOptions = {}
  ): Promise<T> {
    const query = options.query?.toString();
    const suffix = query ? `?${query}` : "";
    return this.request<T>(method, `/rest/v1/${encodeURIComponent(table)}${suffix}`, options);
  }

  async rpc<T>(functionName: string, params: JsonObject): Promise<T> {
    return this.request<T>(
      "POST",
      `/rest/v1/rpc/${encodeURIComponent(functionName)}`,
      { body: params, prefer: "return=representation" }
    );
  }

  async uploadStorageObject(
    bucket: string,
    path: string,
    bytes: Uint8Array,
    mimeType: string,
    upsert = false
  ): Promise<JsonValue> {
    await this.ensureSession();
    const response = await fetch(
      `${this.config.supabaseUrl}/storage/v1/object/${encodeURIComponent(bucket)}/${encodeStoragePath(path)}`,
      {
        method: "POST",
        headers: {
          ...this.authHeaders(),
          "Content-Type": mimeType,
          "x-upsert": upsert ? "true" : "false"
        },
        body: Buffer.from(bytes) as unknown as BodyInit,
        signal: AbortSignal.timeout(60_000)
      }
    );
    return this.parseResponse(response);
  }

  async removeStorageObjects(bucket: string, paths: string[]): Promise<JsonValue> {
    if (paths.length === 0) return [];
    await this.ensureSession();
    const response = await fetch(
      `${this.config.supabaseUrl}/storage/v1/object/${encodeURIComponent(bucket)}`,
      {
        method: "DELETE",
        headers: {
          ...this.authHeaders(),
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ prefixes: paths }),
        signal: AbortSignal.timeout(30_000)
      }
    );
    return this.parseResponse(response);
  }

  private async request<T>(
    method: string,
    path: string,
    options: PostgrestRequestOptions = {}
  ): Promise<T> {
    await this.ensureSession();
    const headers: Record<string, string> = {
      ...this.authHeaders(),
      Accept: "application/json",
      ...options.headers
    };
    if (options.body !== undefined) headers["Content-Type"] = "application/json";
    if (options.prefer) headers.Prefer = options.prefer;

    const response = await fetch(`${this.config.supabaseUrl}${path}`, {
      method,
      headers,
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
      signal: AbortSignal.timeout(30_000)
    });
    return this.parseResponse(response) as Promise<T>;
  }

  private async ensureSession(): Promise<void> {
    if (this.accessToken && Date.now() < this.expiresAt - 30_000) return;

    if (this.refreshToken) {
      const refreshed = await this.authRequest("refresh_token", { refresh_token: this.refreshToken });
      this.acceptAuth(refreshed);
      return;
    }

    if (!this.config.email || !this.config.password) {
      throw new AdminIntegrationError(
        "credentials_missing",
        "Master Dance Admin credentials are missing. Run script/setup_master_dance_admin_credentials.sh or provide the documented environment variables."
      );
    }

    const signedIn = await this.authRequest("password", {
      email: this.config.email,
      password: this.config.password
    });
    this.acceptAuth(signedIn);
  }

  private async authRequest(grantType: string, body: JsonObject): Promise<AuthResponse> {
    const response = await fetch(
      `${this.config.supabaseUrl}/auth/v1/token?grant_type=${encodeURIComponent(grantType)}`,
      {
        method: "POST",
        headers: {
          apikey: this.config.publishableKey,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(30_000)
      }
    );
    return this.parseResponse(response) as unknown as Promise<AuthResponse>;
  }

  private acceptAuth(auth: AuthResponse): void {
    this.accessToken = auth.access_token;
    this.refreshToken = auth.refresh_token;
    this.expiresAt = Date.now() + Math.max(60, auth.expires_in ?? 3600) * 1000;
    this.user = auth.user;
  }

  private async fetchCurrentUser(): Promise<AuthUser> {
    await this.ensureSession();
    const response = await fetch(`${this.config.supabaseUrl}/auth/v1/user`, {
      headers: this.authHeaders(),
      signal: AbortSignal.timeout(30_000)
    });
    const user = await this.parseResponse(response) as unknown as AuthUser;
    this.user = user;
    return user;
  }

  private authHeaders(): Record<string, string> {
    if (!this.accessToken) {
      throw new AdminIntegrationError("session_missing", "Supabase session is unavailable.");
    }
    return {
      apikey: this.config.publishableKey,
      Authorization: `Bearer ${this.accessToken}`
    };
  }

  private async parseResponse(response: Response): Promise<JsonValue> {
    const text = await response.text();
    let body: JsonValue = null;
    if (text) {
      try {
        body = JSON.parse(text) as JsonValue;
      } catch {
        body = text;
      }
    }

    if (!response.ok) {
      const object = isJsonObject(body) ? body : undefined;
      const message = stringValue(object?.message)
        ?? stringValue(object?.error_description)
        ?? stringValue(object?.error)
        ?? `Supabase request failed (${response.status}).`;
      const code = stringValue(object?.code) ?? `supabase_${response.status}`;
      throw new AdminIntegrationError(code, message, {
        status: response.status,
        details: body
      });
    }

    return body;
  }
}

function encodeStoragePath(path: string): string {
  return path.split("/").map(encodeURIComponent).join("/");
}

function isJsonObject(value: JsonValue): value is JsonObject {
  return value !== null && !Array.isArray(value) && typeof value === "object";
}

function stringValue(value: JsonValue | undefined): string | undefined {
  return typeof value === "string" ? value : undefined;
}
