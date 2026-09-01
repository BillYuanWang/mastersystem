import test from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

test("MCP server initializes and exposes focused tools", async () => {
  const serverPath = fileURLToPath(new URL("../mcp/server.js", import.meta.url));
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [serverPath],
    stderr: "pipe"
  });
  const client = new Client({ name: "master-dance-mcp-test", version: "0.1.0" });
  try {
    await client.connect(transport);
    const listed = await client.listTools();
    const names = listed.tools.map((tool) => tool.name);
    assert.ok(names.includes("md_list_records"));
    assert.ok(names.includes("md_set_course_pricing"));
    assert.ok(names.includes("md_issue_invoice"));
    assert.ok(names.includes("md_record_payment"));
    assert.ok(names.length >= 20);
    const createTool = listed.tools.find((tool) => tool.name === "md_create_record");
    assert.ok(createTool);
    assert.ok(
      "allow_incomplete_guardian_contact" in
        ((createTool.inputSchema.properties ?? {}) as Record<string, unknown>)
    );
  } finally {
    await client.close();
  }
});
