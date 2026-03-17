import { log } from "./logger.js";

interface GeoResult {
  latitude: number;
  longitude: number;
}

// Simple geocoder using OpenStreetMap Nominatim (free, no API key needed)
// Rate limit: 1 request/second
export const RATE_LIMITED = "RATE_LIMITED" as const;
export type GeocodedResult = GeoResult | typeof RATE_LIMITED | null;

const MAX_RETRIES = 3;

export async function geocodeAddress(
  address: string
): Promise<GeocodedResult> {
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const encoded = encodeURIComponent(address);
      const url = `https://nominatim.openstreetmap.org/search?q=${encoded}&format=json&limit=1&countrycodes=us`;

      const res = await fetch(url, {
        headers: {
          "User-Agent": "ParentGuide-Pipeline/1.0 (contact@parentguide.app)",
        },
        signal: AbortSignal.timeout(10000), // 10s timeout per request
      });

      if (res.status === 429) {
        if (attempt < MAX_RETRIES) {
          // Exponential backoff: 3s, 6s, 12s
          const backoff = 3000 * Math.pow(2, attempt);
          log.warn("geocoder", `HTTP 429 for "${address}" — retry ${attempt + 1}/${MAX_RETRIES} in ${backoff / 1000}s`);
          await delay(backoff);
          continue;
        }
        log.warn("geocoder", `HTTP 429 (rate limited, exhausted retries) for: ${address}`);
        return RATE_LIMITED;
      }
      if (!res.ok) {
        log.warn("geocoder", `HTTP ${res.status} for: ${address}`);
        return null;
      }

      const data = (await res.json()) as Array<{ lat: string; lon: string }>;
      if (data.length === 0) return null;

      return {
        latitude: parseFloat(data[0].lat),
        longitude: parseFloat(data[0].lon),
      };
    } catch (err) {
      if (attempt < MAX_RETRIES) {
        const backoff = 2000 * Math.pow(2, attempt);
        log.warn("geocoder", `Request error for "${address}" — retry ${attempt + 1}/${MAX_RETRIES} in ${backoff / 1000}s`);
        await delay(backoff);
        continue;
      }
      log.error("geocoder", `Failed to geocode: ${address}`, err);
      return null;
    }
  }
  return null;
}

// Throttle to respect Nominatim rate limits
export async function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
