"""Generate the synthetic labeled dataset used by train.py.

Not part of the training pipeline itself — run once (already committed as
model/data/tasks_labeled.csv) to regenerate it if you want more/different rows:

    python model/generate_data.py
"""
import csv
import random
from pathlib import Path

random.seed(42)

SUBJECTS = [
    "login page", "checkout flow", "API rate limiter", "email service", "dashboard chart",
    "search endpoint", "user profile", "billing webhook", "cache layer", "PDF export",
    "notification worker", "auth middleware", "database migration", "CSV importer", "admin panel",
]

HIGH_TITLES = [
    "URGENT: {subject} is down in production",
    "Critical bug in {subject}, customers are blocked",
    "Security vulnerability found in {subject}, fix ASAP",
    "{subject} outage - needs immediate attention",
    "Production incident: {subject} throwing 500s for all users",
    "Data loss risk in {subject}, must fix today",
]
HIGH_DESCRIPTIONS = [
    "This is blocking all customers and needs to be fixed immediately.",
    "On-call was paged, this cannot wait until next sprint.",
    "Escalated by support, affects every account on the platform.",
    "Revenue-impacting, drop everything else.",
]

MEDIUM_TITLES = [
    "Improve {subject} performance",
    "Add validation to {subject}",
    "Refactor {subject} before next release",
    "{subject} needs better error messages",
    "Update {subject} to handle an edge case",
    "Investigate flaky test in {subject}",
]
MEDIUM_DESCRIPTIONS = [
    "Should be done this sprint, not blocking anyone yet.",
    "Would be good to land before the next release.",
    "No customers affected yet but worth prioritizing soon.",
    "Came up in code review, moderate impact.",
]

LOW_TITLES = [
    "Rename variable in {subject}",
    "Minor typo in {subject} docs",
    "Nice-to-have: dark mode for {subject}",
    "Clean up unused imports in {subject}",
    "Consider refactoring {subject} someday",
    "Cosmetic tweak to {subject} spacing",
]
LOW_DESCRIPTIONS = [
    "No rush, whenever someone has spare time.",
    "Purely cosmetic, doesn't affect functionality.",
    "Someday/maybe, not tied to any deadline.",
    "Low priority cleanup, no user impact.",
]


def rows():
    for subject in SUBJECTS:
        for title in HIGH_TITLES:
            yield title.format(subject=subject), random.choice(HIGH_DESCRIPTIONS), "high"
        for title in MEDIUM_TITLES:
            yield title.format(subject=subject), random.choice(MEDIUM_DESCRIPTIONS), "medium"
        for title in LOW_TITLES:
            yield title.format(subject=subject), random.choice(LOW_DESCRIPTIONS), "low"


def main() -> None:
    out_path = Path(__file__).parent / "data" / "tasks_labeled.csv"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    data = list(rows())
    random.shuffle(data)

    with out_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["title", "description", "priority"])
        writer.writerows(data)

    print(f"wrote {len(data)} rows to {out_path}")


if __name__ == "__main__":
    main()
