import Foundation
import CoreML

/// Text-based exercise classifier using CoreML model
public class ExerciseTextClassifier {
    
    private var mlModel: MLModel?
    private var vocabulary: [String: Int] = [:]
    private var modelLabels: [String] = []
    private let maxLength = 128
    
    public init() {}
    
    /// Load CoreML model and vocabulary from bundle
    public func loadModel(named modelName: String) throws {
        // Load CoreML model
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            throw ClassifierError.modelNotFound(modelName)
        }
        
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU
            self.mlModel = try MLModel(contentsOf: modelURL, configuration: config)
        } catch {
            throw ClassifierError.modelLoadFailed(error.localizedDescription)
        }
        
        // Load vocabulary
        if let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "json"),
           let data = try? Data(contentsOf: vocabURL),
           let vocab = try? JSONDecoder().decode([String: Int].self, from: data) {
            self.vocabulary = vocab
        } else {
            // Use basic fallback vocabulary
            self.vocabulary = createBasicVocabulary()
        }
        
        // Load model labels
        if let labelsURL = Bundle.main.url(forResource: "labels", withExtension: "json"),
           let data = try? Data(contentsOf: labelsURL),
           let labels = try? JSONDecoder().decode([String].self, from: data) {
            self.modelLabels = labels
        } else {
            // Default labels for sentiment model
            self.modelLabels = ["NEGATIVE", "POSITIVE"]
        }
    }
    
    /// Classify exercise from text using CoreML
    public func classify(text: String) throws -> ClassificationResult {
        guard let model = mlModel else {
            throw ClassifierError.modelNotLoaded
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClassifierError.emptyInput
        }
        
        // Tokenize input
        let (inputIds, attentionMask) = tokenize(text: text)
        
        // Create MLMultiArray inputs
        let inputIdsArray = try createMultiArray(from: inputIds)
        let attentionMaskArray = try createMultiArray(from: attentionMask)
        
        // Run inference
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputIdsArray),
            "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
        ])
        
        let output = try model.prediction(from: input)
        
        // Parse logits
        guard let logitsValue = output.featureValue(for: "logits"),
              let logits = logitsValue.multiArrayValue else {
            throw ClassifierError.predictionFailed("No logits output")
        }
        
        // Get prediction (argmax of logits)
        let (predictedIndex, confidence) = getArgmaxWithSoftmax(logits: logits)
        
        // Map to ExerciseType
        let exerciseType = mapIndexToExerciseType(index: predictedIndex)
        
        return ClassificationResult(
            exerciseType: exerciseType,
            confidence: confidence
        )
    }
    
    /// Fallback classification using keywords
    public func classifyWithKeywords(text: String) -> ClassificationResult {
        let normalizedText = text.lowercased()
        
        let exercisePatterns: [ExerciseType: [String]] = [
            .pushup: ["pushup", "push-up", "push up", "віджимання", "chest press"],
            .squat: ["squat", "присідання", "leg bend", "knee bend"],
            .jumpingJack: ["jumping jack", "star jump", "джампінг", "стрибки"],
            .plank: ["plank", "планка", "core hold"],
            .rest: ["rest", "відпочинок", "break", "pause"]
        ]
        
        var bestMatch: ExerciseType = .unknown
        var bestScore: Double = 0.0
        
        for (exercise, keywords) in exercisePatterns {
            for keyword in keywords {
                if normalizedText.contains(keyword) {
                    let score = min(Double(keyword.count) / Double(normalizedText.count) + 0.5, 0.95)
                    if score > bestScore {
                        bestScore = score
                        bestMatch = exercise
                    }
                }
            }
        }
        
        return ClassificationResult(exerciseType: bestMatch, confidence: bestScore)
    }
    
    // MARK: - Private Methods
    
    private func tokenize(text: String) -> ([Int], [Int]) {
        var inputIds = [Int]()
        var attentionMask = [Int]()
        
        // Add [CLS] token
        inputIds.append(vocabulary["[CLS]"] ?? 101)
        attentionMask.append(1)
        
        // Tokenize words (simple whitespace tokenization + subword fallback)
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        for word in words where !word.isEmpty {
            if let tokenId = vocabulary[word] {
                inputIds.append(tokenId)
            } else {
                // Unknown token
                inputIds.append(vocabulary["[UNK]"] ?? 100)
            }
            attentionMask.append(1)
            
            if inputIds.count >= maxLength - 1 {
                break
            }
        }
        
        // Add [SEP] token
        inputIds.append(vocabulary["[SEP]"] ?? 102)
        attentionMask.append(1)
        
        // Pad to maxLength
        while inputIds.count < maxLength {
            inputIds.append(vocabulary["[PAD]"] ?? 0)
            attentionMask.append(0)
        }
        
        return (inputIds, attentionMask)
    }
    
    private func createMultiArray(from array: [Int]) throws -> MLMultiArray {
        let mlArray = try MLMultiArray(shape: [1, NSNumber(value: maxLength)], dataType: .int32)
        for (index, value) in array.enumerated() {
            mlArray[[0, NSNumber(value: index)] as [NSNumber]] = NSNumber(value: value)
        }
        return mlArray
    }
    
    private func getArgmaxWithSoftmax(logits: MLMultiArray) -> (Int, Double) {
        let count = logits.count
        var maxIndex = 0
        var maxValue = Double(truncating: logits[0])
        var expSum: Double = 0
        
        // Find max for numerical stability
        for i in 0..<count {
            let val = Double(truncating: logits[i])
            if val > maxValue {
                maxValue = val
                maxIndex = i
            }
        }
        
        // Compute softmax
        for i in 0..<count {
            let val = Double(truncating: logits[i])
            expSum += exp(val - maxValue)
        }
        
        let confidence = 1.0 / expSum
        return (maxIndex, confidence)
    }
    
    private func mapIndexToExerciseType(index: Int) -> ExerciseType {
        guard index < modelLabels.count else { return .unknown }
        
        let label = modelLabels[index].lowercased()
        
        // Map model output labels to ExerciseType
        // For sentiment model (NEGATIVE/POSITIVE), we use keyword fallback
        // For exercise-specific model, we map directly
        switch label {
        case "pushup", "push-up": return .pushup
        case "squat": return .squat
        case "jumping jack", "jumpingjack": return .jumpingJack
        case "plank": return .plank
        case "rest": return .rest
        case "positive": return .pushup  // Sentiment model: positive -> exercise detected
        case "negative": return .rest    // Sentiment model: negative -> no exercise
        default: return .unknown
        }
    }
    
    /// Get the raw model prediction label (for debugging)
    public func getRawLabel(for index: Int) -> String? {
        guard index < modelLabels.count else { return nil }
        return modelLabels[index]
    }
    
    private func createBasicVocabulary() -> [String: Int] {
        // Minimal vocabulary for fallback
        return [
            "[PAD]": 0,
            "[UNK]": 100,
            "[CLS]": 101,
            "[SEP]": 102,
            "pushup": 1000,
            "push": 1001,
            "up": 1002,
            "squat": 1003,
            "plank": 1004,
            "jumping": 1005,
            "jack": 1006,
            "rest": 1007,
            "exercise": 1008,
            "i": 1009,
            "did": 1010,
            "the": 1011,
            "a": 1012
        ]
    }
}

// MARK: - Errors

public enum ClassifierError: Error, LocalizedError {
    case modelNotFound(String)
    case modelLoadFailed(String)
    case modelNotLoaded
    case emptyInput
    case predictionFailed(String)
    case tokenizationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "CoreML model '\(name)' not found in bundle"
        case .modelLoadFailed(let reason):
            return "Failed to load CoreML model: \(reason)"
        case .modelNotLoaded:
            return "CoreML model is not loaded"
        case .emptyInput:
            return "Input text is empty"
        case .predictionFailed(let reason):
            return "Prediction failed: \(reason)"
        case .tokenizationFailed(let reason):
            return "Tokenization failed: \(reason)"
        }
    }
}
