# Rapport de baseline de sécurité

Statut : **baseline non destructive terminée**. Les résultats des outils sont des candidats ; aucune vulnérabilité n’est confirmée sans validation indépendante.

Run : 20260930T134246Z · Début (UTC) : 2026-09-30T13:42:46+00:00 · Révision : c2dbe3dc853bdfd3827533725d8562d6862a64db · Génération : /nix/store/n373nn2mxdnaf1gfijrk42cfy2k9v34k-nixos-system-homelab-26.05.20260927.cf5e765

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
| gitleaks | ok | fd999a7d63a6c6f904268243fdc95ed4e3803965307725eb32858e8d5fe16f66 |
| trivy | ok | b66f8b14f44f1b0b098fcc06fc7bd9bca2b4698fb4f6b1c91831335f47888d9f |
| vulnix | exit-2 | fa10b5d5081f79706059f0e5743c7e3e95475e9258ff72fb7bf7530c969de7d8 |
| nmap | ok | 6fdc70f246a4144988414907e351f0a3dec40c1233444215176a8df474865bf8 |
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

Les artefacts bruts sont conservés hors Git dans le répertoire d’état privé de sobek (mode 0700). Ce rapport ne contient ni secrets, ni sorties de scanner, ni contenu de snapshot. Le propriétaire peut relier chaque empreinte ci-dessus au manifeste privé 20260930T134246Z.

## Actions différées nécessitant approbation

- Validation manuelle de tout candidat signalé par les artefacts privés.
- Toute exploitation, authentification, scan actif, OAST, IPv6, nouvelle cible/port, correction, rebuild, changement Docker/pare-feu/comptes ou redémarrage.

## Retest reproductible

Depuis /etc/nixos, avec le compte sobek déjà authentifié dans Codex si l’analyse complémentaire est souhaitée :

    ./security/scripts/run-unattended-baseline.sh --publish

Le runner crée une branche codex/pentest-*, valide le rapport puis pousse uniquement cette branche. Il ne publie jamais sur main.
