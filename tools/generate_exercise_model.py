#!/usr/bin/env python3
"""
Generates `ExercisePoseClassifier.mlmodel` — a Core ML classifier that predicts the
exercise being performed from a small vector of body-pose features (joint angles +
a couple of ratios) computed by Apple's Vision body-pose request inside the app.

IMPORTANT — synthetic data caveat:
    The training data here is SYNTHETIC. Each exercise is described by characteristic
    joint-angle distributions (means/stds derived from domain knowledge) and sampled
    with Gaussian noise. The reported test accuracy is therefore measured on the same
    synthetic distribution it was trained on, so it looks high but does NOT represent
    real-world accuracy. This model is a proof-of-concept that wires a real Core ML
    `.mlmodel` into the app; for field-grade accuracy you would train on real, labeled
    pose data from many people / camera angles.

Feature vector (length 7) — MUST stay in sync with `PoseExerciseClassifier.swift`:
    0: average knee angle      / 180
    1: average elbow angle     / 180
    2: hip angle (shoulder-hip-knee)   / 180
    3: body-line angle (shoulder-hip-ankle) / 180
    4: torso lean degrees      / 90
    5: ankle spread ratio (clamped 0..3) / 3
    6: wrists-above-shoulders  (0 or 1)

Run:  python3 tools/generate_exercise_model.py
"""

import numpy as np
import coremltools as ct
from coremltools.models import datatypes
from coremltools.models.neural_network import NeuralNetworkBuilder

RNG = np.random.default_rng(42)

# Class labels match ExerciseType.rawValue in the app so the predicted string maps back.
CLASSES = ["Squat", "Push-up", "Jumping jack", "Sit-up", "Pull-up", "Lunge", "Bicep curl"]

# Raw (mean, std) per feature, per class — in natural units (degrees / ratio / 0-1).
# Order: knee, elbow, hip, bodyLine, torsoLean, ankleSpread, wristAbove
PROFILES = {
    "Squat":        [(110, 30), (165, 8),  (120, 25), (150, 12), (18, 8),  (1.2, 0.20), (0.0, 0.05)],
    "Push-up":      [(172, 6),  (120, 35), (168, 8),  (170, 8),  (80, 8),  (0.5, 0.15), (0.0, 0.05)],
    "Jumping jack": [(170, 8),  (168, 10), (172, 6),  (168, 8),  (6, 4),   (1.8, 0.25), (1.0, 0.05)],
    "Sit-up":       [(95, 15),  (150, 20), (110, 30), (130, 20), (45, 20), (0.6, 0.20), (0.0, 0.05)],
    "Pull-up":      [(172, 6),  (100, 35), (172, 6),  (172, 6),  (6, 4),   (0.4, 0.15), (1.0, 0.05)],
    "Lunge":        [(115, 20), (165, 8),  (150, 20), (150, 12), (14, 7),  (1.4, 0.30), (0.0, 0.05)],
    "Bicep curl":   [(175, 5),  (95, 35),  (175, 5),  (172, 6),  (6, 4),   (1.0, 0.15), (0.0, 0.05)],
}

SAMPLES_PER_CLASS = 1200
N_FEATURES = 7


def normalize(raw):
    """Map raw feature units to the same 0-1 space used in Swift inference."""
    knee, elbow, hip, body_line, torso_lean, ankle_spread, wrist_above = raw.T
    return np.stack([
        np.clip(knee, 0, 180) / 180.0,
        np.clip(elbow, 0, 180) / 180.0,
        np.clip(hip, 0, 180) / 180.0,
        np.clip(body_line, 0, 180) / 180.0,
        np.clip(torso_lean, 0, 90) / 90.0,
        np.clip(ankle_spread, 0, 3) / 3.0,
        np.clip(np.round(wrist_above), 0, 1),
    ], axis=1)


def make_dataset():
    X, y = [], []
    for class_index, name in enumerate(CLASSES):
        profile = PROFILES[name]
        raw = np.zeros((SAMPLES_PER_CLASS, N_FEATURES))
        for f, (mean, std) in enumerate(profile):
            raw[:, f] = RNG.normal(mean, std, SAMPLES_PER_CLASS)
        # wrist-above is a flag: threshold then occasionally flip for noise
        raw[:, 6] = (raw[:, 6] > 0.5).astype(float)
        flip = RNG.random(SAMPLES_PER_CLASS) < 0.05
        raw[flip, 6] = 1.0 - raw[flip, 6]
        X.append(normalize(raw))
        y.append(np.full(SAMPLES_PER_CLASS, class_index))
    return np.concatenate(X), np.concatenate(y)


def softmax(z):
    z = z - z.max(axis=1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=1, keepdims=True)


def train_softmax_regression(X, y, n_classes, epochs=600, lr=0.5, l2=1e-3):
    n, d = X.shape
    W = np.zeros((d, n_classes))
    b = np.zeros(n_classes)
    Y = np.eye(n_classes)[y]
    for _ in range(epochs):
        probs = softmax(X @ W + b)
        grad_W = X.T @ (probs - Y) / n + l2 * W
        grad_b = (probs - Y).mean(axis=0)
        W -= lr * grad_W
        b -= lr * grad_b
    return W, b


def main():
    X, y = make_dataset()

    # Shuffle + 80/20 split.
    perm = RNG.permutation(len(X))
    X, y = X[perm], y[perm]
    split = int(0.8 * len(X))
    Xtr, ytr, Xte, yte = X[:split], y[:split], X[split:], y[split:]

    W, b = train_softmax_regression(Xtr, ytr, len(CLASSES))

    def accuracy(Xs, ys):
        preds = softmax(Xs @ W + b).argmax(axis=1)
        return (preds == ys).mean()

    print(f"Train accuracy (synthetic): {accuracy(Xtr, ytr):.3f}")
    print(f"Test  accuracy (synthetic): {accuracy(Xte, yte):.3f}")
    print("NOTE: synthetic split — not representative of real-world accuracy.")

    # ---- Build the Core ML classifier (single inner-product + softmax) ----
    input_features = [("pose_features", datatypes.Array(N_FEATURES))]
    output_features = [("classProbability", None)]

    builder = NeuralNetworkBuilder(input_features, output_features, mode="classifier")

    # Core ML inner_product expects W as (output_channels, input_channels).
    builder.add_inner_product(
        name="fc",
        W=W.T.flatten(),
        b=b,
        input_channels=N_FEATURES,
        output_channels=len(CLASSES),
        has_bias=True,
        input_name="pose_features",
        output_name="logits",
    )
    builder.add_softmax(name="softmax", input_name="logits", output_name="classProbability")
    builder.set_class_labels(
        CLASSES,
        predicted_feature_name="exercise",
        prediction_blob="classProbability",
    )

    builder.spec.description.input[0].shortDescription = "Body-pose feature vector (length 7)"
    builder.spec.description.output[0].shortDescription = "Probability per exercise"

    mlmodel = ct.models.MLModel(builder.spec)
    mlmodel.short_description = (
        "Exercise classifier from Vision body-pose features. "
        "Trained on SYNTHETIC data (proof-of-concept) — accuracy is not field-validated."
    )
    mlmodel.author = "Calora FitnessCoach"
    mlmodel.input_description["pose_features"] = "Normalized joint angles + ratios (length 7)"
    mlmodel.output_description["exercise"] = "Predicted exercise name"
    mlmodel.output_description["classProbability"] = "Confidence per exercise"

    out_path = "Cindi_FitnessCoach_L25020008/Core/ML/ExercisePoseClassifier.mlmodel"
    mlmodel.save(out_path)
    print(f"Saved {out_path}")


if __name__ == "__main__":
    main()
