import Foundation

/// Types of exercises that can be classified
public enum ExerciseType: String, CaseIterable, Codable {
    case pushup = "Pushup"
    case squat = "Squat"
    case jumpingJack = "Jumping Jack"
    case plank = "Plank"
    case rest = "Rest"
    case unknown = "Unknown"
    
    public var caloriesPerRep: Double {
        switch self {
        case .pushup: return 0.5
        case .squat: return 0.4
        case .jumpingJack: return 0.2
        case .plank: return 0.1
        case .rest, .unknown: return 0.0
        }
    }
    
    public var emoji: String {
        switch self {
        case .pushup: return "💪"
        case .squat: return "🦵"
        case .jumpingJack: return "⭐"
        case .plank: return "🧘"
        case .rest: return "😴"
        case .unknown: return "❓"
        }
    }
}

/// Result of exercise classification
public struct ClassificationResult {
    public let exerciseType: ExerciseType
    public let confidence: Double
    public let timestamp: Date
    
    public init(exerciseType: ExerciseType, confidence: Double, timestamp: Date = Date()) {
        self.exerciseType = exerciseType
        self.confidence = confidence
        self.timestamp = timestamp
    }
    
    public var isHighConfidence: Bool {
        confidence >= 0.75
    }
}
