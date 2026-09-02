import type { JsonValue } from "./contracts.js";

export class AdminIntegrationError extends Error {
  readonly code: string;
  readonly details?: JsonValue;
  readonly status?: number;

  constructor(
    code: string,
    message: string,
    options: { details?: JsonValue; status?: number; cause?: unknown } = {}
  ) {
    super(message, { cause: options.cause });
    this.name = "AdminIntegrationError";
    this.code = code;
    if (options.details !== undefined) this.details = options.details;
    if (options.status !== undefined) this.status = options.status;
  }
}

export function errorBody(error: unknown): {
  ok: false;
  error: { code: string; message: string; details?: JsonValue };
} {
  if (error instanceof AdminIntegrationError) {
    const body: { code: string; message: string; details?: JsonValue } = {
      code: error.code,
      message: error.message
    };
    if (error.details !== undefined) body.details = error.details;
    return { ok: false, error: body };
  }
  return {
    ok: false,
    error: {
      code: "unexpected_error",
      message: error instanceof Error ? error.message : "Unexpected error"
    }
  };
}
