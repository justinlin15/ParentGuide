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
        case .storytime:
            return Color.eventBlue
        case .farmersMarket:
            return Color.eventGreen
        case .freeMovie:
            return Color.eventPurple
        case .toddlerActivity:
            return Color.eventPink
        case .craft:
            return Color.eventOrange
        case .music:
            return Color.eventPurple
        case .fireStationTour:
            return Color.eventGray
        case .museum:
            return Color.eventBlue
        case .outdoorAdventure:
            return Color.eventGreen
        case .food:
            return Color.eventOrange
        case .sports:
            return Color.eventGreen
        case .education:
            return Color.eventBlue
        case .festival:
            return Color.eventPink
        case .seasonal:
            return Color.brandBlue
        case .subscriberMeetup:
            return Color.brandLavender
        case .other:
            return Color.eventGray
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
