import Foundation
import Combine

/// Main service for text-based exercise classification using CoreML
@MainActor
public class ExerciseClassifierService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentExercise: ExerciseType = .unknown
    @Published public private(set) var confidence: Double = 0.0
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var classificationHistory: [ClassificationResult] = []
    @Published public private(set) var exerciseCounts: [ExerciseType: Int] = [:]
    @Published public private(set) var totalCalories: Double = 0.0
    @Published public private(set) var lastInputText: String = ""
    @Published public private(set) var modelError: String?
    
    // MARK: - Private Properties
    
    private let classifier: ExerciseTextClassifier
    private var useFallback: Bool = true
    
    // MARK: - Initialization
    
    public init(modelName: String? = nil) {
        self.classifier = ExerciseTextClassifier()
        initializeExerciseCounts()
        
        if let modelName = modelName {
            loadModel(named: modelName)
        }
    }
    
    /// Load CoreML model for text classification
    public func loadModel(named modelName: String) {
        do {
            try classifier.loadModel(named: modelName)
            modelError = nil
            useFallback = false
            print("CoreML model '\(modelName)' loaded")
        } catch {
            modelError = error.localizedDescription
            useFallback = true
            print("Using keyword fallback: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Classify exercise from text description
    public func classify(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isProcessing = true
        lastInputText = text
        
        let result: ClassificationResult
        
        if useFallback {
            result = classifier.classifyWithKeywords(text: text)
        } else {
            do {
                result = try classifier.classify(text: text)
            } catch {
                print("Classification error: \(error.localizedDescription)")
                isProcessing = false
                return
            }
        }
        
        updateState(with: result)
        isProcessing = false
    }
    
    /// Classify exercise asynchronously
    public func classifyAsync(text: String) async {
        await MainActor.run {
            classify(text: text)
        }
    }
    
    /// Reset all statistics
    public func reset() {
        classificationHistory.removeAll()
        initializeExerciseCounts()
        totalCalories = 0.0
        currentExercise = .unknown
        confidence = 0.0
        lastInputText = ""
    }
    
    /// Get summary of classifications
    public func getWorkoutSummary() -> WorkoutSummary {
        WorkoutSummary(
            exerciseCounts: exerciseCounts,
            totalCalories: totalCalories,
            duration: calculateWorkoutDuration(),
            classificationHistory: classificationHistory
        )
    }
    
    // MARK: - Private Methods
    
    private func initializeExerciseCounts() {
        exerciseCounts = Dictionary(uniqueKeysWithValues: ExerciseType.allCases.map { ($0, 0) })
    }
    
    private func updateState(with result: ClassificationResult) {
        currentExercise = result.exerciseType
        confidence = result.confidence
        
        if result.isHighConfidence && result.exerciseType != .rest && result.exerciseType != .unknown {
            exerciseCounts[result.exerciseType, default: 0] += 1
            totalCalories += result.exerciseType.caloriesPerRep
        }
        
        classificationHistory.append(result)
        if classificationHistory.count > 100 {
            classificationHistory.removeFirst()
        }
    }
    
    private func calculateWorkoutDuration() -> TimeInterval {
        guard let first = classificationHistory.first,
              let last = classificationHistory.last else {
            return 0
        }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }
}

// MARK: - Workout Summary

public struct WorkoutSummary {
    public let exerciseCounts: [ExerciseType: Int]
    public let totalCalories: Double
    public let duration: TimeInterval
    public let classificationHistory: [ClassificationResult]
    
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var totalReps: Int {
        exerciseCounts.values.reduce(0, +)
    }
    
    public var mostPerformedExercise: ExerciseType? {
        exerciseCounts.filter { $0.key != .rest && $0.key != .unknown }
            .max(by: { $0.value < $1.value })?.key
    }
}
