#!/bin/bash
# Orphan Export Detector
# Finds exported functions/constants that are never imported elsewhere.
# This catches the #1 AI agent failure mode: writing code that's never wired up.
#
# Usage: bash scripts/check-orphaned-exports.sh [src_dir] [threshold]
# Default: src_dir=src, threshold=3
#
# For larger codebases (500+ files), consider a TypeScript implementation
# using AST parsing for better accuracy. See DanBot's production version
# at github.com/defi-app/danbot for reference.

set -euo pipefail

SRC_DIR="${1:-src}"
WARNING_THRESHOLD="${2:-3}"
orphan_count=0
orphans=""

# Ensure source directory exists
if [ ! -d "$SRC_DIR" ]; then
  echo "Source directory $SRC_DIR not found. Skipping orphan check."
  exit 0
fi

# Find all exported functions (both `export function` and `export async function`)
while IFS= read -r file; do
  while IFS= read -r match; do
    # Extract function name
    func_name=$(echo "$match" | grep -oP '(?<=function )\w+' || true)
    [ -z "$func_name" ] && continue

    # Skip common entry point patterns
    case "$func_name" in
      handler|config|main|default|setup|bootstrap|register|init|initialize) continue ;;
    esac

    # Search for imports/references to this function across the codebase
    # Excludes the defining file itself and test files
    import_count=$(grep -rl "\b${func_name}\b" "$SRC_DIR" \
      --include="*.ts" --include="*.tsx" \
      --exclude="*.test.ts" --exclude="*.test.tsx" --exclude="*.spec.ts" \
      | grep -v "$(basename "$file")" | wc -l || true)

    if [ "$import_count" -eq 0 ]; then
      orphans="${orphans}  ORPHAN: ${file}: ${func_name}()\n"
      orphan_count=$((orphan_count + 1))
    fi
  done < <(grep -nE '^export (async )?function ' "$file" 2>/dev/null || true)
done < <(find "$SRC_DIR" -name "*.ts" -not -name "*.test.ts" -not -name "*.spec.ts" -not -name "*.d.ts" -not -path "*/node_modules/*" 2>/dev/null)

# Also check exported arrow functions (export const X = ...)
while IFS= read -r file; do
  while IFS= read -r match; do
    func_name=$(echo "$match" | grep -oP '(?<=const )\w+' || true)
    [ -z "$func_name" ] && continue

    case "$func_name" in
      handler|config|main|default|setup|bootstrap|register|init|initialize) continue ;;
    esac

    import_count=$(grep -rl "\b${func_name}\b" "$SRC_DIR" \
      --include="*.ts" --include="*.tsx" \
      --exclude="*.test.ts" --exclude="*.test.tsx" --exclude="*.spec.ts" \
      | grep -v "$(basename "$file")" | wc -l || true)

    if [ "$import_count" -eq 0 ]; then
      orphans="${orphans}  ORPHAN: ${file}: ${func_name} (arrow fn)\n"
      orphan_count=$((orphan_count + 1))
    fi
  done < <(grep -nE '^export const \w+ = ' "$file" 2>/dev/null || true)
done < <(find "$SRC_DIR" -name "*.ts" -not -name "*.test.ts" -not -name "*.spec.ts" -not -name "*.d.ts" -not -path "*/node_modules/*" 2>/dev/null)

# Report results
if [ "$orphan_count" -gt 0 ]; then
  echo ""
  echo "⚠️  ${orphan_count} potentially orphaned export(s):"
  echo -e "$orphans"
  echo ""
  echo "For each orphan: wire it up (import + call it) or delete it."
  echo "If it's an intentional entry point (API handler, cron), add it to the skip list above."
fi

if [ "$orphan_count" -gt "$WARNING_THRESHOLD" ]; then
  echo ""
  echo "❌ THRESHOLD EXCEEDED: ${orphan_count} orphans (max: ${WARNING_THRESHOLD})"
  echo "Wire up or delete unused exports before continuing."
  exit 1
fi

echo "✅ Orphan check passed (${orphan_count}/${WARNING_THRESHOLD} threshold)"
exit 0
