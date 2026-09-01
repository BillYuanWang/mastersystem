import { execFileSync } from "node:child_process";

export const DEFAULT_SUPABASE_URL = "https://szienrktsikxwdnrrudo.supabase.co";
export const DEFAULT_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_oOg7RYMXv83Ofwf2NjgrlA_EcCKFMab";

export const keychainServices = {
  email: "com.masterdance.admin.mcp.email",
  password: "com.masterdance.admin.mcp.password",
  apiToken: "com.masterdance.admin.api.token"
} as const;

export interface AdminCredentialConfig {
  supabaseUrl: string;
  publishableKey: string;
  email?: string;
  password?: string;
  accessToken?: string;
}

function keychainSecret(service: string): string | undefined {
  if (process.platform !== "darwin") {
    return undefined;
  }

  try {
    return execFileSync(
      "/usr/bin/security",
      ["find-generic-password", "-s", service, "-a", "default", "-w"],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }
    ).trim() || undefined;
  } catch {
    return undefined;
  }
}

export function resolveAdminCredentialConfig(
  environment: NodeJS.ProcessEnv = process.env
): AdminCredentialConfig {
  const email = environment.MASTER_DANCE_ADMIN_EMAIL ?? keychainSecret(keychainServices.email);
  const password = environment.MASTER_DANCE_ADMIN_PASSWORD ?? keychainSecret(keychainServices.password);
  const accessToken = environment.MASTER_DANCE_ACCESS_TOKEN;

  const config: AdminCredentialConfig = {
    supabaseUrl: environment.MASTER_DANCE_SUPABASE_URL ?? DEFAULT_SUPABASE_URL,
    publishableKey: environment.MASTER_DANCE_SUPABASE_PUBLISHABLE_KEY ?? DEFAULT_SUPABASE_PUBLISHABLE_KEY
  };

  if (email) config.email = email;
  if (password) config.password = password;
  if (accessToken) config.accessToken = accessToken;
  return config;
}

export function resolveLocalApiToken(
  environment: NodeJS.ProcessEnv = process.env
): string | undefined {
  return environment.MASTER_DANCE_LOCAL_API_TOKEN ?? keychainSecret(keychainServices.apiToken);
}
