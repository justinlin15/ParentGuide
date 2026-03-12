/**
 * Set up CloudKit schema indexes for the Event record type.
 * Run once to make fields queryable so the iOS app's CKQuery works.
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

async function cloudKitFetch(subpath: string, body: object, pk: string): Promise<any> {
  const url = `${CK_BASE}${subpath}`;
  const bodyStr = JSON.stringify(body);
  const date = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const signature = signRequest(date, bodyStr, subpath, pk);

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Apple-CloudKit-Request-KeyID": KEY_ID,
      "X-Apple-CloudKit-Request-ISO8601Date": date,
      "X-Apple-CloudKit-Request-SignatureV1": signature,
    },
    body: bodyStr,
  });

  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(`CloudKit API ${resp.status}: ${text}`);
  }
  return JSON.parse(text);
}

async function main() {
  const pk = await getPrivateKey();

  // Step 1: Look up current schema
  console.log("Looking up current Event schema...");
  const lookupSubpath = `/database/1/${CONTAINER}/${ENV}/schema/records/lookup`;
  try {
    const lookupResult = await cloudKitFetch(lookupSubpath, {
      recordTypes: [{ recordName: "Event" }],
    }, pk);
    console.log("Current schema:");
    console.log(JSON.stringify(lookupResult, null, 2));
  } catch (err) {
    console.log("Schema lookup failed (might not exist yet):", err);
  }

  // Step 2: Modify schema to add queryable indexes
  console.log("\nAdding queryable indexes to Event record type...");
  const modifySubpath = `/database/1/${CONTAINER}/${ENV}/schema/records/modify`;

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
            { fieldName: "source", fieldType: "QUERYABLE" },
            { fieldName: "category", fieldType: "QUERYABLE" },
            { fieldName: "city", fieldType: "QUERYABLE" },
            { fieldName: "isFeatured", fieldType: "QUERYABLE" },
          ],
        },
      },
    ],
  };

  try {
    const result = await cloudKitFetch(modifySubpath, modifyBody, pk);
    console.log("Schema updated successfully!");
    console.log(JSON.stringify(result, null, 2));
  } catch (err) {
    console.error("Schema update failed:", err);
  }

  // Step 3: Verify by querying
  console.log("\nVerifying: querying Event records...");
  const querySubpath = `/database/1/${CONTAINER}/${ENV}/public/records/query`;
  try {
    const queryResult = await cloudKitFetch(querySubpath, {
      query: { recordType: "Event" },
      resultsLimit: 3,
    }, pk);
    console.log(`Query returned ${queryResult.records?.length || 0} records`);
    if (queryResult.records?.[0]) {
      const rec = queryResult.records[0];
      console.log(`\nFirst record: ${rec.recordName}`);
      for (const [key, val] of Object.entries(rec.fields || {})) {
        const field = val as any;
        console.log(`  ${key}: type=${field.type}, value=${JSON.stringify(field.value).substring(0, 100)}`);
      }
    }
  } catch (err) {
    console.error("Query failed:", err);
  }
}

main().catch(console.error);
