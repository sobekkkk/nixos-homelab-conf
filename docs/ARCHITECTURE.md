# Architecture

## Démarrage et chiffrement

```text
UEFI Secure Boot
        |
Lanzaboote / UKI signé
        |
Démarrage mesuré (PCR 0, 4, 7)
        |
TPM2 + PIN
        |
LUKS2 (cryptroot)
        |
NixOS
```

Le mot de passe LUKS et une clé de récupération restent les voies de secours.
Une sauvegarde du header LUKS est conservée hors de la machine, dans un endroit
sûr.

## Réseau

Le pare-feu nftables bloque les entrées par défaut. SSH est l'unique service
accessible et seulement depuis le réseau local de confiance. Les redirections
TCP ou socket Unix, le transfert d'agent, X11 et les tunnels sont désactivés.
SSH sert donc à l'administration interactive et aux transferts de fichiers,
sans devenir un relais vers d'autres services du réseau. L'accès distant, les
services web et les conteneurs ne sont pas encore exposés : ils seront
ajoutés avec leur propre documentation et leurs propres règles de pare-feu.

## Modules NixOS

| Module | Rôle |
| --- | --- |
| `base.nix` | Langue, fuseau horaire et fonctionnalités Nix. |
| `boot.nix` | Lanzaboote, Secure Boot et démarrage mesuré TPM2. |
| `firewall.nix` | nftables et règle SSH locale. |
| `hardening.nix` | AppArmor, sysctl et restrictions du noyau. |
| `networking.nix` | NetworkManager. |
| `ssh.nix` | Service SSH et ses restrictions. |
| `sudo.nix` / `users.nix` | Comptes locaux et élévation de privilèges. |
| `auditing.nix` | Journaux persistants et audit des chemins sensibles. |
| `maintenance.nix` | Nettoyage, optimisation et politique de mise à jour. |

## Principe d'évolution

Chaque nouveau service doit préciser au minimum :

1. son objectif et ses données ;
2. son mode d'accès et les ports nécessaires ;
3. sa stratégie de sauvegarde ;
4. comment le mettre à jour, le vérifier et le retirer.

Cette règle garde le projet accessible sans transformer chaque expérimentation
en dossier administratif.
