/**
 * venue-urls.ts
 *
 * Known venue → events/calendar URL mapping for Orange County & LA venues.
 * Used by the enrichment step to replace Google Search fallback URLs with
 * direct links to the venue's events page.
 *
 * The matcher is case-insensitive and supports partial matching so that
 * variations like "Huntington Beach Central Library" and
 * "Huntington Beach Central Library - Main Street" both resolve.
 */

export interface VenueUrlEntry {
  /** URL to the venue's events/calendar page */
  url: string;
  /** Optional: direct website URL (used as websiteURL if set) */
  websiteURL?: string;
}

// ─── OC Public Libraries (OCPL system) ────────────────────────────────────────
// OCPL branches share the ocpl.libcal.com platform with per-branch slugs.

const OCPL_BRANCHES: Record<string, string> = {
  "el toro": "eltoro",
  "westminster": "westminster",
  "stanton": "stanton",
  "los alamitos": "losalamitos",
  "rossmoor": "losalamitos",
  "rancho santa margarita": "rsm",
  "foothill ranch": "foothillranch",
  "la palma": "lapalma",
  "library of the canyons": "canyons",
  "seal beach": "sealbeach",
  "villa park": "villapark",
  "ladera ranch": "laderaranch",
  "laguna hills": "lagunahills",
  "dana point": "danapoint",
  "laguna niguel": "lagunaniguel",
  "mesa verde": "mesaverde",
  "san juan capistrano": "sjcapistrano",
  "corona del mar": "coronadelmar",
  "aliso viejo": "alisoviejo",
  "silverado": "silverado",
  "katie wheeler": "katiewheeler",
  "brea": "brea",
  "tustin": "tustin",
  "costa mesa": "costamesadd",
  "donald dungan": "costamesadd",
  "san clemente": "sanclemente",
  "fountain valley": "fountainvalley",
  "laguna beach": "lagunabeach",
  "cypress": "cypress",
  "garden grove tibor rubin": "ggtr",
  "tibor rubin": "ggtr",
  "garden grove chapman": "chapman",
  "chapman branch": "chapman",
  "chapman library": "chapman",
  "orange public": "orange",
};

function ocplUrl(slug: string): string {
  return `https://ocpl.libcal.com/calendar/${slug}`;
}

// ─── Independent Library Systems ──────────────────────────────────────────────

const INDEPENDENT_LIBRARIES: Record<string, VenueUrlEntry> = {
  // Huntington Beach Public Library system
  "huntington beach central library": {
    url: "https://hbpl.libcal.com/calendar/events",
  },
  "oak view library": {
    url: "https://hbpl.libcal.com/calendar/events",
  },
  "main street library": {
    url: "https://hbpl.libcal.com/calendar/events",
  },
  "huntington beach main street library": {
    url: "https://hbpl.libcal.com/calendar/events",
  },
  "banning branch library": {
    url: "https://hbpl.libcal.com/calendar/events",
  },
  "murphy ranch branch library": {
    url: "https://hbpl.libcal.com/calendar/events",
  },
  "murphy branch library": {
    url: "https://hbpl.libcal.com/calendar/events",
  },

  // Newport Beach Public Library system
  "newport beach central library": {
    url: "https://www.newportbeachlibrary.org/calendar/library-event-list",
  },
  "newport beach public library central": {
    url: "https://www.newportbeachlibrary.org/calendar/library-event-list",
  },
  "mariners library": {
    url: "https://www.newportbeachlibrary.org/calendar/library-event-list",
  },
  "mariners library newport beach": {
    url: "https://www.newportbeachlibrary.org/calendar/library-event-list",
  },

  // Buena Park Library (independent)
  "buena park library": {
    url: "https://www.buenaparklibrary.org/events",
  },

  // Irvine libraries (city system)
  "irvine university park library": {
    url: "https://cityofirvine.org/irvine-public-library/library-events",
  },
  "university park library": {
    url: "https://cityofirvine.org/irvine-public-library/library-events",
  },
  "irvine heritage park library": {
    url: "https://cityofirvine.org/irvine-public-library/library-events",
  },
  "heritage park library": {
    url: "https://cityofirvine.org/irvine-public-library/library-events",
  },
  "heritage park regional library": {
    url: "https://cityofirvine.org/irvine-public-library/library-events",
  },

  // Fullerton Public Library system
  "fullerton public library": {
    url: "https://www.fullertonlibrary.org/calendar",
  },
  "hunt branch library": {
    url: "https://www.fullertonlibrary.org/calendar",
  },
  "hunt library": {
    url: "https://www.fullertonlibrary.org/calendar",
  },

  // Mission Viejo Library
  "mission viejo library": {
    url: "https://cityofmissionviejo.libcal.com/calendar/libraryprograms",
  },

  // Anaheim Public Library system
  "anaheim central library": {
    url: "https://anaheim.libcal.com/calendars",
  },
  "east anaheim branch library": {
    url: "https://anaheim.libcal.com/calendars",
  },
  "anaheim public library - east anaheim branch": {
    url: "https://anaheim.libcal.com/calendars",
  },
  "anaheim canyon hills branch library": {
    url: "https://anaheim.libcal.com/calendars",
  },
  "anaheim canyon hills branch": {
    url: "https://anaheim.libcal.com/calendars",
  },
  "euclid branch library": {
    url: "https://anaheim.libcal.com/calendars",
  },
  "euclid branch": {
    url: "https://anaheim.libcal.com/calendars",
  },
  "sunkist branch library": {
    url: "https://anaheim.libcal.com/calendars",
  },
  "sunkist branch": {
    url: "https://anaheim.libcal.com/calendars",
  },

  // Placentia Library
  "placentia library": {
    url: "https://www.placentialibrary.org/calendar",
  },

  // Yorba Linda Library
  "yorba linda library": {
    url: "https://ylpl.org/event-directory/",
  },

  // Santa Ana Library
  "santa ana library": {
    url: "https://www.santa-ana.org/library-events/",
  },
  "delhi library": {
    url: "https://www.santa-ana.org/library-events/",
  },
  "the delhi library": {
    url: "https://www.santa-ana.org/library-events/",
  },

  // Garden Grove (city library system, also on OCPL)
  "garden grove main library": {
    url: "https://ggcity.org/events",
  },

  // Orange Public Library (also on OCPL)
  "taft branch library": {
    url: "https://orangepubliclibrary.libcal.com/calendar/all",
  },
  "el modena branch library": {
    url: "https://orangepubliclibrary.libcal.com/calendar/all",
  },
};

// ─── Non-Library Venues ───────────────────────────────────────────────────────

const NON_LIBRARY_VENUES: Record<string, VenueUrlEntry> = {
  "south coast plaza": {
    url: "https://www.southcoastplaza.com/calendar/",
    websiteURL: "https://www.southcoastplaza.com/calendar/",
  },
  "oak canyon nature center": {
    url: "https://www.anaheim.net/1111/Programs-Events-Tours",
    websiteURL: "https://www.anaheim.net/1111/Programs-Events-Tours",
  },
  "tanaka farms": {
    url: "https://www.tanakafarms.com/pages/upcoming-events",
    websiteURL: "https://www.tanakafarms.com/pages/upcoming-events",
  },
  "hana field": {
    url: "https://www.tanakafarms.com/pages/hana-field",
    websiteURL: "https://www.tanakafarms.com/pages/hana-field",
  },
  "play & parties": {
    url: "https://www.playandparties.com/",
    websiteURL: "https://www.playandparties.com/",
  },
  "play & parties orange": {
    url: "https://www.playandparties.com/",
    websiteURL: "https://www.playandparties.com/",
  },
  "bass pro shops": {
    url: "https://stores.basspro.com/us/ca/irvine/71-technology-drive.html",
    websiteURL: "https://stores.basspro.com/us/ca/irvine/71-technology-drive.html",
  },
  "bass pro shop": {
    url: "https://stores.basspro.com/us/ca/irvine/71-technology-drive.html",
    websiteURL: "https://stores.basspro.com/us/ca/irvine/71-technology-drive.html",
  },
  "bass pro shops irvine": {
    url: "https://stores.basspro.com/us/ca/irvine/71-technology-drive.html",
    websiteURL: "https://stores.basspro.com/us/ca/irvine/71-technology-drive.html",
  },
  "get air sports": {
    url: "https://getairsports.com/surf-city/",
    websiteURL: "https://getairsports.com/surf-city/",
  },
  "oc fair & event center": {
    url: "https://ocfair.com/",
    websiteURL: "https://ocfair.com/",
  },
  "oc fair and event center": {
    url: "https://ocfair.com/",
    websiteURL: "https://ocfair.com/",
  },
  "orange county fair & event center": {
    url: "https://ocfair.com/",
    websiteURL: "https://ocfair.com/",
  },
  "discovery cube": {
    url: "https://www.discoverycube.org/events/",
    websiteURL: "https://www.discoverycube.org/events/",
  },
  "discovery cube orange county": {
    url: "https://www.discoverycube.org/events/",
    websiteURL: "https://www.discoverycube.org/events/",
  },
  "fountain valley skating center": {
    url: "https://fvsc.com/schedule/",
    websiteURL: "https://fvsc.com/schedule/",
  },
  "fullerton community center": {
    url: "https://www.cityoffullerton.com/residents/community-events",
    websiteURL: "https://www.cityoffullerton.com/residents/community-events",
  },
  "dana point harbor": {
    url: "https://danapointharbor.com/events/",
    websiteURL: "https://danapointharbor.com/events/",
  },
  "irvine regional park": {
    url: "https://www.ocparks.com/irvinepark",
    websiteURL: "https://www.ocparks.com/irvinepark",
  },
  "irvine regional park nature center": {
    url: "https://www.ocparks.com/irvinepark",
    websiteURL: "https://www.ocparks.com/irvinepark",
  },
  "lido theater": {
    url: "https://www.thelidotheater.com/events",
    websiteURL: "https://www.thelidotheater.com/events",
  },
  "lido theatre": {
    url: "https://www.thelidotheater.com/events",
    websiteURL: "https://www.thelidotheater.com/events",
  },
  "casa romantica": {
    url: "https://www.casaromantica.org/calendar/",
    websiteURL: "https://www.casaromantica.org/calendar/",
  },
  "casa romantica cultural center and gardens": {
    url: "https://www.casaromantica.org/calendar/",
    websiteURL: "https://www.casaromantica.org/calendar/",
  },
  "marina park": {
    url: "https://www.newportbeachca.gov/government/departments/recreation-senior-services/marina-park",
    websiteURL: "https://www.newportbeachca.gov/government/departments/recreation-senior-services/marina-park",
  },
  "skate express": {
    url: "https://holidayskate.com/",
    websiteURL: "https://holidayskate.com/",
  },
  "lido marina village": {
    url: "https://www.lidomarinavillage.com/events",
    websiteURL: "https://www.lidomarinavillage.com/events",
  },
  "sherman library and gardens": {
    url: "https://thesherman.org/",
    websiteURL: "https://thesherman.org/",
  },
  "mariners church": {
    url: "https://www.marinerschurch.org/irvine/events/",
    websiteURL: "https://www.marinerschurch.org/irvine/events/",
  },
  "the ecology center": {
    url: "https://www.theecologycenter.org/eventscalendar/",
    websiteURL: "https://www.theecologycenter.org/eventscalendar/",
  },
  "pretend city children's museum": {
    url: "https://www.pretendcity.org/",
    websiteURL: "https://www.pretendcity.org/",
  },
  "pretend city": {
    url: "https://www.pretendcity.org/",
    websiteURL: "https://www.pretendcity.org/",
  },
  "orange county museum of art": {
    url: "https://ocma.art/calendar/",
    websiteURL: "https://ocma.art/calendar/",
  },
  "ocma": {
    url: "https://ocma.art/calendar/",
    websiteURL: "https://ocma.art/calendar/",
  },
  "orange coast college": {
    url: "https://orangecoastcollege.edu/calendars/events.html",
    websiteURL: "https://orangecoastcollege.edu/calendars/events.html",
  },
  "crystal cove state park": {
    url: "https://crystalcove.org/events/",
    websiteURL: "https://crystalcove.org/events/",
  },
  "back bay science center": {
    url: "https://newportbay.org/facilities/back-bay-science-center/",
    websiteURL: "https://newportbay.org/facilities/back-bay-science-center/",
  },
  "centennial farm": {
    url: "https://ocfair.com/centennial-farm/calendar-hours/",
    websiteURL: "https://ocfair.com/centennial-farm/calendar-hours/",
  },
  "centennial farm at oc fair & event center": {
    url: "https://ocfair.com/centennial-farm/calendar-hours/",
    websiteURL: "https://ocfair.com/centennial-farm/calendar-hours/",
  },
  "oc fair & event center - centennial farm": {
    url: "https://ocfair.com/centennial-farm/calendar-hours/",
    websiteURL: "https://ocfair.com/centennial-farm/calendar-hours/",
  },
  "upper newport bay nature preserve": {
    url: "https://newportbay.org/",
    websiteURL: "https://newportbay.org/",
  },
  "upper newport bay": {
    url: "https://newportbay.org/",
    websiteURL: "https://newportbay.org/",
  },
  "newport bay conservancy": {
    url: "https://newportbay.org/",
    websiteURL: "https://newportbay.org/",
  },
  "laguna coast wilderness park": {
    url: "https://lagunacanyon.org/events/",
    websiteURL: "https://lagunacanyon.org/events/",
  },
  "aquarium of the pacific": {
    url: "https://www.aquariumofpacific.org/events",
    websiteURL: "https://www.aquariumofpacific.org/events",
  },
  "zoomars petting zoo": {
    url: "https://riverstreetranch.com/",
    websiteURL: "https://riverstreetranch.com/",
  },
  "ocean institute": {
    url: "https://oceaninstitute.org/calendar-new/",
    websiteURL: "https://oceaninstitute.org/calendar-new/",
  },
  "bowers museum": {
    url: "https://www.bowers.org/programs",
    websiteURL: "https://www.bowers.org/programs",
  },
  "atlantis play center": {
    url: "https://ggcity.org/community-services/atlantis-play-center",
    websiteURL: "https://ggcity.org/community-services/atlantis-play-center",
  },
  "newport dunes waterfront resort": {
    url: "https://www.newportdunes.com/events/",
    websiteURL: "https://www.newportdunes.com/events/",
  },
  "newport dunes waterfront resort & marina": {
    url: "https://www.newportdunes.com/events/",
    websiteURL: "https://www.newportdunes.com/events/",
  },
  "newland house museum": {
    url: "https://www.newlandhouse.org/",
    websiteURL: "https://www.newlandhouse.org/",
  },
  "mission viejo civic center": {
    url: "https://www.cityofmissionviejo.org/",
    websiteURL: "https://www.cityofmissionviejo.org/",
  },
  "la habra community center": {
    url: "https://www.lahabracity.com/",
    websiteURL: "https://www.lahabracity.com/",
  },
  "laguna beach recreation center": {
    url: "https://www.lagunabeachcity.net/government/departments/community-services",
    websiteURL: "https://www.lagunabeachcity.net/government/departments/community-services",
  },
  "irvine spectrum center": {
    url: "https://www.irvinespectrumcenter.com/events",
    websiteURL: "https://www.irvinespectrumcenter.com/events",
  },
  "diego sepulveda adobe": {
    url: "https://www.costamesaca.gov/city-hall/city-departments/parks-community-services/parks/diego-sepulveda-adobe",
    websiteURL: "https://www.costamesaca.gov/city-hall/city-departments/parks-community-services/parks/diego-sepulveda-adobe",
  },
  "santiago oaks regional park": {
    url: "https://www.ocparks.com/santiagooaks",
    websiteURL: "https://www.ocparks.com/santiagooaks",
  },
  "peters canyon regional park": {
    url: "https://www.ocparks.com/peterscanyon",
    websiteURL: "https://www.ocparks.com/peterscanyon",
  },
  "environmental nature center": {
    url: "https://www.encenter.org/",
    websiteURL: "https://www.encenter.org/",
  },
  "newport beach environmental nature center": {
    url: "https://www.encenter.org/",
    websiteURL: "https://www.encenter.org/",
  },
  "orange county model engineers": {
    url: "https://www.ocmetrains.org/",
    websiteURL: "https://www.ocmetrains.org/",
  },
  "saddleback church": {
    url: "https://saddleback.com/",
    websiteURL: "https://saddleback.com/",
  },
  "saddleback church lake forest": {
    url: "https://saddleback.com/",
    websiteURL: "https://saddleback.com/",
  },
  "santiago creek eco center": {
    url: "https://www.santa-ana.org/santiago-creek-eco-center/",
    websiteURL: "https://www.santa-ana.org/santiago-creek-eco-center/",
  },
  "eco tots": {
    url: "https://theecologycenter.org/",
    websiteURL: "https://theecologycenter.org/",
  },
  "fashion island": {
    url: "https://www.shopfashionisland.com/events/",
    websiteURL: "https://www.shopfashionisland.com/events/",
  },
  "the market place": {
    url: "https://themarketplacetustin.com/",
    websiteURL: "https://themarketplacetustin.com/",
  },
  "tustin market place": {
    url: "https://themarketplacetustin.com/",
    websiteURL: "https://themarketplacetustin.com/",
  },
  "rancho los cerritos": {
    url: "https://rancholoscerritos.org/",
    websiteURL: "https://rancholoscerritos.org/",
  },

  // Farmers markets
  "tustin farmers market": {
    url: "https://www.tustinca.org/369/Farmers-Market",
    websiteURL: "https://www.tustinca.org/369/Farmers-Market",
  },
  "downtown anaheim farmers market": {
    url: "https://www.anaheim.net/1120/Farmers-Markets",
    websiteURL: "https://www.anaheim.net/1120/Farmers-Markets",
  },
  "farmakis farms certified farmers market": {
    url: "https://farmakisfarms.com/",
    websiteURL: "https://farmakisfarms.com/",
  },
  "mission viejo farmers market": {
    url: "https://www.cityofmissionviejo.org/",
    websiteURL: "https://www.cityofmissionviejo.org/",
  },
  "laguna beach farmers market": {
    url: "https://www.lagunabeachfarmersmarket.com/",
    websiteURL: "https://www.lagunabeachfarmersmarket.com/",
  },
  "cypress farmers market": {
    url: "https://www.cypressca.org/",
    websiteURL: "https://www.cypressca.org/",
  },
  "orange farmers market": {
    url: "https://www.cityoforange.org/",
    websiteURL: "https://www.cityoforange.org/",
  },
  "newport pier farmers market": {
    url: "https://www.newportbeachca.gov/",
    websiteURL: "https://www.newportbeachca.gov/",
  },
  "ladera ranch farmers market": {
    url: "https://laderalife.com/",
    websiteURL: "https://laderalife.com/",
  },
  "lake forest farmer's market": {
    url: "https://www.lakeforestca.gov/",
    websiteURL: "https://www.lakeforestca.gov/",
  },
  "anaheim hills certified farmers market": {
    url: "https://www.anaheim.net/1120/Farmers-Markets",
    websiteURL: "https://www.anaheim.net/1120/Farmers-Markets",
  },
  "the district farmers market": {
    url: "https://thedistricttustin.com/",
    websiteURL: "https://thedistricttustin.com/",
  },
  "the district at tustin legacy farmers market": {
    url: "https://thedistricttustin.com/",
    websiteURL: "https://thedistricttustin.com/",
  },
  "the district at tustin legacy": {
    url: "https://thedistricttustin.com/",
    websiteURL: "https://thedistricttustin.com/",
  },

  // Coffee shops & restaurants with events
  "aosa coffee": {
    url: "https://www.aosacoffee.com/",
    websiteURL: "https://www.aosacoffee.com/",
  },
  "aosa coffee huntington beach": {
    url: "https://www.aosacoffee.com/",
    websiteURL: "https://www.aosacoffee.com/",
  },
  "high tide coffee": {
    url: "https://www.hightidecoffeeco.com/",
    websiteURL: "https://www.hightidecoffeeco.com/",
  },

  // Shopping centers
  "rodeo 39": {
    url: "https://rodeo39.com/events/",
    websiteURL: "https://rodeo39.com/events/",
  },
  "lbx (long beach exchange)": {
    url: "https://www.lbxlongbeach.com/events",
    websiteURL: "https://www.lbxlongbeach.com/events",
  },
  "lbx": {
    url: "https://www.lbxlongbeach.com/events",
    websiteURL: "https://www.lbxlongbeach.com/events",
  },
  "bella terra": {
    url: "https://www.bellaterra-hb.com/",
    websiteURL: "https://www.bellaterra-hb.com/",
  },
  "the shops at mission viejo": {
    url: "https://www.simon.com/mall/the-shops-at-mission-viejo",
    websiteURL: "https://www.simon.com/mall/the-shops-at-mission-viejo",
  },
  "the shops of mission viejo": {
    url: "https://www.simon.com/mall/the-shops-at-mission-viejo",
    websiteURL: "https://www.simon.com/mall/the-shops-at-mission-viejo",
  },
  "kaleidoscope": {
    url: "https://www.gokaleidoscope.com/",
    websiteURL: "https://www.gokaleidoscope.com/",
  },
  "main place mall": {
    url: "https://www.mainplacemall.com/",
    websiteURL: "https://www.mainplacemall.com/",
  },
  "triangle square starlight cinemas": {
    url: "https://www.regmovies.com/",
    websiteURL: "https://www.regmovies.com/",
  },

  // Bookstores
  "barnes and noble irvine spectrum": {
    url: "https://stores.barnesandnoble.com/store/2650",
    websiteURL: "https://stores.barnesandnoble.com/store/2650",
  },
  "barnes & noble irvine spectrum": {
    url: "https://stores.barnesandnoble.com/store/2650",
    websiteURL: "https://stores.barnesandnoble.com/store/2650",
  },
  "barnes and noble at bella terra": {
    url: "https://stores.barnesandnoble.com/store/2798",
    websiteURL: "https://stores.barnesandnoble.com/store/2798",
  },
  "barnes & noble at bella terra": {
    url: "https://stores.barnesandnoble.com/store/2798",
    websiteURL: "https://stores.barnesandnoble.com/store/2798",
  },
  "barnes & noble bella terra": {
    url: "https://stores.barnesandnoble.com/store/2798",
    websiteURL: "https://stores.barnesandnoble.com/store/2798",
  },
  "barnes & noble": {
    url: "https://www.barnesandnoble.com/",
    websiteURL: "https://www.barnesandnoble.com/",
  },

  // Community centers & recreation
  "delhi community center": {
    url: "https://www.santa-ana.org/delhi-center/",
    websiteURL: "https://www.santa-ana.org/delhi-center/",
  },
  "huntington beach central park": {
    url: "https://www.huntingtonbeachca.gov/residents/parks-facilities/parks/central-park/",
    websiteURL: "https://www.huntingtonbeachca.gov/residents/parks-facilities/parks/central-park/",
  },
  "sea country senior & community center": {
    url: "https://www.sanjuancapistrano.org/",
    websiteURL: "https://www.sanjuancapistrano.org/",
  },
  "sea country community services": {
    url: "https://www.sanjuancapistrano.org/",
    websiteURL: "https://www.sanjuancapistrano.org/",
  },
  "sea country community services district": {
    url: "https://www.sanjuancapistrano.org/",
    websiteURL: "https://www.sanjuancapistrano.org/",
  },
  "crossings church": {
    url: "https://www.crossings.church/",
    websiteURL: "https://www.crossings.church/",
  },
  "fullerton train museum": {
    url: "https://www.fullertontrainmuseum.org/",
    websiteURL: "https://www.fullertontrainmuseum.org/",
  },
  "brea civic and cultural center": {
    url: "https://www.ci.brea.ca.us/",
    websiteURL: "https://www.ci.brea.ca.us/",
  },
  "the muck": {
    url: "https://www.themuckinstitute.org/",
    websiteURL: "https://www.themuckinstitute.org/",
  },
  "hangar 18": {
    url: "https://www.climbhangar18.com/",
    websiteURL: "https://www.climbhangar18.com/",
  },
  "doodlebugs animal adventure": {
    url: "https://www.doodlebugsanimaladventure.com/",
    websiteURL: "https://www.doodlebugsanimaladventure.com/",
  },
  "skate n play": {
    url: "https://www.skatennplay.com/",
    websiteURL: "https://www.skatennplay.com/",
  },
  "goldfish swim school": {
    url: "https://www.goldfishswimschool.com/",
    websiteURL: "https://www.goldfishswimschool.com/",
  },
  "playhub indoor playground": {
    url: "https://www.playhubindoorplayground.com/",
    websiteURL: "https://www.playhubindoorplayground.com/",
  },
  "black star canyon": {
    url: "https://www.ocparks.com/",
    websiteURL: "https://www.ocparks.com/",
  },
  "aliso and wood canyons wilderness park": {
    url: "https://www.ocparks.com/alisoandwoodcanyons",
    websiteURL: "https://www.ocparks.com/alisoandwoodcanyons",
  },
  "aliso and wood canyons park": {
    url: "https://www.ocparks.com/alisoandwoodcanyons",
    websiteURL: "https://www.ocparks.com/alisoandwoodcanyons",
  },
  "mile square regional park": {
    url: "https://www.ocparks.com/milesquare",
    websiteURL: "https://www.ocparks.com/milesquare",
  },
  "laguna niguel regional park": {
    url: "https://www.ocparks.com/lagunaniguel",
    websiteURL: "https://www.ocparks.com/lagunaniguel",
  },
  "irvine ranch natural landmarks": {
    url: "https://letsgooutside.org/",
    websiteURL: "https://letsgooutside.org/",
  },
  "bommer canyon": {
    url: "https://letsgooutside.org/",
    websiteURL: "https://letsgooutside.org/",
  },
  "san clemente state beach": {
    url: "https://www.parks.ca.gov/?page_id=646",
    websiteURL: "https://www.parks.ca.gov/?page_id=646",
  },
  "little folk club": {
    url: "https://www.instagram.com/littlefolkclub/",
    websiteURL: "https://www.instagram.com/littlefolkclub/",
  },
  "ocean institute": {
    url: "https://oceaninstitute.org/calendar-new/",
    websiteURL: "https://oceaninstitute.org/calendar-new/",
  },
};

// ─── Lookup Function ──────────────────────────────────────────────────────────

/**
 * Look up a known venue URL by location name.
 * Returns the venue's events/calendar URL, or undefined if not found.
 *
 * Matching strategy:
 * 1. Exact match in independent libraries or non-library venues
 * 2. Fuzzy match against OCPL branch keywords (for library variants)
 * 3. Substring match for partial venue name variations
 */
export function lookupVenueUrl(
  locationName: string | undefined
): VenueUrlEntry | undefined {
  if (!locationName) return undefined;

  const normalized = locationName.toLowerCase().trim();

  // 1. Exact match in independent libraries
  if (INDEPENDENT_LIBRARIES[normalized]) {
    const entry = INDEPENDENT_LIBRARIES[normalized];
    return { url: entry.url, websiteURL: entry.websiteURL ?? entry.url };
  }

  // 2. Exact match in non-library venues
  if (NON_LIBRARY_VENUES[normalized]) {
    return NON_LIBRARY_VENUES[normalized];
  }

  // 3. OCPL branch matching — check if any branch keyword appears in the name
  // This handles variants like "Costa Mesa Donald Dungan Library"
  if (normalized.includes("library")) {
    for (const [keyword, slug] of Object.entries(OCPL_BRANCHES)) {
      if (normalized.includes(keyword)) {
        const url = ocplUrl(slug);
        return { url, websiteURL: url };
      }
    }
  }

  // 4. Partial/fuzzy match for non-library venues
  for (const [key, entry] of Object.entries(NON_LIBRARY_VENUES)) {
    // Check if the venue name contains the key or vice versa
    if (normalized.includes(key) || key.includes(normalized)) {
      return entry;
    }
  }

  // 5. Partial match for independent libraries
  for (const [key, entry] of Object.entries(INDEPENDENT_LIBRARIES)) {
    if (normalized.includes(key) || key.includes(normalized)) {
      return { url: entry.url, websiteURL: entry.websiteURL ?? entry.url };
    }
  }

  return undefined;
}
