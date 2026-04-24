# Exercise Classifier

Text-based exercise classification using a HuggingFace model converted to CoreML, plus keyword fallback.

## Features

- Text input classification (`"I did 20 pushups"`)
- CoreML inference via `MLModel`
- Configurable HF model conversion (`MODEL_ID` env var)
- Generated tokenizer/label metadata for Swift (`vocab.json`, `labels.json`)
- Keyword fallback when model is missing/unavailable
- SwiftUI demo view + macOS CI smoke tests (no local Xcode required)

## Architecture

```
ExerciseClassifier/
├── Sources/ExerciseClassifier/
│   ├── Models/ExerciseType.swift
│   ├── ML/ExerciseTextClassifier.swift
│   ├── Services/ExerciseClassifierService.swift
│   ├── Views/ExerciseClassifierView.swift
│   └── App/ExerciseClassifierApp.swift
├── scripts/convert_to_coreml.py
└── .github/workflows/
    ├── coreml-convert.yml
    └── test-swift.yml
```

## Convert HuggingFace Model to CoreML

### Option A (Recommended): GitHub Actions

1. Push repository to GitHub.
2. Open **Actions** → **Convert HF to CoreML** → **Run workflow**.
3. Download artifacts:
   - `ExerciseClassifier-CoreML` (contains `ExerciseClassifier.mlpackage`)
   - `vocab` (contains `vocab.json`)
   - `labels` (contains `labels.json`)

Default model in workflow:
- `distilbert-base-uncased-finetuned-sst-2-english`

You can change model by editing `MODEL_ID` in:
- `.github/workflows/coreml-convert.yml`

### Option B: Manual conversion on macOS

```bash
cd scripts
python -m pip install --upgrade pip
pip install "torch==2.5.0" "transformers==4.46.3" "coremltools==8.3.0" sentencepiece

# Optional
# export HF_TOKEN=...
# export MODEL_ID=distilbert-base-uncased-finetuned-sst-2-english

python convert_to_coreml.py
```

Produced files:
- `ExerciseClassifier.mlpackage`
- `vocab.json`
- `labels.json`

## Swift Integration

1. Add `ExerciseClassifier.mlpackage` to app target.
2. Add `vocab.json` and `labels.json` to bundle resources.
3. Load model in app/service:

```swift
let service = ExerciseClassifierService(modelName: "ExerciseClassifier")
service.classify(text: "I did 20 pushups")
```

If model loading fails, service automatically uses keyword fallback.

## Testing Without Xcode

Use GitHub Action:
- **Actions** → **Test Swift on macOS**

This workflow runs:
- `swift build`
- `swift test` (if present)
- CLI smoke test using `ExerciseClassifierService`

## Requirements

- Swift 5.9+
- iOS 16+ / macOS 13+
- (Optional) Xcode 15+ for app UI integration

## License

MIT
