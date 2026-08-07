# Tasks API

A minimal FastAPI task tracker.

## Quick Start

```bash
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
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

**Use Python 3.10–3.12.** `mlflow` pulls in `pyarrow`, which has no prebuilt wheel for very new
Python versions (3.13+) on several platforms — pip will try to build it from source and fail
with a `cmake` error unless you have the full C++ build toolchain installed. If `python3 -V`
shows 3.13 or newer, install 3.12 separately (e.g. `brew install python@3.12`) and use that to
create the venv below.

```bash
python3.12 -m venv .venv-model
source .venv-model/bin/activate   # Windows: .venv-model\Scripts\activate
pip install -r model/requirements.txt
MLFLOW_TRACKING_URI=http://localhost:5000 python model/train.py
```
