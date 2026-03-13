/**
 * Set up CloudKit schema indexes for the Event record type.
 * Tries multiple API endpoint formats to find the working one.
 *
 * Usage: npx tsx setup-schema.ts
 */
import { createSign, createHash } from "crypto";
import { readFile } from "fs/promises";

const CK_BASE = "https://api.apple-cloudkit.com";
const CONTAINER = process.env.CLOUDKIT_CONTAINER || "iCloud.com.parentguide.app";
const KEY_ID = process.env.CLOUDKIT_KEY_ID || "";
const ENV = process.env.CLOUDKIT_ENVIRONMENT || "development";
const KEY_PATH = process.env.CLOUDKIT_PRIVATE_KEY_PATH || "./cloudkit-key.pem";

async function getPrivateKey(): Promise<string> {
  if (process.env.CLOUDKIT_PRIVATE_KEY) return process.env.CLOUDKIT_PRIVATE_KEY;
  return await readFile(KEY_PATH, "utf-8");
}

function signRequest(date: string, body: string, subpath: string, pk: string): string {
  const bodyHash = createHash("sha256").update(body, "utf-8").digest("base64");
  const message = `${date}:${bodyHash}:${subpath}`;
  const sign = createSign("SHA256");
  sign.update(message);
  return sign.sign(pk, "base64");
}

async function cloudKitFetch(subpath: string, body: object | string, pk: string, method: string = "POST"): Promise<{ status: number; data: any }> {
  const url = `${CK_BASE}${subpath}`;
  const bodyStr = typeof body === "string" ? body : JSON.stringify(body);
  const date = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const signature = signRequest(date, bodyStr, subpath, pk);

  const resp = await fetch(url, {
    method,
    headers: {
      "Content-Type": "application/json",
      "X-Apple-CloudKit-Request-KeyID": KEY_ID,
      "X-Apple-CloudKit-Request-ISO8601Date": date,
      "X-Apple-CloudKit-Request-SignatureV1": signature,
    },
    body: bodyStr,
  });

  const text = await resp.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: resp.status, data };
}

async function main() {
  const pk = await getPrivateKey();

  // Try multiple possible schema endpoint formats
  const schemaEndpoints = [
    `/database/1/${CONTAINER}/${ENV}/schema`,
    `/database/1/${CONTAINER}/${ENV}/public/schema`,
    `/database/1/${CONTAINER}/${ENV}/schema/records/lookup`,
    `/database/1/${CONTAINER}/${ENV}/public/schema/records/lookup`,
    `/database/1/${CONTAINER}/${ENV}/schema/indexes/lookup`,
    `/database/1/${CONTAINER}/${ENV}/public/schema/indexes/lookup`,
  ];

  console.log(`Container: ${CONTAINER}`);
  console.log(`Environment: ${ENV}`);
  console.log(`Key ID: ${KEY_ID ? KEY_ID.substring(0, 8) + "..." : "NOT SET"}\n`);

  // Step 1: Find the right schema endpoint
  console.log("=== Testing schema endpoints ===");
  for (const path of schemaEndpoints) {
    const body = path.includes("records/lookup")
      ? { recordTypes: [{ recordName: "Event" }] }
      : {};
    const result = await cloudKitFetch(path, body, pk);
    console.log(`${result.status} ${path}`);
    if (result.status === 200) {
      console.log("  SUCCESS! Response:");
      console.log(`  ${JSON.stringify(result.data).substring(0, 500)}`);
    } else {
      const reason = typeof result.data === "object" ? result.data.reason : result.data;
      console.log(`  ${reason}`);
    }
  }

  // Step 2: Try schema modification endpoints
  console.log("\n=== Testing schema modification endpoints ===");
  const modifyEndpoints = [
    `/database/1/${CONTAINER}/${ENV}/schema/records/modify`,
    `/database/1/${CONTAINER}/${ENV}/public/schema/records/modify`,
    `/database/1/${CONTAINER}/${ENV}/schema/indexes/modify`,
    `/database/1/${CONTAINER}/${ENV}/public/schema/indexes/modify`,
  ];

  const modifyBody = {
    operations: [
      {
        operationType: "update",
        recordType: {
          recordName: "Event",
          indexes: [
            { fieldName: "recordName", fieldType: "QUERYABLE" },
            { fieldName: "title", fieldType: "QUERYABLE" },
            { fieldName: "startDate", fieldType: "QUERYABLE" },
            { fieldName: "startDate", fieldType: "SORTABLE" },
            { fieldName: "metro", fieldType: "QUERYABLE" },
          ],
        },
      },
    ],
  };

  for (const path of modifyEndpoints) {
    const result = await cloudKitFetch(path, modifyBody, pk);
    console.log(`${result.status} ${path}`);
    if (result.status === 200) {
      console.log("  SUCCESS!");
      console.log(`  ${JSON.stringify(result.data).substring(0, 500)}`);
    } else {
      const reason = typeof result.data === "object" ? result.data.reason : result.data;
      console.log(`  ${reason}`);
    }
  }

  // Step 3: Verify query still fails/works
  console.log("\n=== Testing query ===");
  const queryPath = `/database/1/${CONTAINER}/${ENV}/public/records/query`;
  const queryResult = await cloudKitFetch(queryPath, {
    query: { recordType: "Event" },
    resultsLimit: 2,
  }, pk);
  console.log(`Query status: ${queryResult.status}`);
  if (queryResult.status === 200) {
    console.log(`Records: ${queryResult.data.records?.length || 0}`);
    if (queryResult.data.records?.[0]) {
      const rec = queryResult.data.records[0];
      console.log(`First: ${rec.recordName}`);
      for (const [key, val] of Object.entries(rec.fields || {})) {
        const f = val as any;
        console.log(`  ${key}: type=${f.type}, value=${JSON.stringify(f.value).substring(0, 80)}`);
      }
    }
  } else {
    const reason = typeof queryResult.data === "object" ? queryResult.data.reason : queryResult.data;
    console.log(`Error: ${reason}`);
  }
}

main().catch(console.error);
