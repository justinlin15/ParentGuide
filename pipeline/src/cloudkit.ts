import { createSign, createHash } from "crypto";
import { readFile } from "fs/promises";
import { writeFile, mkdir } from "fs/promises";
import { join } from "path";
import { config } from "./config.js";
import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";

// CloudKit Web Services REST API with server-to-server auth
// https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/

const CK_BASE = "https://api.apple-cloudkit.com";
const BATCH_SIZE = 200; // CloudKit max per request
const OUTPUT_DIR = join(process.cwd(), "output");

// ─── Auth ────────────────────────────────────────────────────────────────────

async function getPrivateKey(): Promise<string> {
  // Prefer raw env var (GitHub Actions), fall back to file path (local dev)
  if (config.cloudkit.privateKey) {
    return config.cloudkit.privateKey;
  }
  if (config.cloudkit.privateKeyPath) {
    return await readFile(config.cloudkit.privateKeyPath, "utf-8");
  }
  throw new Error(
    "CloudKit private key not configured. Set CLOUDKIT_PRIVATE_KEY or CLOUDKIT_PRIVATE_KEY_PATH."
  );
}

function signRequest(
  date: string,
  body: string,
  subpath: string,
  privateKeyPem: string
): string {
  // Signature payload: "{date}:{bodyHash}:{subpath}"
  const bodyHash = createHash("sha256").update(body, "utf-8").digest("base64");
  const message = `${date}:${bodyHash}:${subpath}`;
  const sign = createSign("SHA256");
  sign.update(message);
  return sign.sign(privateKeyPem, "base64");
}

async function cloudKitFetch(
  subpath: string,
  body: object,
  privateKeyPem: string
): Promise<any> {
  const url = `${CK_BASE}${subpath}`;
  const bodyStr = JSON.stringify(body);
  const date = new Date().toISOString().replace(/\.\d{3}Z$/, "Z"); // no millis

  const signature = signRequest(date, bodyStr, subpath, privateKeyPem);

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Apple-CloudKit-Request-KeyID": config.cloudkit.keyId,
      "X-Apple-CloudKit-Request-ISO8601Date": date,
      "X-Apple-CloudKit-Request-SignatureV1": signature,
    },
    body: bodyStr,
    signal: AbortSignal.timeout(60000), // 60s timeout per request
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`CloudKit API ${resp.status}: ${text}`);
  }

  return resp.json();
}

// ─── Query for manually edited records ───────────────────────────────────────

async function fetchManuallyEditedRecords(
  privateKeyPem: string
): Promise<Set<string>> {
  const env = config.cloudkit.environment;
  const container = config.cloudkit.container;
  const subpath = `/database/1/${container}/${env}/public/records/query`;

  const body = {
    query: {
      recordType: "Event",
      filterBy: [
        {
          comparator: "EQUALS",
          fieldName: "manuallyEdited",
          fieldValue: { value: 1 },
        },
      ],
    },
    resultsLimit: 500,
  };

  const editedNames = new Set<string>();

  try {
    let continuationMarker: string | undefined;
    let page = 0;

    do {
      const requestBody = continuationMarker
        ? { ...body, continuationMarker }
        : body;

      const result = await cloudKitFetch(subpath, requestBody, privateKeyPem);

      for (const record of result.records || []) {
        if (record.recordName) {
          editedNames.add(record.recordName);
        }
      }

      continuationMarker = result.continuationMarker;
      page++;
    } while (continuationMarker && page < 10); // safety cap

    return editedNames;
  } catch (err) {
    log.warn(
      "cloudkit",
      `Could not fetch manually edited records: ${err} — will upload all`
    );
    return editedNames; // empty set = upload everything
  }
}

// ─── Record conversion ──────────────────────────────────────────────────────

function toCloudKitRecord(event: PipelineEvent) {
  // Core fields that exist in the CloudKit schema
  const fields: Record<string, { value: unknown }> = {
    sourceId: { value: event.sourceId },
    source: { value: event.source },
    title: { value: event.title },
    description: { value: event.description },
    startDate: { value: new Date(event.startDate).getTime() },
    endDate: { value: event.endDate ? new Date(event.endDate).getTime() : null },
    isAllDay: { value: event.isAllDay ? 1 : 0 },
    category: { value: event.category },
    city: { value: event.city },
    address: { value: event.address || "" },
    latitude: { value: event.latitude ?? null },
    longitude: { value: event.longitude ?? null },
    locationName: { value: event.locationName || "" },
    imageURL: { value: event.imageURL || "" },
    externalURL: { value: event.externalURL || "" },
    isFeatured: { value: event.isFeatured ? 1 : 0 },
    isRecurring: { value: event.isRecurring ? 1 : 0 },
    tags: { value: event.tags },
    metro: { value: event.metro },
  };

  // Enriched fields — these columns must exist in CloudKit Dashboard → Schema → Event
  // as String fields. Add them there before running the pipeline with upload enabled.
  if (event.price) fields.price = { value: event.price };
  if (event.ageRange) fields.ageRange = { value: event.ageRange };
  if (event.websiteURL) fields.websiteURL = { value: event.websiteURL };
  if (event.phone) fields.phone = { value: event.phone };
  if (event.contactEmail) fields.contactEmail = { value: event.contactEmail };

  // Moderation status — default to "published" for backwards compatibility
  fields.status = { value: event.status ?? "published" };

  return {
    recordType: "Event",
    recordName: event.sourceId.replace(/[^a-zA-Z0-9_-]/g, "_"),
    fields,
  };
}

// ─── Upload ─────────────────────────────────────────────────────────────────

async function uploadBatch(
  records: ReturnType<typeof toCloudKitRecord>[],
  privateKeyPem: string,
  batchNum: number,
  totalBatches: number
): Promise<{ saved: number; errors: number }> {
  const env = config.cloudkit.environment;
  const container = config.cloudkit.container;
  const subpath = `/database/1/${container}/${env}/public/records/modify`;

  const body = {
    operations: records.map((record) => ({
      operationType: "forceReplace",
      record,
    })),
  };

  const MAX_RETRIES = 2;
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const result = await cloudKitFetch(subpath, body, privateKeyPem);

      let saved = 0;
      let errors = 0;

      for (const rec of result.records || []) {
        if (rec.serverErrorCode) {
          errors++;
          if (errors <= 3) {
            log.warn(
              "cloudkit",
              `  Record error: ${rec.serverErrorCode} — ${rec.reason || rec.recordName}`
            );
          }
        } else {
          saved++;
        }
      }

      log.info(
        "cloudkit",
        `  Batch ${batchNum}/${totalBatches}: ${saved} saved, ${errors} errors`
      );
      return { saved, errors };
    } catch (err) {
      if (attempt < MAX_RETRIES) {
        const backoff = 3000 * Math.pow(2, attempt);
        log.warn("cloudkit", `  Batch ${batchNum}/${totalBatches} failed (attempt ${attempt + 1}) — retrying in ${backoff / 1000}s: ${err}`);
        await new Promise((r) => setTimeout(r, backoff));
        continue;
      }
      log.error("cloudkit", `  Batch ${batchNum}/${totalBatches} failed after ${MAX_RETRIES + 1} attempts: ${err}`);
      return { saved: 0, errors: records.length };
    }
  }
  return { saved: 0, errors: records.length };
}

export async function uploadToCloudKit(
  events: PipelineEvent[]
): Promise<void> {
  // Always write local output files for debugging/artifacts
  await writeOutputFiles(events);

  if (config.dryRun) {
    log.info("cloudkit", `[DRY RUN] Would upload ${events.length} events`);
    return;
  }

  if (!config.cloudkit.container || !config.cloudkit.keyId) {
    log.warn(
      "cloudkit",
      "CloudKit not configured (missing container or keyId) — skipping upload"
    );
    return;
  }

  let privateKeyPem: string;
  try {
    privateKeyPem = await getPrivateKey();
  } catch (err) {
    log.warn("cloudkit", `${err} — skipping upload`);
    return;
  }

  const allRecords = events.map(toCloudKitRecord);

  // Deduplicate by recordName — different sourceIds can map to the same
  // recordName after character replacement, causing "Record updated multiple
  // times in one batch" errors.
  const seen = new Set<string>();
  const records = allRecords.filter((r) => {
    if (seen.has(r.recordName)) return false;
    seen.add(r.recordName);
    return true;
  });

  if (records.length < allRecords.length) {
    log.info(
      "cloudkit",
      `Deduplicated ${allRecords.length - records.length} records with colliding names`
    );
  }

  log.info(
    "cloudkit",
    `Uploading ${records.length} events to ${config.cloudkit.container} (${config.cloudkit.environment})…`
  );
  const batches: (typeof records)[] = [];
  for (let i = 0; i < records.length; i += BATCH_SIZE) {
    batches.push(records.slice(i, i + BATCH_SIZE));
  }

  let totalSaved = 0;
  let totalErrors = 0;

  for (let i = 0; i < batches.length; i++) {
    const { saved, errors } = await uploadBatch(
      batches[i],
      privateKeyPem,
      i + 1,
      batches.length
    );
    totalSaved += saved;
    totalErrors += errors;

    // Rate limit: brief pause between batches
    if (i < batches.length - 1) {
      await new Promise((r) => setTimeout(r, 500));
    }
  }

  if (totalErrors > 0) {
    log.warn(
      "cloudkit",
      `Upload complete: ${totalSaved} saved, ${totalErrors} errors`
    );
  } else {
    log.success("cloudkit", `Upload complete: ${totalSaved} events saved`);
  }
}

// ─── Local output (always written for debugging) ────────────────────────────

async function writeOutputFiles(events: PipelineEvent[]): Promise<void> {
  await mkdir(OUTPUT_DIR, { recursive: true });

  const byMetro = new Map<string, PipelineEvent[]>();
  for (const event of events) {
    const list = byMetro.get(event.metro) || [];
    list.push(event);
    byMetro.set(event.metro, list);
  }

  for (const [metro, metroEvents] of byMetro) {
    const filePath = join(OUTPUT_DIR, `${metro}.json`);
    const records = metroEvents.map(toCloudKitRecord);
    await writeFile(filePath, JSON.stringify(records, null, 2));
    log.info("cloudkit", `  ${metro}: ${metroEvents.length} events → ${filePath}`);
  }

  const combinedPath = join(OUTPUT_DIR, "all-events.json");
  await writeFile(combinedPath, JSON.stringify(events, null, 2));
  log.success("cloudkit", `${events.length} events written to output/`);

  const summary = {
    generatedAt: new Date().toISOString(),
    totalEvents: events.length,
    byMetro: Object.fromEntries(
      Array.from(byMetro.entries()).map(([k, v]) => [k, v.length])
    ),
    bySource: countBy(events, "source"),
    byCategory: countBy(events, "category"),
  };
  await writeFile(
    join(OUTPUT_DIR, "summary.json"),
    JSON.stringify(summary, null, 2)
  );
}

function countBy(
  events: PipelineEvent[],
  key: keyof PipelineEvent
): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const event of events) {
    const val = String(event[key]);
    counts[val] = (counts[val] || 0) + 1;
  }
  return counts;
}
