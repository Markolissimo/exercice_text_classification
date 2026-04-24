import torch
import coremltools as ct
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import os

# Default is a CoreML-friendly model for reliable prototype conversion.
# To force a different model, set MODEL_ID in the workflow env.
MODEL_ID = os.getenv("MODEL_ID", "distilbert-base-uncased-finetuned-sst-2-english")
OUT_NAME = "ExerciseClassifier"
LABELS = ["Pushup", "Squat", "Jumping Jack", "Plank", "Rest"]

print(f"Loading model: {MODEL_ID}")
hf_token = os.getenv("HF_TOKEN")
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, token=hf_token)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_ID, token=hf_token)
model.eval()
model.float()

class WrappedModel(torch.nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m

    def forward(self, input_ids, attention_mask):
        # Keep dtypes explicit for stable CoreML conversion.
        input_ids = input_ids.to(torch.int64)
        attention_mask = attention_mask.to(torch.float32)
        out = self.m(input_ids=input_ids, attention_mask=attention_mask)
        return out.logits

wrapped = WrappedModel(model)
wrapped.eval()

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
    compute_precision=ct.precision.FLOAT32,
)

mlmodel.author = "ExerciseClassifier"
mlmodel.short_description = "Zero-shot text classification for exercise detection"
mlmodel.version = "1.0.0"

output_path = f"{OUT_NAME}.mlpackage"
mlmodel.save(output_path)
print(f"Saved: {output_path}")

# Save tokenizer vocab as JSON for Swift-side tokenization
import json

vocab = tokenizer.get_vocab()
with open("vocab.json", "w", encoding="utf-8") as f:
    json.dump(vocab, f, ensure_ascii=False)
print(f"Saved vocab.json ({len(vocab)} tokens)")

# Save model labels for Swift-side mapping
model_labels = list(model.config.id2label.values())
with open("labels.json", "w", encoding="utf-8") as f:
    json.dump(model_labels, f, ensure_ascii=False)
print(f"Saved labels.json: {model_labels}")

# Also save tokenizer files for reference
tokenizer.save_pretrained("tokenizer_files")
print("Saved tokenizer files to: tokenizer_files/")
