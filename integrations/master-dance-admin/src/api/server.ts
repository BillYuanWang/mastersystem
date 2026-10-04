#!/usr/bin/env node
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { timingSafeEqual } from "node:crypto";
import type { ActionName, JsonObject, ListRecordsOptions, ResourceName } from "../contracts.js";
import { actionNames, resourceNames } from "../contracts.js";
import { resolveLocalApiToken } from "../credentials.js";
import { AdminIntegrationError, errorBody } from "../errors.js";
import { createMasterDanceAdminSDK } from "../factory.js";

const host = process.env.MASTER_DANCE_ADMIN_API_HOST ?? "127.0.0.1";
const port = parsePort(process.env.MASTER_DANCE_ADMIN_API_PORT ?? "4688");
const token = resolveLocalApiToken();

if (!token || token.length < 32) {
  process.stderr.write(
    "Master Dance Admin API token is missing. Run script/setup_master_dance_admin_credentials.sh first.\n"
  );
  process.exit(1);
}

const sdk = createMasterDanceAdminSDK();

const server = createServer(async (request, response) => {
  try {
    await route(request, response);
  } catch (error) {
    const status = error instanceof AdminIntegrationError ? (error.status ?? 400) : 500;
    sendJSON(response, status, errorBody(error));
  }
});

server.listen(port, host, () => {
  process.stderr.write(`Master Dance Admin API listening on http://${host}:${port}\n`);
});

async function route(request: IncomingMessage, response: ServerResponse): Promise<void> {
  const method = request.method ?? "GET";
  const url = new URL(request.url ?? "/", `http://${host}:${port}`);

  if (method === "GET" && url.pathname === "/health") {
    sendJSON(response, 200, { ok: true, service: "master-dance-admin-api", version: "0.1.0" });
    return;
  }
  authorize(request);

  if (method === "GET" && url.pathname === "/v1/capabilities") {
    sendJSON(response, 200, await sdk.capabilities());
    return;
  }

  const segments = url.pathname.split("/").filter(Boolean);
  if (segments[0] === "v1" && segments[1] === "resources") {
    const resource = parseResource(segments[2]);
    const id = segments[3];
    if (method === "GET" && !id) {
      sendJSON(response, 200, await sdk.listRecords(resource, parseListOptions(url)));
      return;
    }
    if (method === "GET" && id) {
      sendJSON(response, 200, await sdk.getRecord(resource, decodeURIComponent(id)));
      return;
    }
    if (method === "POST" && !id) {
      sendJSON(response, 201, await sdk.createRecord(
        resource,
        await readObject(request),
        parseMutationOptions(url)
      ));
      return;
    }
    if (method === "PATCH" && id) {
      sendJSON(response, 200, await sdk.updateRecord(
        resource,
        decodeURIComponent(id),
        await readObject(request),
        parseMutationOptions(url)
      ));
      return;
    }
    if (method === "DELETE" && id) {
      sendJSON(response, 200, await sdk.deleteRecord(resource, decodeURIComponent(id)));
      return;
    }
  }

  if (segments[0] === "v1" && segments[1] === "actions" && segments[2] && method === "POST") {
    const action = parseAction(segments[2]);
    sendJSON(response, 200, await sdk.runAction(action, await readObject(request)));
    return;
  }

  throw new AdminIntegrationError("not_found", "API route was not found.", { status: 404 });
}

function authorize(request: IncomingMessage): void {
  const supplied = request.headers.authorization?.replace(/^Bearer\s+/i, "") ?? "";
  const expectedBytes = Buffer.from(token!);
  const suppliedBytes = Buffer.from(supplied);
  if (expectedBytes.length !== suppliedBytes.length || !timingSafeEqual(expectedBytes, suppliedBytes)) {
    throw new AdminIntegrationError("unauthorized", "A valid local API bearer token is required.", { status: 401 });
  }
}

function parseListOptions(url: URL): ListRecordsOptions {
  const result: ListRecordsOptions = {};
  const filters = parseJSONParameter(url, "filters");
  const sort = parseJSONParameter(url, "sort");
  if (filters !== undefined) result.filters = filters as ListRecordsOptions["filters"];
  if (sort !== undefined) result.sort = sort as ListRecordsOptions["sort"];
  if (url.searchParams.has("limit")) result.limit = Number(url.searchParams.get("limit"));
  if (url.searchParams.has("offset")) result.offset = Number(url.searchParams.get("offset"));
  const search = url.searchParams.get("search");
  if (search) result.search = search;
  return result;
}

function parseJSONParameter(url: URL, name: string): unknown {
  const value = url.searchParams.get(name);
  if (!value) return undefined;
  try {
    return JSON.parse(value);
  } catch {
    throw new AdminIntegrationError("invalid_query", `${name} must contain valid JSON.`);
  }
}

function parseMutationOptions(url: URL): { allowIncompleteGuardianContact: boolean } {
  const raw = url.searchParams.get("allow_incomplete_guardian_contact");
  if (raw !== null && raw !== "true" && raw !== "false") {
    throw new AdminIntegrationError(
      "invalid_query",
      "allow_incomplete_guardian_contact must be true or false."
    );
  }
  return { allowIncompleteGuardianContact: raw === "true" };
}

async function readObject(request: IncomingMessage): Promise<JsonObject> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buffer.length;
    if (size > 2 * 1024 * 1024) {
      throw new AdminIntegrationError("request_too_large", "JSON request body exceeds 2 MB.", { status: 413 });
    }
    chunks.push(buffer);
  }
  try {
    const value = JSON.parse(Buffer.concat(chunks).toString("utf8")) as unknown;
    if (value === null || Array.isArray(value) || typeof value !== "object") throw new Error("object required");
    return value as JsonObject;
  } catch {
    throw new AdminIntegrationError("invalid_json", "Request body must be a JSON object.");
  }
}

function parseResource(value: string | undefined): ResourceName {
  if (!value || !resourceNames.includes(value as ResourceName)) {
    throw new AdminIntegrationError("unknown_resource", "Unknown Master Dance resource.");
  }
  return value as ResourceName;
}

function parseAction(value: string): ActionName {
  if (!actionNames.includes(value as ActionName)) {
    throw new AdminIntegrationError("unknown_action", "Unknown Master Dance action.");
  }
  return value as ActionName;
}

function sendJSON(response: ServerResponse, status: number, body: unknown): void {
  response.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff"
  });
  response.end(JSON.stringify(body));
}

function parsePort(value: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1024 || parsed > 65535) {
    throw new Error("MASTER_DANCE_ADMIN_API_PORT must be between 1024 and 65535.");
  }
  return parsed;
}
