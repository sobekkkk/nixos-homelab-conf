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
- SSH accessible uniquement depuis le réseau local ;
- pare-feu nftables sans port ouvert globalement ;
- AppArmor, paramètres noyau de durcissement, journaux persistants et audit
  local des fichiers sensibles.
- Docker local, avec Portainer CE comme interface unique des conteneurs ;
- Portainer disponible uniquement en HTTPS sur le LAN, avec une garde dédiée
  contre le contournement du pare-feu par les ports Docker publiés.

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
conteneurs sont dans [docs/CONTAINERS.md](docs/CONTAINERS.md).

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
- [ ] Premier service applicatif, avec données et sauvegarde définies ;
- [ ] Supervision locale et alertes ;
- [ ] Revue de sécurité de l'infrastructure avec un périmètre explicite.

## Participer ou proposer une idée

Pas besoin d'être expert. Une correction de documentation, une question ou une
idée de service est déjà une contribution utile. Le petit guide
[CONTRIBUTING.md](CONTRIBUTING.md) explique la manière de garder les changements
simples et vérifiables.
