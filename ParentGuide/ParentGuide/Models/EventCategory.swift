//
//  EventCategory.swift
//  ParentGuide
//

import SwiftUI

nonisolated enum EventCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case storytime = "Storytime"
    case farmersMarket = "Farmers Market"
    case freeMovie = "Free Movie"
    case toddlerActivity = "Toddler Activity"
    case craft = "Craft"
    case music = "Music"
    case fireStationTour = "Fire Station Tour"
    case museum = "Museum"
    case outdoorAdventure = "Outdoor"
    case food = "Food & Dining"
    case sports = "Sports"
    case education = "Education"
    case festival = "Festival"
    case seasonal = "Seasonal"
    case subscriberMeetup = "Subscriber Meetup"
    case other = "Other"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .storytime, .farmersMarket, .outdoorAdventure:
            return Color("EventGreen")
        case .freeMovie, .music, .museum, .education:
            return Color("EventBlue")
        case .toddlerActivity, .craft, .festival, .seasonal, .subscriberMeetup:
            return Color("EventPink")
        case .fireStationTour, .sports, .other:
            return Color("EventGray")
        case .food:
            return Color("EventOrange")
        }
    }

    var iconName: String {
        switch self {
        case .storytime: return "book.fill"
        case .farmersMarket: return "leaf.fill"
        case .freeMovie: return "film.fill"
        case .toddlerActivity: return "figure.and.child.holdinghands"
        case .craft: return "paintbrush.fill"
        case .music: return "music.note"
        case .fireStationTour: return "flame.fill"
        case .museum: return "building.columns.fill"
        case .outdoorAdventure: return "sun.max.fill"
        case .food: return "fork.knife"
        case .sports: return "sportscourt.fill"
        case .education: return "graduationcap.fill"
        case .festival: return "party.popper.fill"
        case .seasonal: return "star.fill"
        case .subscriberMeetup: return "person.3.fill"
        case .other: return "calendar"
        }
    }
}
