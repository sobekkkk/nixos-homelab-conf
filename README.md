# NixOS Homelab

Bienvenue dans la configuration NixOS de mon homelab personnel. C'est un projet
pour apprendre, expérimenter et héberger des services sans perdre de vue deux
choses simples : comprendre ce qui tourne, et pouvoir revenir en arrière.

Le dépôt est volontairement modulaire. Il n'a pas besoin d'être un projet
"parfait" pour être utile : les choix sont documentés au fur et à mesure et les
améliorations sont bienvenues.

## État actuel

- NixOS 26.05, configuration gérée avec des flakes ;
- Codex CLI installé de manière déclarative pour assister l'administration ;
- disque système chiffré avec LUKS2 ;
- déverrouillage TPM2 + PIN, lié au démarrage mesuré (PCR 0, 4 et 7) ;
- Secure Boot avec Lanzaboote et `sbctl` ;
- SSH accessible depuis le réseau local et, après l'activation de Tailscale,
  depuis les appareils d'administration autorisés du tailnet ;
- pare-feu nftables sans port ouvert globalement ;
- AppArmor, paramètres noyau de durcissement, journaux persistants et audit
  local des fichiers sensibles.
- Docker local, avec Portainer CE comme interface unique des conteneurs ;
- Portainer disponible uniquement en HTTPS sur le LAN, avec une garde dédiée
  contre le contournement du pare-feu par les ports Docker publiés.
- HTTPS local avec Caddy sur le LAN : Portainer et la supervision sont servis
  sous les noms `*.home.arpa`, sans exposition Internet.
- Uptime Kuma, isolé derrière Caddy et géré comme stack Portainer ;
- Netdata, isolé derrière Caddy, pour les métriques détaillées du serveur,
  systemd et des workloads Docker sans socket Docker ;
- modèle GitOps documenté pour que les prochaines applications Docker soient
  déployées depuis une source versionnée.

## Organisation

```text
.
├── flake.nix                 # Point d'entrée de la configuration
├── hosts/homelab/            # Ce qui est propre à cette machine
└── modules/                  # Briques réutilisables : boot, SSH, réseau…
```

Les explications un peu plus détaillées sont dans [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
et les commandes du quotidien dans [docs/OPERATIONS.md](docs/OPERATIONS.md). La
configuration et les précautions propres à l'agent sont décrites dans
[docs/CODEX.md](docs/CODEX.md). Le périmètre de sécurité est défini dans
[SECURITY.md](SECURITY.md) et les scénarios à auditer dans
[docs/THREAT_MODEL.md](docs/THREAT_MODEL.md). Les règles simples pour les
conteneurs sont dans [docs/CONTAINERS.md](docs/CONTAINERS.md). La supervision
locale est expliquée dans [docs/SUPERVISION.md](docs/SUPERVISION.md).
Le chemin prévu pour les applications Docker est décrit dans
[docs/GITOPS.md](docs/GITOPS.md).

## Appliquer une modification

Depuis le serveur :

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake .#homelab
```

Pour tester une génération sans la définir comme génération de démarrage :

```bash
sudo nixos-rebuild test --flake .#homelab
```

Une génération NixOS précédente reste disponible dans le menu de démarrage : ne
pas improviser une commande risquée reste malgré tout la meilleure stratégie.

## Sécurité et secrets

Ce dépôt doit rester publiable. Ne jamais y ajouter :

- clé privée, mot de passe, token ou fichier `.env` ;
- clé de récupération LUKS ou sauvegarde du header LUKS ;
- données personnelles ou sauvegardes de services.

Les sauvegardes de header LUKS doivent rester chiffrées, hors du serveur et hors
de Git.

## Feuille de route

- [x] Chiffrement du système, Secure Boot et TPM2 ;
- [x] Socle réseau et SSH durci ;
- [x] Audit local et maintenance régulière du store Nix ;
- [x] Politique de sécurité et modèle de menaces documentés ;
- [x] Base Docker et Portainer CE restreints au LAN ;
- [ ] Sauvegardes automatisées vers une destination à choisir ;
- [x] Premier service de supervision déployé sans exposition Internet ;
- [x] HTTPS local unifié et supervision Uptime Kuma déployée ;
- [x] Observabilité temps réel de l'hôte et des conteneurs avec Netdata ;
- [x] Dépôt privé et GitOps par polling pour les applications Docker ;
- [ ] Revue de sécurité de l'infrastructure avec un périmètre explicite.

## Participer ou proposer une idée

Pas besoin d'être expert. Une correction de documentation, une question ou une
idée de service est déjà une contribution utile. Le petit guide
[CONTRIBUTING.md](CONTRIBUTING.md) explique la manière de garder les changements
simples et vérifiables.
