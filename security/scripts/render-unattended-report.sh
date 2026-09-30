#!/usr/bin/env bash
# Render a safe report from the runner metadata; raw outputs never enter Git.
set -Eeuo pipefail

if [[ $# -ne 4 ]]; then
  printf 'Usage: %s RUN_ID EVIDENCE_DIR OUTPUT.md CODEX_STATUS\n' "${0##*/}" >&2
  exit 64
fi

run_id=$1
evidence_dir=$2
output=$3
codex_status=$4
manifest="$evidence_dir/manifest.tsv"
[[ -f "$manifest" ]] || { printf 'Manifest not found: %s\n' "$manifest" >&2; exit 1; }

revision=$(awk -F '\t' '$1 == "revision" { print $2; exit }' "$manifest")
generation=$(awk -F '\t' '$1 == "generation" { print $2; exit }' "$manifest")
target=$(awk -F '\t' '$1 == "target" { print $2; exit }' "$manifest")
ports=$(awk -F '\t' '$1 == "ports" { print $2; exit }' "$manifest")
started=$(awk -F '\t' '$1 == "started_at" { print $2; exit }' "$manifest")

{
  printf '# Rapport de baseline de sécurité\n\n'
  printf 'Statut : **baseline non destructive terminée**. Les résultats des outils sont des candidats ; aucune vulnérabilité n’est confirmée sans validation indépendante.\n\n'
  printf 'Run : %s · Début (UTC) : %s · Révision : %s · Génération : %s\n\n' "$run_id" "$started" "$revision" "$generation"
  printf '## Périmètre et limites\n\n'
  printf 'Cible unique autorisée : %s; TCP autorisé : %s. IPv6, autres hôtes, authentification, exploitation, scans actifs, fuzzing, OAST, changements de configuration et remédiation sont exclus.\n\n' "$target" "$ports"
  printf '## Méthodologie\n\n'
  printf 'Revue white-box de la révision figée, scan Git Gitleaks entièrement expurgé, évaluation Nix sans activation, inventaire de paquets, lecture du snapshot curaté et découverte de versions/TLS limitée aux ports déclarés.\n\n'
  printf '## Surface testée\n\n'
  printf '| Élément | Limite |\n| --- | --- |\n'
  printf '| Hôte réseau | %s uniquement |\n' "$target"
  printf '| TCP | %s uniquement |\n' "$ports"
  printf '| Dépôt | révision %s |\n' "$revision"
  printf '| Système | génération %s |\n\n' "$generation"
  printf '## Contrôles positifs vérifiés\n\n'
  printf 'Les contrôles dont l’artefact a été produit avec succès sont listés ci-dessous. Un succès de collecte ne confirme pas à lui seul la sécurité.\n\n'
  printf '| Contrôle | État de collecte | Empreinte de preuve |\n| --- | --- | --- |\n'
  awk -F '\t' '$1 == "artifact" { printf "| %s | %s | %s |\n", $2, $3, $4 }' "$manifest"
  printf '\n'
  printf '## Résultats et statut\n\n'
  printf 'Les codes non nuls ou observations de scanners restent des **candidats** à corréler avec la configuration effective ; ils ne sont pas des preuves d’exploitation. Analyse Codex complémentaire : %s.\n\n' "$codex_status"
  printf '| Vérification | Statut |\n| --- | --- |\n'
  awk -F '\t' '$1 == "artifact" { printf "| %s | %s |\n", $2, $3 }' "$manifest"
  printf '\n'
  printf '## Preuves privées\n\n'
  printf 'Les artefacts bruts sont conservés hors Git dans le répertoire d’état privé de sobek (mode 0700). Ce rapport ne contient ni secrets, ni sorties de scanner, ni contenu de snapshot. Le propriétaire peut relier chaque empreinte ci-dessus au manifeste privé %s.\n\n' "$run_id"
  printf '## Actions différées nécessitant approbation\n\n'
  printf '%s\n' '- Validation manuelle de tout candidat signalé par les artefacts privés.'
  printf '%s\n\n' '- Toute exploitation, authentification, scan actif, OAST, IPv6, nouvelle cible/port, correction, rebuild, changement Docker/pare-feu/comptes ou redémarrage.'
  printf '## Retest reproductible\n\n'
  printf 'Depuis /etc/nixos, avec le compte sobek déjà authentifié dans Codex si l’analyse complémentaire est souhaitée :\n\n'
  printf '    ./security/scripts/run-unattended-baseline.sh --publish\n\n'
  printf 'Le runner crée une branche codex/pentest-*, valide le rapport puis pousse uniquement cette branche. Il ne publie jamais sur main.\n'
} > "$output"
