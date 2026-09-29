#!/usr/bin/env bash
# Simulates a long-running download job so you can try Sightglass.
#
# Writes, every DEMO_INTERVAL seconds (default 0.5):
#   <dir>/status.json    the whole status document, replaced atomically
#   <dir>/events.ndjson  one JSON object appended per step
# and <dir>/config.json, a Sightglass config watching both (see `make run-demo`).
#
# Usage: scripts/demo.sh [dir]    (default: build/demo)
set -euo pipefail

dir="${1:-build/demo}"
total="${DEMO_TOTAL:-200}"
interval="${DEMO_INTERVAL:-0.5}"
mkdir -p "$dir"
dir="$(cd "$dir" && pwd)"
: > "$dir/events.ndjson"

cat > "$dir/config.json" <<JSON
{
  "version": 1,
  "watches": [
    {
      "id": "5D7A4C1E-0000-4000-8000-000000000001",
      "name": "Demo download",
      "path": "$dir/status.json",
      "staleAfter": 30,
      "fields": [
        { "id": "5D7A4C1E-0000-4000-8000-000000000011", "path": "status",
          "display": { "badge": { "rules": [
            { "match": "running", "symbol": "circle.fill", "color": "blue" },
            { "match": "done", "symbol": "checkmark.circle.fill", "color": "green" } ] } },
          "format": { "auto": {} } },
        { "id": "5D7A4C1E-0000-4000-8000-000000000012", "path": "progress.downloaded",
          "display": { "bar": { "source": { "ratio": { "total": "progress.total" } }, "showsPercent": true } },
          "format": { "auto": {} } },
        { "id": "5D7A4C1E-0000-4000-8000-000000000013", "path": "progress.bytes", "label": "DL",
          "display": { "text": {} }, "format": { "bytes": {} } },
        { "id": "5D7A4C1E-0000-4000-8000-000000000014", "path": "progress.downloaded",
          "display": { "rate": { "total": "progress.total", "unit": "files" } }, "format": { "auto": {} } }
      ]
    },
    {
      "id": "5D7A4C1E-0000-4000-8000-000000000002",
      "name": "Demo log",
      "path": "$dir/events.ndjson",
      "staleAfter": 30,
      "fields": [
        { "id": "5D7A4C1E-0000-4000-8000-000000000021", "path": "progress.downloaded",
          "display": { "ring": { "source": { "ratio": { "total": "progress.total" } }, "showsPercent": true } },
          "format": { "auto": {} } },
        { "id": "5D7A4C1E-0000-4000-8000-000000000022", "path": "speed_bps",
          "display": { "sparkline": { "samples": 60 } }, "format": { "bytes": {} } }
      ]
    }
  ]
}
JSON

downloaded=0
bytes=0
errors=0
started=$(date +%s)

write_step() {
  local status="$1" file="$2" speed="$3" json
  json=$(printf '{"status":"%s","current_file":"%s","progress":{"downloaded":%d,"total":%d,"bytes":%d},"speed_bps":%d,"errors":%d,"elapsed_seconds":%d}' \
    "$status" "$file" "$downloaded" "$total" "$bytes" "$speed" "$errors" "$(( $(date +%s) - started ))")
  printf '%s\n' "$json" > "$dir/status.json.tmp"
  mv "$dir/status.json.tmp" "$dir/status.json"
  printf '%s\n' "$json" >> "$dir/events.ndjson"
}

echo "Writing $dir/status.json and $dir/events.ndjson (Ctrl-C to stop)"
while (( downloaded < total )); do
  step=$(( RANDOM % 3 + 1 ))
  downloaded=$(( downloaded + step > total ? total : downloaded + step ))
  speed=$(( RANDOM % 4000000 + 500000 ))
  bytes=$(( bytes + step * speed ))
  if (( RANDOM % 40 == 0 )); then errors=$(( errors + 1 )); fi
  write_step running "file-$(printf '%04d' "$downloaded").zip" "$speed"
  sleep "$interval"
done
write_step done "" 0
echo "Done."
