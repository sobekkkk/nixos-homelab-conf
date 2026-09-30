# Rapport de baseline de sécurité

Statut : **baseline non destructive terminée**. Les résultats des outils sont des candidats ; aucune vulnérabilité n’est confirmée sans validation indépendante.

Run : 20260930T135101Z · Début (UTC) : 2026-09-30T13:51:02+00:00 · Révision : c2dbe3dc853bdfd3827533725d8562d6862a64db · Génération : /nix/store/n373nn2mxdnaf1gfijrk42cfy2k9v34k-nixos-system-homelab-26.05.20260927.cf5e765

## Périmètre et limites

Cible unique autorisée : 192.168.1.69; TCP autorisé : 22,443,9443,8443,8444. IPv6, autres hôtes, authentification, exploitation, scans actifs, fuzzing, OAST, changements de configuration et remédiation sont exclus.

## Méthodologie

Revue white-box de la révision figée, scan Git Gitleaks entièrement expurgé, évaluation Nix sans activation, inventaire de paquets, lecture du snapshot curaté et découverte de versions/TLS limitée aux ports déclarés.

## Surface testée

| Élément | Limite |
| --- | --- |
| Hôte réseau | 192.168.1.69 uniquement |
| TCP | 22,443,9443,8443,8444 uniquement |
| Dépôt | révision c2dbe3dc853bdfd3827533725d8562d6862a64db |
| Système | génération /nix/store/n373nn2mxdnaf1gfijrk42cfy2k9v34k-nixos-system-homelab-26.05.20260927.cf5e765 |

## Contrôles positifs vérifiés

Les contrôles dont l’artefact a été produit avec succès sont listés ci-dessous. Un succès de collecte ne confirme pas à lui seul la sécurité.

| Contrôle | État de collecte | Empreinte de preuve |
| --- | --- | --- |
| git-status | ok | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |
| nix-evaluation | ok | dacf32f21f67004899705065c0b634a1c8f141f38bcfe25cb2035fbbc29ed7ef |
| nix-flake-check | ok | 420292c499b873838c6b3fbae1ebb1f64f29e121bafd6779a68aedc205a0d085 |
| gitleaks | ok | efcfb625ed0e42cae4262e3af83859306610ea434dbf31ea89b9642929539c06 |
| trivy | ok | ecf68b96d737e242ffa2d4492da986f4f9f5aa4b4ec69b99b1a18a3c51dc65c1 |
| vulnix | exit-2 | fa10b5d5081f79706059f0e5743c7e3e95475e9258ff72fb7bf7530c969de7d8 |
| nmap | ok | 3827d47715b2d2c80e1bf819cad83ec631fe143f68c7fee2c114926eddbd2d63 |
| snapshot-checksums | ok | 497b80b2e923e75b0eec10a639601e41c1fd1b1e7e618d62561997062b0c91ab |

## Résultats et statut

Les codes non nuls ou observations de scanners restent des **candidats** à corréler avec la configuration effective ; ils ne sont pas des preuves d’exploitation. Analyse Codex complémentaire : disabled-by-operator.

| Vérification | Statut |
| --- | --- |
| git-status | ok |
| nix-evaluation | ok |
| nix-flake-check | ok |
| gitleaks | ok |
| trivy | ok |
| vulnix | exit-2 |
| nmap | ok |
| snapshot-checksums | ok |

## Preuves privées

Les artefacts bruts sont conservés hors Git dans le répertoire d’état privé de sobek (mode 0700). Ce rapport ne contient ni secrets, ni sorties de scanner, ni contenu de snapshot. Le propriétaire peut relier chaque empreinte ci-dessus au manifeste privé 20260930T135101Z.

## Actions différées nécessitant approbation

- Validation manuelle de tout candidat signalé par les artefacts privés.
- Toute exploitation, authentification, scan actif, OAST, IPv6, nouvelle cible/port, correction, rebuild, changement Docker/pare-feu/comptes ou redémarrage.

## Retest reproductible

Depuis /etc/nixos, avec le compte sobek déjà authentifié dans Codex si l’analyse complémentaire est souhaitée :

    ./security/scripts/run-unattended-baseline.sh --publish

Le runner crée une branche codex/pentest-*, valide le rapport puis pousse uniquement cette branche. Il ne publie jamais sur main.
