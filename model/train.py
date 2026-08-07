"""Train the task-priority classifier and log it to MLflow.

Given a task's title + description, predicts priority: low | medium | high.
The model itself is intentionally trivial (TF-IDF + logistic regression) —
the point of this project is the infrastructure around training, tracking,
versioning, and serving it, not the model quality.

Usage:
    MLFLOW_TRACKING_URI=http://localhost:5000 python model/train.py
"""
import os
from pathlib import Path

import mlflow
import mlflow.sklearn
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline

DATA_PATH = Path(__file__).parent / "data" / "tasks_labeled.csv"
EXPERIMENT_NAME = "task-priority-classifier"
REGISTERED_MODEL_NAME = "task-priority-classifier"


def load_dataset() -> pd.DataFrame:
    df = pd.read_csv(DATA_PATH)
    df["text"] = df["title"].fillna("") + " " + df["description"].fillna("")
    return df


def main() -> None:
    mlflow.set_tracking_uri(os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000"))
    mlflow.set_experiment(EXPERIMENT_NAME)

    df = load_dataset()
    X_train, X_test, y_train, y_test = train_test_split(
        df["text"], df["priority"], test_size=0.2, random_state=42, stratify=df["priority"]
    )

    pipeline = Pipeline([
        ("tfidf", TfidfVectorizer(max_features=500, ngram_range=(1, 2))),
        ("clf", LogisticRegression(max_iter=1000)),
    ])

    with mlflow.start_run():
        pipeline.fit(X_train, y_train)
        preds = pipeline.predict(X_test)

        accuracy = accuracy_score(y_test, preds)
        f1 = f1_score(y_test, preds, average="macro")

        mlflow.log_param("model_type", "tfidf+logreg")
        mlflow.log_param("train_rows", len(X_train))
        mlflow.log_param("test_rows", len(X_test))
        mlflow.log_metric("accuracy", accuracy)
        mlflow.log_metric("f1_macro", f1)

        mlflow.sklearn.log_model(
            pipeline,
            artifact_path="model",
            registered_model_name=REGISTERED_MODEL_NAME,
        )

        print(f"accuracy={accuracy:.3f} f1_macro={f1:.3f}")


if __name__ == "__main__":
    main()
