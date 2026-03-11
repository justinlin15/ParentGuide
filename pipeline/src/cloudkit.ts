import { config } from "./config.js";
import { type PipelineEvent } from "./normalize.js";
import { log } from "./utils/logger.js";

// CloudKit Web Services REST API
// Docs: https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/

// For now, this outputs events as JSON files that can be loaded into CloudKit
// via the CloudKit Dashboard or a Swift command-line tool.
// When you set up server-to-server auth, this can be upgraded to direct API calls.

import { writeFile, mkdir } from "fs/promises";
import { join } from "path";

const OUTPUT_DIR = join(process.cwd(), "output");

export async function uploadToCloudKit(
  events: PipelineEvent[]
): Promise<void> {
  if (config.dryRun) {
    log.info("cloudkit", `[DRY RUN] Would upload ${events.length} events`);
    await writeOutputFiles(events);
    return;
  }

  if (!config.cloudkit.container || !config.cloudkit.keyId) {
    log.warn(
      "cloudkit",
      "CloudKit not configured — writing to output/ instead"
    );
    await writeOutputFiles(events);
    return;
  }

  // TODO: Implement direct CloudKit Web Services API calls
  // For now, write JSON files that can be imported via Swift CLI or Dashboard
  log.info(
    "cloudkit",
    "Direct CloudKit upload not yet configured — writing to output/"
  );
  await writeOutputFiles(events);
}

async function writeOutputFiles(events: PipelineEvent[]): Promise<void> {
  await mkdir(OUTPUT_DIR, { recursive: true });

  // Group by metro
  const byMetro = new Map<string, PipelineEvent[]>();
  for (const event of events) {
    const list = byMetro.get(event.metro) || [];
    list.push(event);
    byMetro.set(event.metro, list);
  }

  // Write per-metro files
  for (const [metro, metroEvents] of byMetro) {
    const filePath = join(OUTPUT_DIR, `${metro}.json`);

    // Convert to CloudKit-compatible record format
    const records = metroEvents.map(toCloudKitRecord);

    await writeFile(filePath, JSON.stringify(records, null, 2));
    log.info("cloudkit", `  ${metro}: ${metroEvents.length} events → ${filePath}`);
  }

  // Write combined file
  const combinedPath = join(OUTPUT_DIR, "all-events.json");
  await writeFile(combinedPath, JSON.stringify(events, null, 2));
  log.success(
    "cloudkit",
    `Total: ${events.length} events written to output/`
  );

  // Write summary
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

// Convert a PipelineEvent to a CloudKit record format
// This matches the Event record type you'll create in CloudKit Dashboard
function toCloudKitRecord(event: PipelineEvent) {
  return {
    recordType: "Event",
    recordName: event.sourceId.replace(/[^a-zA-Z0-9_-]/g, "_"),
    fields: {
      sourceId: { value: event.sourceId, type: "STRING" },
      source: { value: event.source, type: "STRING" },
      title: { value: event.title, type: "STRING" },
      description: { value: event.description, type: "STRING" },
      startDate: {
        value: new Date(event.startDate).getTime(),
        type: "TIMESTAMP",
      },
      endDate: {
        value: event.endDate ? new Date(event.endDate).getTime() : null,
        type: "TIMESTAMP",
      },
      isAllDay: { value: event.isAllDay ? 1 : 0, type: "INT64" },
      category: { value: event.category, type: "STRING" },
      city: { value: event.city, type: "STRING" },
      address: { value: event.address || "", type: "STRING" },
      latitude: { value: event.latitude || 0, type: "DOUBLE" },
      longitude: { value: event.longitude || 0, type: "DOUBLE" },
      locationName: { value: event.locationName || "", type: "STRING" },
      imageURL: { value: event.imageURL || "", type: "STRING" },
      externalURL: { value: event.externalURL || "", type: "STRING" },
      isFeatured: { value: event.isFeatured ? 1 : 0, type: "INT64" },
      isRecurring: { value: event.isRecurring ? 1 : 0, type: "INT64" },
      tags: { value: event.tags, type: "STRING_LIST" },
      metro: { value: event.metro, type: "STRING" },
    },
  };
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
