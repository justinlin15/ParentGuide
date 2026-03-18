import "dotenv/config";

// Metro area definitions for MVP
export interface MetroArea {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  radiusMiles: number;
  // Macaroni KID subdomain slugs for this metro
  macaroniKidSlugs: string[];
  // Whether this metro is active for the current launch phase
  enabled: boolean;
}

export const METRO_AREAS: MetroArea[] = [
  {
    id: "los-angeles",
    name: "Los Angeles",
    latitude: 34.0522,
    longitude: -118.2437,
    radiusMiles: 35,
    macaroniKidSlugs: [
      "losangeles",
      "longbeach",
      "pasadena",
      "santamonica",
    ],
    enabled: true,
  },
  {
    id: "orange-county",
    name: "Orange County",
    latitude: 33.7175,
    longitude: -117.8311,
    radiusMiles: 25,
    macaroniKidSlugs: [
      "orangecounty",
      "irvine",
    ],
    enabled: true,
  },
  {
    id: "new-york",
    name: "New York City / Tri-State",
    latitude: 40.7128,
    longitude: -74.006,
    radiusMiles: 40,
    macaroniKidSlugs: [
      "newyorkcity",
      "brooklyn",
      "queens",
      "westchester",
      "longisland",
      "newjersey",
    ],
    enabled: false,
  },
  {
    id: "dallas",
    name: "Dallas-Fort Worth",
    latitude: 32.7767,
    longitude: -96.797,
    radiusMiles: 40,
    macaroniKidSlugs: ["dallas", "fortworth", "plano", "frisco", "arlington"],
    enabled: false,
  },
  {
    id: "chicago",
    name: "Chicago",
    latitude: 41.8781,
    longitude: -87.6298,
    radiusMiles: 40,
    macaroniKidSlugs: [
      "chicago",
      "chicagonorthshore",
      "naperville",
      "schaumburg",
    ],
    enabled: false,
  },
  {
    id: "atlanta",
    name: "Atlanta",
    latitude: 33.749,
    longitude: -84.388,
    radiusMiles: 40,
    macaroniKidSlugs: [
      "atlanta",
      "marietta",
      "alpharetta",
      "decatur",
      "roswell",
    ],
    enabled: false,
  },
];

export const config = {
  ticketmaster: {
    apiKey: process.env.TICKETMASTER_API_KEY || "",
    baseUrl: "https://app.ticketmaster.com/discovery/v2",
  },
  seatgeek: {
    clientId: process.env.SEATGEEK_CLIENT_ID || "",
    baseUrl: "https://api.seatgeek.com/2",
  },
  yelp: {
    apiKey: process.env.YELP_API_KEY || "",
    baseUrl: "https://api.yelp.com/v3",
  },
  unsplash: {
    accessKey: process.env.UNSPLASH_ACCESS_KEY || "",
    baseUrl: "https://api.unsplash.com",
  },
  pexels: {
    apiKey: process.env.PEXELS_API_KEY || "",
    baseUrl: "https://api.pexels.com/v1",
  },
    eventbrite: {
          apiKey: process.env.EVENTBRITE_API_KEY || "",
          baseUrl: "https://www.eventbriteapi.com/v3",
    },
  cloudkit: {
    container: process.env.CLOUDKIT_CONTAINER || "",
    keyId: process.env.CLOUDKIT_KEY_ID || "",
    privateKeyPath: process.env.CLOUDKIT_PRIVATE_KEY_PATH || "",
    // Raw PEM content — used in GitHub Actions where file path isn't practical
    privateKey: process.env.CLOUDKIT_PRIVATE_KEY || "",
    environment: process.env.CLOUDKIT_ENVIRONMENT || "development",
  },
  // Pipeline settings
  dryRun: process.argv.includes("--dry-run"),
  scrapersOnly: process.argv.includes("--scrapers-only"),
};
