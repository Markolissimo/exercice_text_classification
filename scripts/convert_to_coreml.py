import torch
import coremltools as ct
from transformers import AutoTokenizer, AutoModelForSequenceClassification

MODEL_ID = "MoritzLaurer/mDeBERTa-v3-base-mnli-xnli"
OUT_NAME = "ExerciseClassifier"
LABELS = ["Pushup", "Squat", "Jumping Jack", "Plank", "Rest"]

print(f"Loading model: {MODEL_ID}")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_ID)
model.eval()

class WrappedModel(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m

    def forward(self, input_ids, attention_mask):
        out = self.m(input_ids=input_ids, attention_mask=attention_mask)
        return out.logits

wrapped = WrappedModel(model)

max_len = 128
dummy = tokenizer(
    "I did 20 pushups",
    return_tensors="pt",
    truncation=True,
    padding="max_length",
    max_length=max_len
)

print("Tracing model...")
with torch.no_grad():
    traced = torch.jit.trace(
        wrapped,
        (dummy["input_ids"], dummy["attention_mask"])
    )

print("Converting to CoreML...")
mlmodel = ct.convert(
    traced,
    convert_to="mlprogram",
    inputs=[
        ct.TensorType(name="input_ids", shape=(1, max_len), dtype=int),
        ct.TensorType(name="attention_mask", shape=(1, max_len), dtype=int),
    ],
    outputs=[ct.TensorType(name="logits")],
    minimum_deployment_target=ct.target.iOS16,
)

mlmodel.author = "ExerciseClassifier"
mlmodel.short_description = "Zero-shot text classification for exercise detection"
mlmodel.version = "1.0.0"

output_path = f"{OUT_NAME}.mlpackage"
mlmodel.save(output_path)
print(f"Saved: {output_path}")

# Save tokenizer vocab for Swift-side tokenization
tokenizer.save_pretrained("tokenizer_files")
print("Saved tokenizer files to: tokenizer_files/")
