#!/usr/bin/env bash
# Ensure that only a complete, redacted summary can be committed.
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s REPORT.md\n' "${0##*/}" >&2
  exit 64
fi

report=$1
[[ -f "$report" ]] || { printf 'Report not found: %s\n' "$report" >&2; exit 1; }

required_headings=(
  '# Rapport de baseline de sécurité'
  '## Périmètre et limites'
  '## Méthodologie'
  '## Surface testée'
  '## Contrôles positifs vérifiés'
  '## Résultats et statut'
  '## Preuves privées'
  '## Actions différées nécessitant approbation'
  '## Retest reproductible'
)

for heading in "${required_headings[@]}"; do
  grep -Fqx "$heading" "$report" >/dev/null || {
    printf 'Missing required heading: %s\n' "$heading" >&2
    exit 1
  }
done

# These patterns detect high-confidence accidental secret material. They do not
# replace the mandatory redacted Gitleaks scan.
if grep -Eqi -- '-----BEGIN( [A-Z0-9]+)? PRIVATE KEY-----|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}' "$report"; then
  printf 'Potential secret material found in report; refusing publication.\n' >&2
  exit 1
fi

if grep -Eqi -- '(/var/lib/homelab-security-snapshot|\.local/state/homelab-security/evidence).*(\.txt|\.json|\.out)' "$report"; then
  printf 'Raw evidence filename leaked into report; refusing publication.\n' >&2
  exit 1
fi

if grep -Fq 'TODO' "$report"; then
  printf 'Report contains TODO; refusing publication.\n' >&2
  exit 1
fi

printf 'Report validation passed: %s\n' "$report"
