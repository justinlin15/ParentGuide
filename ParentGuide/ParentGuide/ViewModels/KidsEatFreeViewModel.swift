//
//  KidsEatFreeViewModel.swift
//  ParentGuide
//

import Foundation

@Observable
class KidsEatFreeViewModel {
    var restaurants: [KidsEatFreeRestaurant] = []
    var filteredRestaurants: [KidsEatFreeRestaurant] = []
    var selectedCities: Set<String> = []
    var selectedDays: Set<String> = []
    var searchText = ""
    var allCities: [String] = []
    var isLoading = false
    var errorMessage: String?
    var showFilter = false

    var usePreviewData = false

    static let allDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var activeFilterCount: Int {
        selectedCities.count + selectedDays.count
    }

    func loadRestaurants() async {
        isLoading = true

        if usePreviewData {
            restaurants = PreviewData.sampleRestaurants
            extractCities()
            applyFilter()
            isLoading = false
            return
        }

        do {
            let allRestaurants = try await GuideService.shared.fetchKidsEatFreeRestaurants()
            let metroId = MetroService.shared.selectedMetro.id
            // Records with nil metro are legacy OC data — treat as "los-angeles"
            restaurants = allRestaurants.filter { ($0.metro ?? "los-angeles") == metroId }
        } catch {
            errorMessage = error.localizedDescription
        }

        // Fallback: use bundled data if CloudKit returned nothing
        if restaurants.isEmpty {
            let metroId = MetroService.shared.selectedMetro.id
            restaurants = Self.bundledRestaurants.filter { ($0.metro ?? "los-angeles") == metroId }
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

    func toggleDay(_ day: String) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
        applyFilter()
    }

    func clearFilter() {
        selectedCities.removeAll()
        selectedDays.removeAll()
        applyFilter()
    }

    func applyFilter() {
        var result = restaurants

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Filter by city
        if !selectedCities.isEmpty {
            result = result.filter { restaurant in
                restaurant.cities.contains { selectedCities.contains($0) }
            }
        }

        // Filter by day of week
        if !selectedDays.isEmpty {
            result = result.filter { restaurant in
                let details = restaurant.dealDetails.lowercased()
                if details.contains("every day") || details.contains("everyday") { return true }
                return selectedDays.contains { details.contains($0.lowercased()) }
            }
        }

        filteredRestaurants = result
    }

    private func extractCities() {
        let citySet = Set(restaurants.flatMap { $0.cities })
        allCities = citySet.sorted()
    }

    // MARK: - Bundled Fallback Data

    static let bundledRestaurants: [KidsEatFreeRestaurant] = [

        // ───── Los Angeles / Orange County ─────

        KidsEatFreeRestaurant(
            id: "b-kef-la-01", name: "Denny's",
            cities: ["Tustin", "Santa Ana", "Anaheim", "Los Angeles", "Burbank", "Long Beach"],
            dealDetails: "Kids 10 & under eat free on Tuesdays from 4–10 PM with purchase of an adult entrée. Limit two free kids meals per adult entrée.",
            imageURL: nil, websiteURL: "https://www.dennys.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 0, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-02", name: "IKEA",
            cities: ["Costa Mesa", "Burbank", "Carson"],
            dealDetails: "Free kids meal for children 12 & under with purchase of an adult entrée on Wednesdays. Kids crafts on Wednesday evenings at select locations.",
            imageURL: nil, websiteURL: "https://www.ikea.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 1, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-03", name: "Red Robin",
            cities: ["Brea", "Torrance", "Lakewood", "West Covina", "Burbank"],
            dealDetails: "Kids eat free every day with purchase of an adult entrée and a drink. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.redrobin.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 2, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-04", name: "Mimi's Cafe",
            cities: ["Tustin", "Brea", "Monrovia", "Torrance"],
            dealDetails: "Kids 12 & under eat free on Tuesdays from 4 PM to close with purchase of an adult entrée.",
            imageURL: nil, websiteURL: "https://www.mimiscafe.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 3, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-05", name: "Chili's Grill & Bar",
            cities: ["Anaheim", "Cerritos", "Huntington Beach", "Pasadena", "West Covina"],
            dealDetails: "Kids eat free with every adult entrée purchase. Available all day, every day. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.chilis.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 4, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-06", name: "CiCi's Pizza",
            cities: ["Anaheim", "Fullerton", "Riverside"],
            dealDetails: "Kids 3 & under eat free from the buffet with a paying adult. Ages 4–12 enjoy discounted buffet pricing all day, every day.",
            imageURL: nil, websiteURL: "https://www.cicis.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 5, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-07", name: "Bob's Big Boy",
            cities: ["Burbank", "Calimesa"],
            dealDetails: "Kids 10 & under eat free on Sundays with purchase of an adult entrée. Dine-in only. Limit one free kids meal per adult.",
            imageURL: nil, websiteURL: "https://www.bfrg.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 6, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-08", name: "Ruby's Diner",
            cities: ["Anaheim", "Brea", "Corona Del Mar", "Costa Mesa", "Laguna Beach", "San Clemente", "Tustin"],
            dealDetails: "Kids eat free on Tuesday nights from 4 PM until close with purchase of an adult entrée.",
            imageURL: nil, websiteURL: "https://www.rubys.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 7, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-09", name: "Claim Jumper",
            cities: ["Brea", "Irvine", "Torrance"],
            dealDetails: "Kids 12 & under eat free on Tuesdays with purchase of an adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.claimjumper.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 8, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-10", name: "Avila's El Ranchito",
            cities: ["Orange", "Laguna Niguel", "Lake Forest", "Foothill Ranch", "San Clemente", "Santa Ana"],
            dealDetails: "Orange, Lake Forest, Laguna Niguel: Kids eat free on Mondays from 4–10 PM. Foothill Ranch: Kids eat free on Sundays. San Clemente & Santa Ana: Kids eat free on Wednesdays 4–10 PM.",
            imageURL: nil, websiteURL: "https://www.avilaselranchito.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 9, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-11", name: "Wienerschnitzel",
            cities: ["Anaheim", "Costa Mesa", "Fullerton", "Orange", "Santa Ana"],
            dealDetails: "Kids meals starting at $1.99 with purchase of an adult combo. Available every day at participating locations.",
            imageURL: nil, websiteURL: "https://www.wienerschnitzel.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 10, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-la-12", name: "Polly's Pies",
            cities: ["Costa Mesa", "Fullerton", "Huntington Beach", "Norco"],
            dealDetails: "Kids 10 & under eat free on Mondays with purchase of an adult entrée. Dine-in only. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.pollyspies.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 11, metro: "los-angeles", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        // ───── New York / Tri-State ─────

        KidsEatFreeRestaurant(
            id: "b-kef-ny-01", name: "IKEA",
            cities: ["Brooklyn", "Paramus"],
            dealDetails: "Free kids meal for children 12 & under with purchase of an adult entrée at the IKEA Restaurant, available every day.",
            imageURL: nil, websiteURL: "https://www.ikea.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 0, metro: "new-york", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-ny-02", name: "Red Robin",
            cities: ["Wayne", "Brick", "Poughkeepsie"],
            dealDetails: "Kids eat free every day with purchase of an adult entrée and a drink. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.redrobin.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 1, metro: "new-york", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-ny-03", name: "Denny's",
            cities: ["Yonkers", "Flushing", "Edison", "Jersey City"],
            dealDetails: "Kids 10 & under eat free on Tuesdays from 4–10 PM with purchase of an adult entrée. Limit two free kids meals per adult entrée.",
            imageURL: nil, websiteURL: "https://www.dennys.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 2, metro: "new-york", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-ny-04", name: "Bob Evans",
            cities: ["Piscataway", "Flemington", "Middletown"],
            dealDetails: "Kids 12 & under eat free on Tuesdays from 4 PM to close with purchase of an adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.bobevans.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 3, metro: "new-york", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-ny-05", name: "Chili's Grill & Bar",
            cities: ["Brooklyn", "Yonkers", "Wayne", "Edison"],
            dealDetails: "Kids eat free with every adult entrée purchase. Available all day, every day. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.chilis.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 4, metro: "new-york", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-ny-06", name: "Applebee's",
            cities: ["Manhattan", "Brooklyn", "Bronx", "Queens", "Paramus"],
            dealDetails: "Kids eat free on Mondays with purchase of an adult entrée. One free kids meal per adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.applebees.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 5, metro: "new-york", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-ny-07", name: "Friendly's",
            cities: ["Staten Island", "Yonkers", "White Plains", "Hackensack"],
            dealDetails: "Kids eat free on Tuesdays with purchase of an adult entrée. Includes kids drink and sundae.",
            imageURL: nil, websiteURL: "https://www.friendlysrestaurants.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 6, metro: "new-york", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-ny-08", name: "IHOP",
            cities: ["Manhattan", "Brooklyn", "Queens", "Bronx", "Jersey City"],
            dealDetails: "Kids 12 & under eat free from 4–10 PM every day with purchase of an adult entrée. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.ihop.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 7, metro: "new-york", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-ny-09", name: "Moe's Southwest Grill",
            cities: ["Manhattan", "Hoboken", "Stamford"],
            dealDetails: "Kids eat free on Sundays with purchase of an adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.moes.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 8, metro: "new-york", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-ny-10", name: "Steak 'n Shake",
            cities: ["Manhattan", "Newark", "Edison"],
            dealDetails: "Kids eat free on weekends (Saturday and Sunday) with purchase of an adult entrée. Ages 12 & under.",
            imageURL: nil, websiteURL: "https://www.steaknshake.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 9, metro: "new-york", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        // ───── Dallas-Fort Worth ─────

        KidsEatFreeRestaurant(
            id: "b-kef-dal-01", name: "Denny's",
            cities: ["Dallas", "Fort Worth", "Arlington", "Plano", "Irving"],
            dealDetails: "Kids 10 & under eat free on Tuesdays from 4–10 PM with purchase of an adult entrée. Limit two free kids meals per adult entrée.",
            imageURL: nil, websiteURL: "https://www.dennys.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 0, metro: "dallas", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-dal-02", name: "Red Robin",
            cities: ["Plano", "Arlington", "Frisco", "Lewisville"],
            dealDetails: "Kids eat free every day with purchase of an adult entrée and a drink. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.redrobin.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 1, metro: "dallas", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-dal-03", name: "CiCi's Pizza",
            cities: ["Dallas", "Fort Worth", "Garland", "Mesquite", "Irving"],
            dealDetails: "Kids 3 & under eat free from the buffet with a paying adult. Ages 4–12 enjoy discounted buffet pricing all day, every day.",
            imageURL: nil, websiteURL: "https://www.cicis.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 2, metro: "dallas", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-dal-04", name: "Luby's",
            cities: ["Dallas", "Fort Worth", "Garland", "Richardson"],
            dealDetails: "Kids 10 & under eat free every day with purchase of an adult meal. Choose from select kids menu items.",
            imageURL: nil, websiteURL: "https://www.lubys.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 3, metro: "dallas", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-dal-05", name: "Jason's Deli",
            cities: ["Dallas", "Plano", "Fort Worth", "Richardson", "Frisco"],
            dealDetails: "Kids 12 & under eat free on Sundays and Tuesdays with purchase of an adult entrée. Includes drink and dessert. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.jasonsdeli.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 4, metro: "dallas", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-dal-06", name: "Chili's Grill & Bar",
            cities: ["Dallas", "Fort Worth", "Plano", "Arlington", "McKinney"],
            dealDetails: "Kids eat free with every adult entrée purchase. Available all day, every day. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.chilis.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 5, metro: "dallas", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-dal-07", name: "IKEA",
            cities: ["Frisco", "Grand Prairie"],
            dealDetails: "Free kids meal for children 12 & under with purchase of an adult entrée at the IKEA Restaurant, available every day.",
            imageURL: nil, websiteURL: "https://www.ikea.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 6, metro: "dallas", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-dal-08", name: "Dickey's Barbecue Pit",
            cities: ["Dallas", "Fort Worth", "Plano", "Allen", "McKinney"],
            dealDetails: "Kids 12 & under eat free on Sundays with purchase of an adult plate. Dine-in only. Limit one free kids meal per adult.",
            imageURL: nil, websiteURL: "https://www.dickeys.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 7, metro: "dallas", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-dal-09", name: "Moe's Southwest Grill",
            cities: ["Dallas", "Plano", "Irving"],
            dealDetails: "Kids eat free on Sundays with purchase of an adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.moes.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 8, metro: "dallas", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-dal-10", name: "Applebee's",
            cities: ["Dallas", "Fort Worth", "Arlington", "Mesquite", "Grand Prairie"],
            dealDetails: "Kids eat free on Mondays with purchase of an adult entrée. One free kids meal per adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.applebees.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 9, metro: "dallas", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        // ───── Chicago ─────

        KidsEatFreeRestaurant(
            id: "b-kef-chi-01", name: "Portillo's",
            cities: ["Chicago", "Schaumburg", "Oak Brook", "Naperville", "Tinley Park"],
            dealDetails: "Kids 10 & under eat free on Tuesdays from 5–8 PM with purchase of an adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.portillos.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 0, metro: "chicago", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-chi-02", name: "IKEA",
            cities: ["Schaumburg", "Bolingbrook"],
            dealDetails: "Free kids meal for children 12 & under with purchase of an adult entrée at the IKEA Restaurant, available every day.",
            imageURL: nil, websiteURL: "https://www.ikea.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 1, metro: "chicago", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-chi-03", name: "Red Robin",
            cities: ["Schaumburg", "Orland Park", "Gurnee", "Naperville"],
            dealDetails: "Kids eat free every day with purchase of an adult entrée and a drink. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.redrobin.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 2, metro: "chicago", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-chi-04", name: "Denny's",
            cities: ["Chicago", "Skokie", "Elk Grove Village", "Aurora"],
            dealDetails: "Kids 10 & under eat free on Tuesdays from 4–10 PM with purchase of an adult entrée. Limit two free kids meals per adult entrée.",
            imageURL: nil, websiteURL: "https://www.dennys.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 3, metro: "chicago", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-chi-05", name: "Chili's Grill & Bar",
            cities: ["Chicago", "Schaumburg", "Naperville", "Orland Park", "Joliet"],
            dealDetails: "Kids eat free with every adult entrée purchase. Available all day, every day. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.chilis.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 4, metro: "chicago", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-chi-06", name: "Jason's Deli",
            cities: ["Chicago", "Schaumburg", "Downers Grove", "Naperville"],
            dealDetails: "Kids 12 & under eat free on Sundays and Tuesdays with purchase of an adult entrée. Includes drink and dessert.",
            imageURL: nil, websiteURL: "https://www.jasonsdeli.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 5, metro: "chicago", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-chi-07", name: "Moe's Southwest Grill",
            cities: ["Chicago", "Naperville", "Schaumburg"],
            dealDetails: "Kids eat free on Sundays with purchase of an adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.moes.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 6, metro: "chicago", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-chi-08", name: "Steak 'n Shake",
            cities: ["Chicago", "Joliet", "Bolingbrook", "Tinley Park"],
            dealDetails: "Kids eat free on weekends (Saturday and Sunday) with purchase of an adult entrée. Ages 12 & under.",
            imageURL: nil, websiteURL: "https://www.steaknshake.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 7, metro: "chicago", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-chi-09", name: "Applebee's",
            cities: ["Chicago", "Schaumburg", "Orland Park", "Aurora", "Joliet"],
            dealDetails: "Kids eat free on Mondays with purchase of an adult entrée. One free kids meal per adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.applebees.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 8, metro: "chicago", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-chi-10", name: "Bob Evans",
            cities: ["Joliet", "Bolingbrook", "Romeoville"],
            dealDetails: "Kids 12 & under eat free on Tuesdays from 4 PM to close with purchase of an adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.bobevans.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 9, metro: "chicago", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        // ───── Atlanta ─────

        KidsEatFreeRestaurant(
            id: "b-kef-atl-01", name: "Red Robin",
            cities: ["Kennesaw", "Buford", "Duluth", "Newnan"],
            dealDetails: "Kids eat free every day with purchase of an adult entrée and a drink. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.redrobin.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 0, metro: "atlanta", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-atl-02", name: "Denny's",
            cities: ["Atlanta", "Decatur", "Marietta", "College Park", "Duluth"],
            dealDetails: "Kids 10 & under eat free on Tuesdays from 4–10 PM with purchase of an adult entrée. Limit two free kids meals per adult entrée.",
            imageURL: nil, websiteURL: "https://www.dennys.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 1, metro: "atlanta", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-atl-03", name: "CiCi's Pizza",
            cities: ["Atlanta", "Decatur", "Marietta", "Kennesaw", "Lawrenceville"],
            dealDetails: "Kids 3 & under eat free from the buffet with a paying adult. Ages 4–12 enjoy discounted buffet pricing all day, every day.",
            imageURL: nil, websiteURL: "https://www.cicis.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 2, metro: "atlanta", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-atl-04", name: "IKEA",
            cities: ["Atlanta"],
            dealDetails: "Free kids meal for children 12 & under with purchase of an adult entrée at the IKEA Restaurant, available every day.",
            imageURL: nil, websiteURL: "https://www.ikea.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 3, metro: "atlanta", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-atl-05", name: "Chili's Grill & Bar",
            cities: ["Atlanta", "Marietta", "Kennesaw", "Buford", "Douglasville"],
            dealDetails: "Kids eat free with every adult entrée purchase. Available all day, every day. One free kids meal per adult entrée.",
            imageURL: nil, websiteURL: "https://www.chilis.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 4, metro: "atlanta", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-atl-06", name: "Jason's Deli",
            cities: ["Atlanta", "Marietta", "Alpharetta", "Duluth"],
            dealDetails: "Kids 12 & under eat free on Sundays and Tuesdays with purchase of an adult entrée. Includes drink and dessert.",
            imageURL: nil, websiteURL: "https://www.jasonsdeli.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 5, metro: "atlanta", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-atl-07", name: "Applebee's",
            cities: ["Atlanta", "Marietta", "Kennesaw", "Lawrenceville", "Douglasville"],
            dealDetails: "Kids eat free on Mondays with purchase of an adult entrée. One free kids meal per adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.applebees.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 6, metro: "atlanta", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-atl-08", name: "Moe's Southwest Grill",
            cities: ["Atlanta", "Marietta", "Alpharetta", "Roswell", "Kennesaw"],
            dealDetails: "Kids eat free on Sundays with purchase of an adult entrée. Dine-in only.",
            imageURL: nil, websiteURL: "https://www.moes.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 7, metro: "atlanta", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-atl-09", name: "Steak 'n Shake",
            cities: ["Atlanta", "Marietta", "Kennesaw", "Duluth"],
            dealDetails: "Kids eat free on weekends (Saturday and Sunday) with purchase of an adult entrée. Ages 12 & under.",
            imageURL: nil, websiteURL: "https://www.steaknshake.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 8, metro: "atlanta", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),

        KidsEatFreeRestaurant(
            id: "b-kef-atl-10", name: "Dickey's Barbecue Pit",
            cities: ["Atlanta", "Marietta", "Kennesaw", "Buford"],
            dealDetails: "Kids 12 & under eat free on Sundays with purchase of an adult plate. Dine-in only. Limit one free kids meal per adult.",
            imageURL: nil, websiteURL: "https://www.dickeys.com", phoneNumber: nil,
            address: nil, isActive: true, sortOrder: 9, metro: "atlanta", source: "bundled",
            createdAt: Date(), modifiedAt: Date()),
    ]
}
