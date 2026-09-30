# Audit de sécurité du homelab

## Mission

Évaluer ce homelab avec une revue white-box du dépôt et un baseline black-box
non destructif depuis le poste Windows autorisé. Les sources de vérité sont
`SECURITY.md`, `docs/THREAT_MODEL.md`, `docs/ARCHITECTURE.md`,
`docs/CONTAINERS.md`, `docs/CODEX.md` et `security/ROE.md`.

Un résultat de scanner ou un écart de durcissement n'est jamais une vulnérabilité
confirmée sans chemin d'attaque réaliste, impact et preuve reproductible.

## Périmètre et règles d'engagement

- N'agir que sur les actifs déclarés dans `security/scope.yml` ; ne jamais
  déduire un sous-réseau ou une cible supplémentaire.
- Les actions permises par défaut sont la revue de code, le scan de secrets,
  l'inventaire de services, l'inspection TLS, le scan web passif et l'inspection
  système en lecture seule.
- Arrêter et demander une approbation explicite juste avant toute exploitation
  active, attaque d'authentification, brute force, OAST, DoS, extraction de
  données, persistance, changement de privilèges, redémarrage, rebuild, ou
  modification de pare-feu/Docker.
- Ne jamais lancer Codex avec `sudo`, donner le socket Docker à `sobek`, ni
  contourner le collecteur d'état root en lecture seule.
- Ne jamais imprimer, committer, copier ou conserver un secret. Les preuves
  brutes vont hors du dépôt et les rapports les référencent sans les reproduire.

## Phases obligatoires

1. Figer le commit, la génération NixOS, les versions d'outils et les images.
2. Construire l'inventaire de surface d'attaque déclaré et observé, en IPv4 et
   IPv6 lorsqu'une adresse IPv6 autorisée est fournie.
3. Exécuter seulement le baseline permis et classifier chaque résultat comme
   `candidate`, `confirmed`, `false-positive`, `accepted-risk`, `fixed` ou
   `retested`.
4. Figer le rapport initial avant toute remédiation. Retester seulement les
   contrôles affectés après un changement revu et approuvé.

## Preuves et rapport

Pour chaque exécution, conserver la date, la machine d'origine, la commande,
la version de l'outil, la cible, l'artefact et l'identifiant de finding. Chaque
finding confirmé indique l'asset, les préconditions, l'impact, la sévérité, la
confiance, la cause racine, la preuve, la reproduction et le retest.

## Mode unattended baseline

Lorsqu'une tâche demande explicitement un "unattended baseline":

- ne jamais attendre une intervention humaine ;
- exécuter intégralement toutes les actions autorisées par `security/ROE.md`;
- lorsqu'une action nécessiterait une approbation humaine, NE PAS l'exécuter ;
- enregistrer cette action comme `deferred_requires_approval`;
- expliquer pourquoi elle serait utile ;
- continuer immédiatement avec les autres vérifications autorisées ;
- ne jamais remédier automatiquement à une vulnérabilité ;
- ne jamais modifier la configuration NixOS, Docker, nftables, les comptes,
  les services ou les données ;
- terminer le rapport même lorsque certaines vérifications sont impossibles.
