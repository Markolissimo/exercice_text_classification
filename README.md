# Exercise Classifier

Text-based exercise classification using CoreML + HuggingFace model on iOS/macOS.

## Features

- **Text-based Classification**: Describe exercise in natural language
- **CoreML Integration**: Uses converted HuggingFace model for on-device inference
- **Zero-shot Classification**: Works without fine-tuning via NLI model
- **Keyword Fallback**: Pattern-based detection when model unavailable
- **SwiftUI Interface**: Modern text input UI with example prompts

## Architecture

```
ExerciseClassifier/
├── Models/
│   └── ExerciseType.swift              # Exercise types enum
├── ML/
│   └── ExerciseTextClassifier.swift    # CoreML classifier
├── Services/
│   └── ExerciseClassifierService.swift # Main orchestration service
├── Views/
│   └── ExerciseClassifierView.swift    # SwiftUI text input interface
├── App/
│   └── ExerciseClassifierApp.swift     # App entry point
├── scripts/
│   └── convert_to_coreml.py            # HF → CoreML conversion
└── .github/workflows/
    └── coreml-convert.yml              # GitHub Actions for model conversion
```

## How It Works

### 1. Text Input
User describes the exercise in natural language:
- "I did 10 pushups"
- "Squat exercise"
- "Holding a plank position"

### 2. Text Processing
The classifier tokenizes and processes input:
- **CoreML Model** (if available): Direct inference via MLModel
- **Keyword Fallback**: Pattern-based exercise detection

### 3. Classification Output
- **exerciseType**: Detected exercise (pushup, squat, etc.)
- **confidence**: Prediction confidence (0.0 - 1.0)

## Getting the CoreML Model

### Option 1: GitHub Actions (Recommended)
1. Push this repo to GitHub
2. Go to **Actions** → **Convert HF to CoreML** → **Run workflow**
3. Download artifact `ExerciseClassifier-CoreML`
4. Unzip and add `ExerciseClassifier.mlpackage` to Xcode project

### Option 2: Manual Conversion (requires macOS)
```bash
cd scripts
pip install torch transformers coremltools sentencepiece
python convert_to_coreml.py
```

### Adding Model to Xcode
1. Drag `ExerciseClassifier.mlpackage` into Xcode project
2. Ensure "Copy items if needed" is checked
3. Xcode auto-compiles to `.mlmodelc`
4. Load in code: `service.loadModel(named: "ExerciseClassifier")`

## Usage

```swift
import ExerciseClassifier

// Create the service
let service = ExerciseClassifierService()

// Classify from text
service.classify(text: "I just finished 20 pushups")

// Access results
print(service.currentExercise)      // .pushup
print(service.confidence)           // 0.85
print(service.lastInputText)        // "I just finished 20 pushups"

// Get summary
let summary = service.getWorkoutSummary()
print(summary.totalCalories)
```

## Supported Exercises

| Exercise | Keywords |
|----------|----------|
| Pushup | pushup, push-up, chest press, floor press |
| Squat | squat, leg bend, knee bend |
| Jumping Jack | jumping jack, star jump |
| Plank | plank, core hold, static hold |
| Rest | rest, break, pause |

## Requirements

- iOS 16.0+ / macOS 13.0+
- Xcode 15+
- Swift 5.9+

## License

MIT License
