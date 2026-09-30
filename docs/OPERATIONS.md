# Manuel d'exploitation

## 1. Responsabilités et autorisations

sobek opère seul la plateforme. Les assistants préparent et inspectent avec
les droits ordinaires ; Codex n'est jamais lancé avec sudo.
Les actions privilégiées, rebuilds, redémarrages et modifications Docker/réseau
restent soumis aux règles [AGENTS.md](../AGENTS.md) et [ROE](../security/ROE.md).
Les commandes privilégiées ci-dessous sont des procédures pour l'opérateur,
pas une délégation implicite.

Avant toute maintenance réseau/boot : garder la session SSH, préparer une
seconde connexion et prévoir l'accès LAN/physique. Pas de reboot distant sans
possibilité de saisir le PIN TPM au démarrage.

## 2. Baseline quotidienne / après changement

Contrôles de lecture ordinaires :

```sh
hostname
date --iso-8601=seconds
systemctl --failed --no-pager
systemctl is-active docker tailscaled sshd docker-lan-guard docker-portainer
tailscale serve status
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
git -C /etc/nixos rev-parse HEAD
git -C /etc/nixos status --short
```

Résultat attendu : aucune unité échouée inexpliquée, points Serve attendus,
révision identifiée. Les unités Serve oneshot peuvent être active (exited) :
cela n'atteste pas un backend HTTP vivant.

Contrôler séparément l'accès LAN/Tailscale, les sondes Kuma et la fraîcheur des
graphiques Netdata. Éviter les captures affichant des identifiants.

## 3. Maintenance NixOS

Processus : [GITOPS.md](GITOPS.md). Pas d'auto-upgrade système.
Revue des avis au moins toutes les deux semaines ; correctifs des composants
exposés au LAN évalués sous sept jours ; revue mensuelle des autres changements.
Ce sont des objectifs opérateur, pas un SLA fournisseur démontré.

Une mise à jour de flake est un changement fonctionnel à relire :

```sh
cd /etc/nixos
nix flake update nixpkgs
git diff -- flake.lock
```

Ne pas changer system.stateVersion comme une version de paquet.
Lanzaboote et toute évolution de boot nécessitent une validation spécifique
Secure Boot/PCRLock et un moyen de récupération prêt.

GC : dimanche 03:15, délai aléatoire jusqu'à 30 minutes, âge 30 jours.
Optimisation : dimanche 04:15, même délai ; timers persistants.
Cela ne promet pas la conservation indéfinie d'anciennes générations.
Lanzaboote déclare quatre entrées ; contrôler le menu réellement disponible.

## 4. Retour arrière hôte

Si l'hôte reste accessible, après autorisation :

```sh
sudo nixos-rebuild switch --rollback
```

Sinon, choisir une génération précédente depuis la console/menu de démarrage.
Capturer le résultat et le motif ; réconcilier ensuite le code Git pour éviter
le redéploiement de la même erreur. Une génération précédente ne restaure
ni une base applicative ni un secret supprimé.

## 5. Vérifications privilégiées opérateur

```sh
sudo sbctl status
sudo cryptsetup status cryptroot
sudo iptables -S DOCKER-USER
sudo iptables -S HOMELAB-DOCKER-GUARD
sudo ip6tables -S DOCKER-USER
sudo ip6tables -S HOMELAB-DOCKER-GUARD
sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

Attendus : Secure Boot activé, cryptroot actif, garde référencée, seuls les
ports documentés publiés. Pas de socket Docker attribué à sobek pour simplifier
un diagnostic. Ne pas exporter docker inspect complet : il peut contenir des secrets.

## 6. Journaux et audit

journald persistant : plafond configuré 512M, réserve 2G, rétention maximale un
mois. auditd : 10 fichiers de 50 Mo, rotation ; suspension possible si disque
plein/erreur ; failureMode printk privilégie disponibilité. Quotas et durées ne
garantissent pas une conservation minimale. Pas d'export centralisé établi.

Opérateur : consulter le journal de l'unité affectée, période bornée, expurger
avant partage. Clés audit : nixos-configuration, ssh-configuration,
secure-boot-keys. Pas de debug webhook ni de collecte d'environnement.

Le snapshot quotidien ajoute un délai aléatoire de 15 min. sobek lit le dernier
snapshot curaté via homelab-audit ; aucun sudo ou socket donné à l'outil d'audit.
L'opérateur peut lancer le collecteur autorisé :

```sh
sudo systemctl start homelab-security-snapshot.service
```

Chaque fichier peut contenir une erreur de capture : présence du fichier ≠
succès du contrôle. Les preuves ne sont pas publiées brutes dans Git.
La politique tmpfiles déclare un âge de nettoyage 14 jours ; vérifier son
exécution plutôt que promettre une purge garantie.

## 7. Cadence d'exploitation

| Quand | Vérifier | Trace |
| --- | --- | --- |
| Après chaque activation | Accès, unités, images/ports, sondes, collecte | Commit + génération + résultat |
| Chaque semaine | Stockage, EFI, rétention, alertes bruyantes | Note datée si action |
| Toutes les deux semaines | Avis et versions amont | Mise à jour ou report motivé |
| Chaque mois | ACL/comptes, exceptions TLS, budget ressources | Décision et actions |
| Après incident | Cause, effet, correction et retest | Postmortem sans secret |

Pas de rotation de clé improvisée sans vérifier les utilisateurs dépendants.
Gestion des secrets : [DATA.md](DATA.md). Sauvegardes : chantier propriétaire
différé ; aucune configuration ou opération réalisée ici.
