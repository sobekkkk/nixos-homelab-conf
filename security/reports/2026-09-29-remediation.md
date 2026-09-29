# Remédiation des constats de sécurité — 29 septembre 2026

Ce document complète le rapport initial en lecture seule, sans le modifier :
[`2026-09-29-white-box-read-only.md`](2026-09-29-white-box-read-only.md).
Les preuves brutes restent hors du dépôt.

## État figé avant modification

| Élément | Valeur observée |
| --- | --- |
| Révision du dépôt serveur | `9344d1a97226828cc369474856adbdde374495ac` |
| Génération NixOS active | `65g48ic8ij5fsgc3z85z5m04r8371z9v` |
| Entrée de boot courante | génération 21 |
| Snapshot disponible | `20260929T172948Z` |
| Portainer | actif, TCP/9443 publié, premier admin déjà initialisé (`GET /api/users/admin/check` : `204`) |

## Classification et traitement

| ID | État après revue | Traitement |
| --- | --- | --- |
| F-01 | corrigé dans la configuration | La garde Docker ne dépend plus d'une interface physique nommée. |
| F-02 | retest requis | Le collecteur enregistrera les profils noyau et l'ordre LSM ; l'état actuel n'établit pas encore leur nombre. |
| F-03 | risque accepté planifié | Aucun reboot uniquement pour aligner les générations ; validation au prochain redémarrage planifié. |
| F-04 | différé, non déployé | Déploiement Caddy/Kuma à réaliser via Portainer avant de retirer 9443. |
| F-05 | différé avec contrôle compensatoire | 9443 reste temporairement nécessaire ; le retrait suit la validation Caddy et de son autorité locale. |
| F-06 | corrigé dans la configuration | Les trois images sont épinglées par digest vérifié. |
| F-07 | corrigé opérationnellement | Cadence bihebdomadaire, délais et procédure documentés. |
| F-08 | non reproductible sur l'instance actuelle | Le premier administrateur existe déjà ; procédure de maintenance ajoutée pour toute recréation de volume. |

## Retests requis après activation

Après `nixos-rebuild test`, puis `switch` validé, déclencher le collecteur et
vérifier :

```bash
sudo systemctl start homelab-security-snapshot.service
sudo iptables -S HOMELAB-DOCKER-GUARD
sudo ip6tables -S HOMELAB-DOCKER-GUARD
cat /var/lib/homelab-security-snapshot/latest/lsm.txt
cat /var/lib/homelab-security-snapshot/latest/apparmor-profiles.txt
```

Le retest de F-04/F-05 ne commence qu'après le déploiement autorisé du stack
Caddy/Kuma. Aucun test d'authentification, scan actif ou recréation de volume
n'a été réalisé pour cette remédiation.
