#!/usr/bin/env bash
set -euo pipefail

# Usage: ./seed-tasks.sh
BASE_URL="http://alex.taskly.ironlabs.online"   # confirm staging vs production here

TITLES=(
  "Write project proposal" "Review pull request" "Fix login bug"
  "Update dependencies" "Deploy to staging" "Write unit tests"
  "Refactor auth module" "Set up CI pipeline" "Document API endpoints"
  "Optimize database query" "Design landing page" "Fix responsive layout"
  "Add error handling" "Configure monitoring" "Write onboarding guide"
  "Review security policy" "Update README" "Test rollback procedure"
  "Add rate limiting" "Fix memory leak" "Migrate database schema"
  "Set up alerting rules" "Write integration tests" "Clean up old branches"
  "Add caching layer" "Improve error messages" "Update Terraform modules"
  "Fix flaky test" "Add health check endpoint" "Review Helm chart"
  "Rotate API keys" "Update dashboard panels" "Fix timezone bug"
  "Add pagination" "Prepare demo environment"
)

PRIORITIES=("low" "medium" "high")

TOTAL=200
echo ">> Seeding ${TOTAL} tasks against ${BASE_URL} ..."

for i in $(seq 1 "$TOTAL"); do
  title="${TITLES[$(( (i - 1) % ${#TITLES[@]} ))]}"
  priority="${PRIORITIES[$((RANDOM % 3))]}"
  done_flag=$([ $((RANDOM % 4)) -eq 0 ] && echo true || echo false)

  response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/tasks" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"${title}\", \"description\": \"Seeded task ${i}\", \"done\": ${done_flag}, \"priority\": \"${priority}\"}")

  echo "  [${i}/${TOTAL}] ${title} -> HTTP ${response}"
done

echo ">> Done. Verify:"
echo "   curl ${BASE_URL}/tasks | jq length"