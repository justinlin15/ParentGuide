import { log } from "./logger.js";

interface GeoResult {
  latitude: number;
  longitude: number;
}

// Simple geocoder using OpenStreetMap Nominatim (free, no API key needed)
// Rate limit: 1 request/second
export async function geocodeAddress(
  address: string
): Promise<GeoResult | null> {
  try {
    const encoded = encodeURIComponent(address);
    const url = `https://nominatim.openstreetmap.org/search?q=${encoded}&format=json&limit=1&countrycodes=us`;

    const res = await fetch(url, {
      headers: {
        "User-Agent": "ParentGuide-Pipeline/1.0 (contact@parentguide.app)",
      },
    });

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
    log.error("geocoder", `Failed to geocode: ${address}`, err);
    return null;
  }
}

// Throttle to respect Nominatim rate limits
export async function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
