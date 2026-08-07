# Tasks API

A minimal FastAPI task tracker.

## Quick Start

```bash
pip install -r requirements.txt
uvicorn main:app --reload
```

Open http://localhost:8000/docs for the interactive API docs.

## With Docker

```bash
docker compose up
```

## Task-priority model

`model/train.py` trains a trivial TF-IDF + logistic regression classifier that predicts a
task's `priority` (low/medium/high) from its title + description, and logs it to MLflow. It's
the starter kit for the MLFlowOps project option — see `model/data/tasks_labeled.csv` for the
synthetic training data (regenerate with `python model/generate_data.py`).

```bash
pip install -r model/requirements.txt
MLFLOW_TRACKING_URI=http://localhost:5000 python model/train.py
```
