#!/usr/bin/env bash
# Works out the line coverage of the app from an lcov file, prints it, writes
# it to the summary of the run, and fails if it is below the minimum.
#
# Usage: coverage.sh <lcov.info> <minimum percent>
#
# The generated localization (lib/l10n) is left out: nobody writes it, and its
# lines would only make the number look better or worse for no reason. Note
# that `flutter test --coverage` lists only the files that some test loads, so
# a file that no test touches is not in the number at all.
set -euo pipefail

file="${1:?usage: coverage.sh <lcov.info> <minimum percent>}"
minimum="${2:?usage: coverage.sh <lcov.info> <minimum percent>}"

read -r hit found < <(
  awk -F: '
    /^SF:/ { skip = ($2 ~ /^lib\/l10n\//) }
    /^LF:/ && !skip { found += $2 }
    /^LH:/ && !skip { hit += $2 }
    END { print hit + 0, found + 0 }
  ' "$file"
)

if [ "$found" -eq 0 ]; then
  echo "::error::No lines in $file. Did the tests run with --coverage?"
  exit 1
fi

percent=$(awk -v h="$hit" -v f="$found" 'BEGIN { printf "%.1f", 100 * h / f }')
enough=$(awk -v p="$percent" -v m="$minimum" 'BEGIN { print (p + 0 >= m + 0) ? "yes" : "no" }')

message="Line coverage of the app: ${percent}% (${hit} of ${found} lines), minimum ${minimum}%."
echo "$message"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Coverage"
    echo
    echo "**${percent}%** of the lines (${hit} of ${found}), minimum ${minimum}%."
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$enough" != "yes" ]; then
  echo "::error::$message"
  exit 1
fi
