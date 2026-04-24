// Exercise Classifier
// Text-based exercise classification using local NLP/LLM

import Foundation

/// Main entry point for the ExerciseClassifier library
public struct ExerciseClassifier {
    public static let version = "2.0.0"
    
    public init() {}
}

// Re-export public types
public typealias Exercise = ExerciseType
public typealias Classification = ClassificationResult
public typealias TextClassifier = ExerciseTextClassifier
