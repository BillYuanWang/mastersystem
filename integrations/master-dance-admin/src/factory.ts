import { resolveAdminCredentialConfig } from "./credentials.js";
import { MasterDanceAdminSDK } from "./service.js";
import { SupabaseAdminClient } from "./supabase.js";

export function createMasterDanceAdminSDK(
  environment: NodeJS.ProcessEnv = process.env
): MasterDanceAdminSDK {
  return new MasterDanceAdminSDK(
    new SupabaseAdminClient(resolveAdminCredentialConfig(environment))
  );
}
