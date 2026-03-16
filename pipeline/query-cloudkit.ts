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

async function main() {
  const pk = await getPrivateKey();
  const subpath = `/database/1/${CONTAINER}/${ENV}/public/records/query`;
  const body = {
    query: {
      recordType: "Event",
    },
    resultsLimit: 5,
  };
  const bodyStr = JSON.stringify(body);
  const date = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const signature = signRequest(date, bodyStr, subpath, pk);
  const url = `${CK_BASE}${subpath}`;

  console.log(`Querying CloudKit: ${CONTAINER} (${ENV})`);
  console.log(`Key ID: ${KEY_ID}`);

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

  if (!resp.ok) {
    console.error(`Error: ${resp.status} ${await resp.text()}`);
    return;
  }

  const data = await resp.json();
  console.log(`\nTotal records returned: ${data.records?.length || 0}`);

  if (data.records && data.records.length > 0) {
    console.log("\n--- First record ---");
    const rec = data.records[0];
    console.log(`recordName: ${rec.recordName}`);
    console.log(`recordType: ${rec.recordType}`);
    console.log("\nFields:");
    for (const [key, val] of Object.entries(rec.fields || {})) {
      const field = val as any;
      console.log(`  ${key}: type=${field.type}, value=${JSON.stringify(field.value)}`);
    }

    console.log("\n--- Second record ---");
    if (data.records.length > 1) {
      const rec2 = data.records[1];
      console.log(`recordName: ${rec2.recordName}`);
      console.log("\nFields:");
      for (const [key, val] of Object.entries(rec2.fields || {})) {
        const field = val as any;
        console.log(`  ${key}: type=${field.type}, value=${JSON.stringify(field.value)}`);
      }
    }
  } else {
    console.log("No records found!");
    console.log("Full response:", JSON.stringify(data, null, 2));
  }
}

main().catch(console.error);
