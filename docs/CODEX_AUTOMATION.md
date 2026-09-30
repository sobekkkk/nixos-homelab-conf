# Automatisation Codex du baseline de sécurité

## Décision

Le homelab conserve Codex comme analyseur complémentaire, pas comme compte
privilégié ni comme service permanent. Le baseline déterministe est exécuté par
un script versionné et le modèle, lorsqu'il est authentifié, ne reçoit que le
mode lecture. Cette séparation permet de continuer à produire un rapport
reproductible si l'analyse Codex est indisponible.

Le choix suit les recommandations actuelles d'OpenAI : des instructions ciblées,
un skill court avec révélation progressive, et un sandbox minimal. La
documentation développeur OpenAI est la référence pour toute évolution de
Codex, de ses plugins, skills, permissions ou sandbox.

## Flux

1. sobek lance le runner depuis /etc/nixos.
2. Le runner vérifie le périmètre immuable, fige la révision et crée un worktree
   jetable hors du checkout actif.
3. Les contrôles white-box et réseau autorisés écrivent leurs sorties privées
   sous ~/.local/state/homelab-security/evidence en 0700.
4. Le rapport ne contient que les états et empreintes; le validateur refuse les
   rubriques incomplètes ou des motifs de secrets à haute confiance.
5. Avec --publish, seul ce rapport est commité et poussé vers une nouvelle
   branche codex/pentest-*; main reste intact.
6. Si Codex est connecté, codex exec est limité au sandbox read-only. Sa réponse
   reste hors Git.

## Préconditions

- Le snapshot root-owned doit être disponible et lisible par le groupe
  homelab-audit; le runner ne tente jamais de le régénérer.
- L'authentification GitHub SSH de sobek doit permettre le push sur origin.
- Pour l'analyse complémentaire, sobek doit faire une fois, hors du pipeline :

      codex login --device-auth

  Aucun token ou clé API ne doit être ajouté à NixOS, Git, un prompt ou un
  fichier de configuration du dépôt.

## Exploitation

Le test à blanc vérifie la collecte, la génération, la validation et le
nettoyage du worktree sans changement Git :

    ./security/scripts/run-unattended-baseline.sh --dry-run

La commande unattended qui publie le rapport est :

    ./security/scripts/run-unattended-baseline.sh --publish

Suivre la branche créée dans GitHub et ouvrir une PR seulement après lecture du
rapport expurgé. Une anomalie est un candidat, pas une vulnérabilité confirmée.

## Limites et approbations

Le runner ne fait pas de scan actif, OAST, brute force, authentification,
exploitation, fuzzing, IPv6, changement de cible, rebuild, switch, Docker,
pare-feu, compte ou reboot. Toute évolution de cette liste requiert une
approbation explicite du propriétaire immédiatement avant l'action et une mise
à jour coordonnée de scope.yml, ROE.md, SECURITY.md et du modèle de menaces.
