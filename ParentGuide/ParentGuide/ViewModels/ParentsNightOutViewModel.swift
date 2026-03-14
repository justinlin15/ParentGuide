//
//  ParentsNightOutViewModel.swift
//  ParentGuide
//

import Foundation

@Observable
class ParentsNightOutViewModel {
    var providers: [ParentsNightOutProvider] = []
    var filteredProviders: [ParentsNightOutProvider] = []
    var selectedCities: Set<String> = []
    var searchText = ""
    var onlyWithPromo = false
    var allCities: [String] = []
    var isLoading = false
    var errorMessage: String?
    var showFilter = false

    var usePreviewData = false

    var activeFilterCount: Int {
        selectedCities.count + (onlyWithPromo ? 1 : 0)
    }

    func loadProviders() async {
        isLoading = true

        if usePreviewData {
            providers = PreviewData.sampleProviders
            extractCities()
            applyFilter()
            isLoading = false
            return
        }

        do {
            let allProviders = try await GuideService.shared.fetchParentsNightOutProviders()
            let metroId = MetroService.shared.selectedMetro.id
            // Records with nil metro are legacy OC data — treat as "los-angeles"
            let cloudRecords = allProviders.filter { ($0.metro ?? "los-angeles") == metroId }
            // Merge bundled image URLs into CloudKit records that are missing them
            providers = Self.enrichWithBundledImages(cloudRecords)
        } catch {
            errorMessage = error.localizedDescription
        }

        // Fallback: use bundled data if CloudKit returned nothing
        if providers.isEmpty {
            let metroId = MetroService.shared.selectedMetro.id
            providers = Self.bundledProviders.filter { ($0.metro ?? "los-angeles") == metroId }
        }

        extractCities()
        applyFilter()
        isLoading = false
    }

    func toggleCity(_ city: String) {
        if selectedCities.contains(city) {
            selectedCities.remove(city)
        } else {
            selectedCities.insert(city)
        }
        applyFilter()
    }

    func clearFilter() {
        selectedCities.removeAll()
        onlyWithPromo = false
        applyFilter()
    }

    func applyFilter() {
        var result = providers

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        if !selectedCities.isEmpty {
            result = result.filter { provider in
                provider.cities.contains { selectedCities.contains($0) }
            }
        }

        if onlyWithPromo {
            result = result.filter { $0.promoCode != nil && !($0.promoCode?.isEmpty ?? true) }
        }

        filteredProviders = result
    }

    private func extractCities() {
        let citySet = Set(providers.flatMap { $0.cities })
        allCities = citySet.sorted()
    }

    // MARK: - Image Enrichment

    /// Merge bundled image URLs into CloudKit records that have nil/empty imageURL.
    private static func enrichWithBundledImages(_ records: [ParentsNightOutProvider]) -> [ParentsNightOutProvider] {
        let bundledByName = Dictionary(
            bundledProviders.map { ($0.name.lowercased(), $0.imageURL) },
            uniquingKeysWith: { first, _ in first }
        )

        return records.map { provider in
            if provider.imageURL == nil || provider.imageURL?.isEmpty == true,
               let bundledURL = bundledByName[provider.name.lowercased()],
               let url = bundledURL {
                return provider.withImageURL(url)
            }
            return provider
        }
    }

    // MARK: - Bundled Fallback Data

    static let bundledProviders: [ParentsNightOutProvider] = [

        // ───── Los Angeles ─────

        ParentsNightOutProvider(
            id: "b-pno-la-02", name: "My Gym",
            cities: ["Pasadena", "Sherman Oaks", "Santa Monica"],
            providerDescription: "Monthly Parents Night Out events featuring gymnastics, games, pizza, and a movie on the big screen. Drop off your kids for 3 hours of active supervised fun.",
            ageRequirement: "Ages 3–9", pricing: "$30–$40/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/8363102/pexels-photo-8363102.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.mygym.com", isActive: true, sortOrder: 0,
            metro: "los-angeles", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-la-03", name: "The Little Gym",
            cities: ["Encino", "Manhattan Beach", "Culver City"],
            providerDescription: "Parents Night Out events held monthly on Friday or Saturday evenings. Kids enjoy gymnastics, games, arts and crafts, and pizza in a safe, supervised environment.",
            ageRequirement: "Ages 3–8", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:30 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e2/Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg/400px-Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg",
            externalURL: "https://www.thelittlegym.com", isActive: true, sortOrder: 1,
            metro: "los-angeles", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-la-04", name: "Pump It Up",
            cities: ["Torrance", "Glendale"],
            providerDescription: "Parents Night Out bounce events on select Friday and Saturday evenings. Kids bounce on giant inflatables, play games, and enjoy pizza and drinks for 3 hours.",
            ageRequirement: "Ages 4–12", pricing: "$25–$30/child",
            schedule: "Select Friday & Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/Bounce_%28482878372%29.jpg/400px-Bounce_%28482878372%29.jpg",
            externalURL: "https://www.pumpitupparty.com", isActive: true, sortOrder: 2,
            metro: "los-angeles", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-la-09", name: "Sky Zone",
            cities: ["Van Nuys", "Torrance"],
            providerDescription: "Parents Night Out with unlimited trampolines, foam pits, dodgeball, and pizza. Events held monthly on Friday or Saturday evenings. Advance registration required.",
            ageRequirement: "Ages 5–14", pricing: "$30–$40/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/Children_on_trampoline.jpg/400px-Children_on_trampoline.jpg",
            externalURL: "https://www.skyzone.com", isActive: true, sortOrder: 3,
            metro: "los-angeles", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        // ───── Orange County ─────

        ParentsNightOutProvider(
            id: "b-pno-oc-01", name: "KidsPark",
            cities: ["Irvine", "Aliso Viejo", "Mission Viejo"],
            providerDescription: "Licensed drop-in childcare center. Open evenings for Parents Night Out. Activities include arts and crafts, games, movies, and supervised free play. No reservations needed.",
            ageRequirement: "Ages 2–12, potty trained", pricing: "$12–$15/hour",
            schedule: "Open daily, evenings until 10:00 PM. No reservation needed.",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/8535592/pexels-photo-8535592.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.kidspark.com", isActive: true, sortOrder: 0,
            metro: "orange-county", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-oc-02", name: "My Gym",
            cities: ["Costa Mesa", "Laguna Niguel", "Mission Viejo", "Yorba Linda"],
            providerDescription: "Monthly Parents Night Out events featuring gymnastics, games, pizza, and a movie on the big screen. Drop off your kids for 3 hours of active supervised fun.",
            ageRequirement: "Ages 3–9", pricing: "$30–$40/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/8363102/pexels-photo-8363102.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.mygym.com", isActive: true, sortOrder: 1,
            metro: "orange-county", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-oc-03", name: "The Little Gym",
            cities: ["Irvine", "Brea", "Rancho Santa Margarita"],
            providerDescription: "Parents Night Out events held monthly on Friday or Saturday evenings. Kids enjoy gymnastics, games, arts and crafts, and pizza in a safe, supervised environment.",
            ageRequirement: "Ages 3–8", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:30 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e2/Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg/400px-Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg",
            externalURL: "https://www.thelittlegym.com", isActive: true, sortOrder: 2,
            metro: "orange-county", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-oc-04", name: "Pretend City Children's Museum",
            cities: ["Irvine"],
            providerDescription: "Monthly Parents Night Out at the museum. Kids explore all 17 interactive rooms after hours with supervised activities, crafts, dinner, and a movie. Registration required.",
            ageRequirement: "Ages 3–8", pricing: "$40–$50/child",
            schedule: "Monthly, Friday evenings, 6:00–10:00 PM. Registration required.",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2d/Pretend-city-imagination-playground.jpg/400px-Pretend-city-imagination-playground.jpg",
            externalURL: "https://www.pretendcity.org", isActive: true, sortOrder: 3,
            metro: "orange-county", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-oc-05", name: "Karate OC",
            cities: ["Fullerton", "Placentia"],
            providerDescription: "Games, obstacle courses, laser tag, pizza, drinks, and movies! A high-energy Parents Night Out for kids who love action and adventure.",
            ageRequirement: "Ages 5+", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/7045594/pexels-photo-7045594.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.karateoc.com", isActive: true, sortOrder: 4,
            metro: "orange-county", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-oc-06", name: "Sweet Peas Gymnastics",
            cities: ["Rancho Mission Viejo"],
            providerDescription: "Offered every Saturday night. Kids enjoy an evening of gymnastics, obstacle courses, trampolines, bounce houses, games, crafts, and more!",
            ageRequirement: "Ages 3–13, potty trained", pricing: "$27–$30/child",
            schedule: "Every Saturday, 5:30–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4b/Cartwheel.jpg/400px-Cartwheel.jpg",
            externalURL: "https://www.sweetpeasgymnastics.com", isActive: true, sortOrder: 5,
            metro: "orange-county", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-oc-07", name: "Urban Air Adventure Park",
            cities: ["Anaheim"],
            providerDescription: "Parents Night Out events featuring trampolines, climbing walls, dodgeball, obstacle courses, pizza, and drinks. Kids get the run of the park for 3 hours.",
            ageRequirement: "Ages 5–13", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/2008-08-05_Climber_at_Vertical_Edge.jpg/400px-2008-08-05_Climber_at_Vertical_Edge.jpg",
            externalURL: "https://www.urbanair.com", isActive: true, sortOrder: 6,
            metro: "orange-county", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-oc-08", name: "Sky Zone",
            cities: ["Anaheim"],
            providerDescription: "Parents Night Out with unlimited trampolines, foam pits, dodgeball, and pizza. Events held monthly on Friday or Saturday evenings. Advance registration required.",
            ageRequirement: "Ages 5–14", pricing: "$30–$40/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/Children_on_trampoline.jpg/400px-Children_on_trampoline.jpg",
            externalURL: "https://www.skyzone.com", isActive: true, sortOrder: 7,
            metro: "orange-county", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        // ───── New York / Tri-State ─────

        ParentsNightOutProvider(
            id: "b-pno-ny-01", name: "The Little Gym",
            cities: ["Manhattan", "Brooklyn", "Westchester"],
            providerDescription: "Monthly Parents Night Out with gymnastics, games, arts and crafts, and pizza in a safe, supervised environment. Advance registration required.",
            ageRequirement: "Ages 3–8", pricing: "$35–$50/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:30 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e2/Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg/400px-Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg",
            externalURL: "https://www.thelittlegym.com", isActive: true, sortOrder: 0,
            metro: "new-york", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-ny-02", name: "My Gym",
            cities: ["Manhattan", "Park Slope", "Hoboken"],
            providerDescription: "Monthly Parents Night Out events featuring gymnastics, games, pizza, and a movie on the big screen. Drop off your kids for 3 hours of active supervised fun.",
            ageRequirement: "Ages 3–9", pricing: "$40–$50/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/8363102/pexels-photo-8363102.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.mygym.com", isActive: true, sortOrder: 1,
            metro: "new-york", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-ny-03", name: "Sky Zone",
            cities: ["Deer Park", "New Rochelle", "College Point"],
            providerDescription: "Parents Night Out with unlimited trampolines, foam pits, dodgeball, and pizza. Events held monthly on Friday or Saturday evenings.",
            ageRequirement: "Ages 5–14", pricing: "$35–$45/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/Children_on_trampoline.jpg/400px-Children_on_trampoline.jpg",
            externalURL: "https://www.skyzone.com", isActive: true, sortOrder: 2,
            metro: "new-york", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-ny-04", name: "Urban Air Adventure Park",
            cities: ["Yonkers", "White Plains", "Wayne"],
            providerDescription: "Parents Night Out events featuring trampolines, climbing walls, dodgeball, obstacle courses, pizza, and drinks. Kids get the run of the park for 3 hours.",
            ageRequirement: "Ages 5–13", pricing: "$30–$40/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/2008-08-05_Climber_at_Vertical_Edge.jpg/400px-2008-08-05_Climber_at_Vertical_Edge.jpg",
            externalURL: "https://www.urbanair.com", isActive: true, sortOrder: 3,
            metro: "new-york", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-ny-05", name: "Kidville",
            cities: ["Manhattan", "Brooklyn", "Hoboken"],
            providerDescription: "Parents Night Out events with music, art, gymnastics, and imaginative play. Dinner and snacks provided. Advance registration required.",
            ageRequirement: "Ages 2–6", pricing: "$45–$60/child",
            schedule: "Monthly, Friday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/8422248/pexels-photo-8422248.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.kidville.com", isActive: true, sortOrder: 4,
            metro: "new-york", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-ny-06", name: "Chelsea Piers",
            cities: ["Manhattan"],
            providerDescription: "Kids Night Out at Chelsea Piers Field House. Children enjoy sports, games, swimming, and pizza in a supervised environment while parents enjoy an evening out.",
            ageRequirement: "Ages 3–12", pricing: "$50–$75/child",
            schedule: "Monthly, Saturday evenings, 6:00–10:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Chelsea_Piers.jpg/400px-Chelsea_Piers.jpg",
            externalURL: "https://www.chelseapiers.com", isActive: true, sortOrder: 5,
            metro: "new-york", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-ny-07", name: "Pump It Up",
            cities: ["Paramus", "Yonkers"],
            providerDescription: "Parents Night Out bounce events on select Friday and Saturday evenings. Kids bounce on giant inflatables, play games, and enjoy pizza and drinks.",
            ageRequirement: "Ages 4–12", pricing: "$30–$40/child",
            schedule: "Select Friday & Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/Bounce_%28482878372%29.jpg/400px-Bounce_%28482878372%29.jpg",
            externalURL: "https://www.pumpitupparty.com", isActive: true, sortOrder: 6,
            metro: "new-york", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        // ───── Dallas-Fort Worth ─────

        ParentsNightOutProvider(
            id: "b-pno-dal-01", name: "My Gym",
            cities: ["Plano", "Frisco", "Dallas", "Southlake"],
            providerDescription: "Monthly Parents Night Out events featuring gymnastics, games, pizza, and a movie. Drop off your kids for 3 hours of active supervised fun.",
            ageRequirement: "Ages 3–9", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/8363102/pexels-photo-8363102.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.mygym.com", isActive: true, sortOrder: 0,
            metro: "dallas", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-dal-02", name: "The Little Gym",
            cities: ["Plano", "Allen", "Flower Mound", "Southlake"],
            providerDescription: "Monthly Parents Night Out with gymnastics, games, arts and crafts, and pizza. Advance registration required.",
            ageRequirement: "Ages 3–8", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:30 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e2/Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg/400px-Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg",
            externalURL: "https://www.thelittlegym.com", isActive: true, sortOrder: 1,
            metro: "dallas", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-dal-03", name: "Urban Air Adventure Park",
            cities: ["Dallas", "Fort Worth", "Frisco", "Arlington", "Mansfield"],
            providerDescription: "Parents Night Out events with trampolines, climbing walls, dodgeball, obstacle courses, pizza, and drinks. Kids get the run of the park.",
            ageRequirement: "Ages 5–13", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/2008-08-05_Climber_at_Vertical_Edge.jpg/400px-2008-08-05_Climber_at_Vertical_Edge.jpg",
            externalURL: "https://www.urbanair.com", isActive: true, sortOrder: 2,
            metro: "dallas", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-dal-04", name: "Sky Zone",
            cities: ["Plano", "Fort Worth", "McKinney"],
            providerDescription: "Parents Night Out with unlimited trampolines, foam pits, dodgeball, and pizza. Events held monthly on Friday or Saturday evenings.",
            ageRequirement: "Ages 5–14", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/Children_on_trampoline.jpg/400px-Children_on_trampoline.jpg",
            externalURL: "https://www.skyzone.com", isActive: true, sortOrder: 3,
            metro: "dallas", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-dal-05", name: "KidsPark",
            cities: ["Dallas", "Plano", "Richardson"],
            providerDescription: "Licensed drop-in childcare center open evenings for Parents Night Out. Activities include arts and crafts, games, movies, and supervised free play.",
            ageRequirement: "Ages 2–12, potty trained", pricing: "$12–$15/hour",
            schedule: "Open daily, evenings until 10:00 PM. No reservation needed.",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/8535592/pexels-photo-8535592.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.kidspark.com", isActive: true, sortOrder: 4,
            metro: "dallas", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-dal-06", name: "Pump It Up",
            cities: ["Frisco", "Arlington", "McKinney"],
            providerDescription: "Parents Night Out bounce events on select Friday and Saturday evenings. Kids bounce on giant inflatables, play games, and enjoy pizza and drinks.",
            ageRequirement: "Ages 4–12", pricing: "$25–$30/child",
            schedule: "Select Friday & Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/Bounce_%28482878372%29.jpg/400px-Bounce_%28482878372%29.jpg",
            externalURL: "https://www.pumpitupparty.com", isActive: true, sortOrder: 5,
            metro: "dallas", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-dal-07", name: "Kiddo",
            cities: ["Dallas", "Plano"],
            providerDescription: "On-demand babysitting and Parents Night Out services. Book vetted, background-checked sitters through the app for in-home or event-based childcare.",
            ageRequirement: "All ages", pricing: "$18–$25/hour",
            schedule: "Available any evening. Book through the Kiddo app.",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/6986435/pexels-photo-6986435.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.getkiddo.com", isActive: true, sortOrder: 6,
            metro: "dallas", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        // ───── Chicago ─────

        ParentsNightOutProvider(
            id: "b-pno-chi-01", name: "My Gym",
            cities: ["Schaumburg", "Naperville", "Downers Grove", "Libertyville"],
            providerDescription: "Monthly Parents Night Out events featuring gymnastics, games, pizza, and a movie. Drop off your kids for 3 hours of active supervised fun.",
            ageRequirement: "Ages 3–9", pricing: "$30–$40/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/8363102/pexels-photo-8363102.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.mygym.com", isActive: true, sortOrder: 0,
            metro: "chicago", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-chi-02", name: "The Little Gym",
            cities: ["Chicago", "Naperville", "Schaumburg", "Oak Brook"],
            providerDescription: "Monthly Parents Night Out with gymnastics, games, arts and crafts, and pizza in a safe, supervised environment.",
            ageRequirement: "Ages 3–8", pricing: "$30–$40/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:30 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e2/Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg/400px-Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg",
            externalURL: "https://www.thelittlegym.com", isActive: true, sortOrder: 1,
            metro: "chicago", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-chi-03", name: "Sky Zone",
            cities: ["Elmhurst", "Joliet", "Naperville"],
            providerDescription: "Parents Night Out with unlimited trampolines, foam pits, dodgeball, and pizza. Events held monthly on Friday or Saturday evenings.",
            ageRequirement: "Ages 5–14", pricing: "$30–$40/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/Children_on_trampoline.jpg/400px-Children_on_trampoline.jpg",
            externalURL: "https://www.skyzone.com", isActive: true, sortOrder: 2,
            metro: "chicago", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-chi-04", name: "Urban Air Adventure Park",
            cities: ["Schaumburg", "Naperville", "Orland Park"],
            providerDescription: "Parents Night Out events featuring trampolines, climbing walls, dodgeball, obstacle courses, pizza, and drinks. Kids get the run of the park.",
            ageRequirement: "Ages 5–13", pricing: "$30–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/2008-08-05_Climber_at_Vertical_Edge.jpg/400px-2008-08-05_Climber_at_Vertical_Edge.jpg",
            externalURL: "https://www.urbanair.com", isActive: true, sortOrder: 3,
            metro: "chicago", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-chi-05", name: "Pump It Up",
            cities: ["Schaumburg", "Naperville", "Tinley Park"],
            providerDescription: "Parents Night Out bounce events on select Friday and Saturday evenings. Kids bounce on giant inflatables, play games, and enjoy pizza and drinks.",
            ageRequirement: "Ages 4–12", pricing: "$25–$30/child",
            schedule: "Select Friday & Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/Bounce_%28482878372%29.jpg/400px-Bounce_%28482878372%29.jpg",
            externalURL: "https://www.pumpitupparty.com", isActive: true, sortOrder: 4,
            metro: "chicago", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-chi-06", name: "KidsPark",
            cities: ["Chicago", "Naperville"],
            providerDescription: "Licensed drop-in childcare center open evenings for Parents Night Out. Activities include arts and crafts, games, movies, and supervised free play.",
            ageRequirement: "Ages 2–12, potty trained", pricing: "$12–$15/hour",
            schedule: "Open daily, evenings until 10:00 PM. No reservation needed.",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/8535592/pexels-photo-8535592.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.kidspark.com", isActive: true, sortOrder: 5,
            metro: "chicago", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        // ───── Atlanta ─────

        ParentsNightOutProvider(
            id: "b-pno-atl-01", name: "My Gym",
            cities: ["Atlanta", "Roswell", "Kennesaw", "Suwanee"],
            providerDescription: "Monthly Parents Night Out events featuring gymnastics, games, pizza, and a movie. Drop off your kids for 3 hours of active supervised fun.",
            ageRequirement: "Ages 3–9", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://images.pexels.com/photos/8363102/pexels-photo-8363102.jpeg?auto=compress&cs=tinysrgb&w=400",
            externalURL: "https://www.mygym.com", isActive: true, sortOrder: 0,
            metro: "atlanta", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-atl-02", name: "The Little Gym",
            cities: ["Atlanta", "Alpharetta", "Marietta", "Duluth"],
            providerDescription: "Monthly Parents Night Out with gymnastics, games, arts and crafts, and pizza in a safe, supervised environment.",
            ageRequirement: "Ages 3–8", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:30 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e2/Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg/400px-Djeca_gimnasti%C4%8Dari_u_dvorani_Aton_%28Croatia%29.jpg",
            externalURL: "https://www.thelittlegym.com", isActive: true, sortOrder: 1,
            metro: "atlanta", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-atl-03", name: "Urban Air Adventure Park",
            cities: ["Atlanta", "Kennesaw", "Buford", "McDonough"],
            providerDescription: "Parents Night Out events featuring trampolines, climbing walls, dodgeball, obstacle courses, pizza, and drinks. Kids get the run of the park.",
            ageRequirement: "Ages 5–13", pricing: "$25–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/2008-08-05_Climber_at_Vertical_Edge.jpg/400px-2008-08-05_Climber_at_Vertical_Edge.jpg",
            externalURL: "https://www.urbanair.com", isActive: true, sortOrder: 2,
            metro: "atlanta", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-atl-04", name: "Sky Zone",
            cities: ["Roswell", "Kennesaw", "Lawrenceville"],
            providerDescription: "Parents Night Out with unlimited trampolines, foam pits, dodgeball, and pizza. Events held monthly on Friday or Saturday evenings.",
            ageRequirement: "Ages 5–14", pricing: "$30–$35/child",
            schedule: "Monthly, Friday or Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/Children_on_trampoline.jpg/400px-Children_on_trampoline.jpg",
            externalURL: "https://www.skyzone.com", isActive: true, sortOrder: 3,
            metro: "atlanta", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-atl-05", name: "Pump It Up",
            cities: ["Atlanta", "Kennesaw", "Duluth"],
            providerDescription: "Parents Night Out bounce events on select Friday and Saturday evenings. Kids bounce on giant inflatables, play games, and enjoy pizza and drinks.",
            ageRequirement: "Ages 4–12", pricing: "$25–$30/child",
            schedule: "Select Friday & Saturday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/Bounce_%28482878372%29.jpg/400px-Bounce_%28482878372%29.jpg",
            externalURL: "https://www.pumpitupparty.com", isActive: true, sortOrder: 4,
            metro: "atlanta", source: "bundled", createdAt: Date(), modifiedAt: Date()),

        ParentsNightOutProvider(
            id: "b-pno-atl-06", name: "Little Maestros",
            cities: ["Atlanta", "Decatur", "Marietta"],
            providerDescription: "Parents Night Out events with music, art, and imaginative play. Kids enjoy hands-on activities, dinner, and supervised fun while parents enjoy a night out.",
            ageRequirement: "Ages 2–8", pricing: "$30–$40/child",
            schedule: "Monthly, Friday evenings, 6:00–9:00 PM",
            promoCode: nil, promoDetails: nil, imageURL: "https://upload.wikimedia.org/wikipedia/commons/thumb/8/82/Boomwhacker_Level_Concentration_%28248641451%29.jpeg/400px-Boomwhacker_Level_Concentration_%28248641451%29.jpeg",
            externalURL: "https://www.littlemaestros.com", isActive: true, sortOrder: 5,
            metro: "atlanta", source: "bundled", createdAt: Date(), modifiedAt: Date()),
    ]
}
