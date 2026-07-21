import { withSupabase } from "npm:@supabase/server@1.4.0";

type ContractManifest = {
  id: string;
  title: string;
  version: string;
  body_text: string;
  content_sha256: string;
};

type Database = {
  public: {
    Tables: Record<string, never>;
    Views: Record<string, never>;
    Functions: {
      guardian_registration_contract_manifest: {
        Args: {
          claim_code: string;
          target_document_id: string;
        };
        Returns: ContractManifest;
      };
      record_guardian_registration_agreement_acceptance: {
        Args: {
          claim_code: string;
          target_document_id: string;
          signature_base64: string;
          contract_sha256: string;
        };
        Returns: {
          contract_document_id: string;
          accepted_at: string;
        };
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};

type RequestBody = {
  action?: unknown;
  invitationCode?: unknown;
  contractDocumentId?: unknown;
  displayedContractSha256?: unknown;
  signatureBase64?: unknown;
};

const noStoreHeaders = {
  "Cache-Control": "no-store, private, max-age=0",
  "Pragma": "no-cache",
};

function jsonError(message: string, status: number): Response {
  return Response.json(
    { error: message },
    { status, headers: noStoreHeaders },
  );
}

function normalizeInvitationCode(value: unknown): string {
  return typeof value === "string"
    ? value.toUpperCase().replaceAll(/[^A-Z0-9]/g, "")
    : "";
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function validPNGSignature(value: unknown): value is string {
  if (
    typeof value !== "string" || value.length < 172 || value.length > 700000
  ) {
    return false;
  }
  try {
    const bytes = Uint8Array.from(
      atob(value),
      (character) => character.charCodeAt(0),
    );
    const pngHeader = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    return bytes.length >= 128 && bytes.length <= 524288 &&
      pngHeader.every((byte, index) => bytes[index] === byte);
  } catch {
    return false;
  }
}

export default {
  fetch: withSupabase<Database>({ auth: "none" }, async (request, context) => {
    if (request.method !== "POST") {
      return jsonError("Method not allowed", 405);
    }

    let body: RequestBody;
    try {
      body = await request.json();
    } catch {
      return jsonError("A JSON body is required", 400);
    }

    const action = typeof body.action === "string" ? body.action : "";
    const invitationCode = normalizeInvitationCode(body.invitationCode);
    const contractDocumentId = typeof body.contractDocumentId === "string"
      ? body.contractDocumentId
      : "";

    if (!/^MD[0-9A-F]{20}$/.test(invitationCode)) {
      return jsonError("Invalid or expired guardian link code", 400);
    }
    if (!isUUID(contractDocumentId)) {
      return jsonError("A valid contract document is required", 400);
    }

    const { data: manifest, error: manifestError } = await context.supabaseAdmin
      .rpc("guardian_registration_contract_manifest", {
        claim_code: invitationCode,
        target_document_id: contractDocumentId,
      });

    if (
      manifestError || !manifest?.body_text ||
      !/^[0-9a-f]{64}$/.test(manifest?.content_sha256 ?? "")
    ) {
      const changed = manifestError?.message?.includes(
        "Registration contract changed",
      );
      return jsonError(
        changed
          ? "合同已更新，请重新验证邀请码并阅读新合同。"
          : "邀请码无效、已过期，或注册合同暂不可用。",
        changed ? 409 : 400,
      );
    }

    const contractHash = manifest.content_sha256;

    if (action === "download") {
      return Response.json(
        {
          agreement: {
            id: manifest.id,
            title: manifest.title,
            version: manifest.version,
            bodyText: manifest.body_text,
            sha256: contractHash,
          },
        },
        { status: 200, headers: noStoreHeaders },
      );
    }

    if (action !== "accept") {
      return jsonError("Unsupported action", 400);
    }

    const displayedHash = typeof body.displayedContractSha256 === "string"
      ? body.displayedContractSha256.trim().toLowerCase()
      : "";
    if (displayedHash !== contractHash) {
      return jsonError("合同已更新，请重新阅读后签名。", 409);
    }
    if (!validPNGSignature(body.signatureBase64)) {
      return jsonError("请提供有效的手写签名。", 400);
    }

    const { data: acceptance, error: acceptanceError } = await context
      .supabaseAdmin.rpc("record_guardian_registration_agreement_acceptance", {
        claim_code: invitationCode,
        target_document_id: contractDocumentId,
        signature_base64: body.signatureBase64,
        contract_sha256: contractHash,
      });

    if (acceptanceError || !acceptance) {
      return jsonError(
        acceptanceError?.message?.includes("Registration contract changed")
          ? "合同已更新，请重新阅读后签名。"
          : "签名暂时无法保存，请稍后重试。",
        acceptanceError?.message?.includes("Registration contract changed")
          ? 409
          : 422,
      );
    }

    return Response.json(
      { acceptance },
      { status: 201, headers: noStoreHeaders },
    );
  }),
};
