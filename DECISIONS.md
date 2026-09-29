# Décisions de sécurité

Ce journal explique simplement les choix qui demandent un compromis. Il ne
contient jamais de secret, de clé, de jeton ou de donnée de volume.

## 2026-09-29 — Remédiation des constats F-01 à F-08

### Garde des ports Docker

La garde `DOCKER-USER` ne dépend plus de `wlp0s20f3`. Tout trafic entrant vers
un port Docker publié est refusé hors du LAN IPv4, quelle que soit l'interface
physique. Les bridges Docker (`docker0` et `br-*`) et `lo` restent autorisés :
ce sont des chemins internes indispensables, notamment pour Caddy vers
Portainer. Cette exception ne donne pas d'accès depuis le LAN.

### Images immuables

Portainer, Caddy et Uptime Kuma sont conservés avec leur tag lisible et épinglés
sur un digest de manifeste Docker Hub vérifié le 29 septembre 2026. Une mise à
jour devient donc un changement volontaire de tag **et** de digest, plutôt
qu'un nouveau contenu reçu silencieusement sous le même tag.

### AppArmor : preuve avant promesse

AppArmor est chargé et son service est actif, mais l'ancien snapshot ne pouvait
pas énumérer les profils. Le collecteur enregistrera désormais l'ordre LSM, la
sortie `aa-status` et la liste noyau des profils séparément. La prochaine
capture permettra de dire si les profils sont réellement appliqués ; cette
décision améliore la preuve sans prétendre qu'un profil absent existe.

Le retest du 29 septembre a confirmé une liste de profils vide. Les profils
distribués par `apparmor-profiles` ne ciblent pas les chemins immuables du Nix
store ni Portainer/Docker. Les charger au hasard serait du durcissement décoratif
et pourrait bloquer des services. F-02 reste donc ouvert : une phase dédiée
créera des profils par service, d'abord en `complain`, puis en `enforce` après
lecture des refus et test de fonctionnement.

### Mises à jour contrôlées

Les mises à jour automatiques restent désactivées : une mise à jour non revue
peut modifier le boot, le réseau ou les images. En contrepartie, une revue
bihebdomadaire et des délais maximums sont désormais documentés dans
`docs/OPERATIONS.md`.

### Propriété du dépôt NixOS

`/etc/nixos` est confié à `sobek` pour que les opérations Git ordinaires ne
créent plus un mélange de fichiers `root` et `sobek`, qui empêchait les mises à
jour. Cette propriété ne rend pas un changement actif : seul `sudo
nixos-rebuild` peut l'appliquer. La revue du diff et le mot de passe restent la
frontière entre l'édition de la source et l'activation système.

### Ce qui reste volontairement différé

- Caddy/Uptime Kuma ne sont pas encore déployés : enlever 9443 avant que le
  proxy HTTPS soit vérifié couperait Portainer. La migration reste donc à faire
  depuis Portainer, suivie de l'import de l'autorité Caddy sur les clients de
  confiance, puis du retrait de 9443.
- Le contrôle Portainer a répondu `204` le 29 septembre 2026 : le premier
  administrateur existe déjà. Le risque F-08 ne touche donc pas l'instance
  actuelle. Une recréation future de `portainer_data` exigera une fenêtre de
  maintenance et une restriction temporaire de 9443 au poste administrateur.
- La génération de démarrage actuelle est plus ancienne que la génération par
  défaut, situation normale après `switch` sans reboot. Aucun redémarrage n'a
  été déclenché uniquement pour aligner ces numéros ; il sera validé avec une
  voie de récupération lors d'une maintenance planifiée.
