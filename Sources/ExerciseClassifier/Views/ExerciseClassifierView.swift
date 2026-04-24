import SwiftUI

/// Main UI view for text-based Exercise Classifier
public struct ExerciseClassifierView: View {
    @StateObject private var service = ExerciseClassifierService()
    @State private var inputText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Text Input Section
                    textInputSection
                    
                    // Current Exercise Display
                    currentExerciseCard
                    
                    // Example Prompts
                    examplePromptsSection
                    
                    // Statistics
                    statisticsSection
                    
                    // Exercise Counts
                    exerciseCountsSection
                }
                .padding()
            }
            .navigationTitle("Exercise Classifier")
            .toolbar {
#if os(macOS)
                ToolbarItem(placement: .automatic) {
                    resetButton
                }
#else
                ToolbarItem(placement: .topBarTrailing) {
                    resetButton
                }
#endif
            }
        }
    }
    
    // MARK: - Subviews

    private var resetButton: some View {
        Button("Reset") {
            service.reset()
            inputText = ""
        }
    }
    
    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Describe the exercise:")
                .font(.headline)
            
            HStack {
                TextField("e.g., 'I did 10 pushups'", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.background)
                            .shadow(color: .black.opacity(0.1), radius: 2)
                    }
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        classifyInput()
                    }
                
                Button {
                    classifyInput()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || service.isProcessing)
            }
            
            if service.isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Classifying...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }
    
    private var currentExerciseCard: some View {
        VStack(spacing: 16) {
            Text(service.currentExercise.emoji)
                .font(.system(size: 80))
            
            Text(service.currentExercise.rawValue)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Confidence Indicator
            HStack {
                Text("Confidence:")
                    .foregroundStyle(.secondary)
                
                ProgressView(value: service.confidence)
                    .progressViewStyle(.linear)
                    .frame(width: 100)
                
                Text("\(Int(service.confidence * 100))%")
                    .fontWeight(.semibold)
                    .foregroundStyle(confidenceColor)
            }
            .font(.subheadline)
            
            if !service.lastInputText.isEmpty {
                Text("Input: \"\(service.lastInputText)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(radius: 5)
        }
    }
    
    private var examplePromptsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try these examples:")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(examplePrompts, id: \.self) { prompt in
                    Button {
                        inputText = prompt
                        classifyInput()
                    } label: {
                        Text(prompt)
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.blue.opacity(0.1))
                            }
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }
    
    private var statisticsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Calories",
                value: String(format: "%.1f", service.totalCalories),
                icon: "flame.fill",
                color: .orange
            )
            
            StatCard(
                title: "Duration",
                value: service.getWorkoutSummary().formattedDuration,
                icon: "clock.fill",
                color: .blue
            )
            
            StatCard(
                title: "Total Reps",
                value: "\(service.getWorkoutSummary().totalReps)",
                icon: "repeat",
                color: .purple
            )
        }
    }
    
    private var exerciseCountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Breakdown")
                .font(.headline)
            
            ForEach(ExerciseType.allCases.filter { $0 != .rest && $0 != .unknown }, id: \.self) { exercise in
                HStack {
                    Text(exercise.emoji)
                    Text(exercise.rawValue)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(service.exerciseCounts[exercise, default: 0]) reps")
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }
    
    private var confidenceColor: Color {
        switch service.confidence {
        case 0.75...: return .green
        case 0.5..<0.75: return .orange
        default: return .red
        }
    }
    
    private var examplePrompts: [String] {
        [
            "I did 10 pushups",
            "Squat exercise",
            "Jumping jacks cardio",
            "Holding a plank",
            "Taking a rest",
            "Floor press workout"
        ]
    }
    
    private func classifyInput() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        service.classify(text: inputText)
        isTextFieldFocused = false
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Preview

#Preview {
    ExerciseClassifierView()
}
