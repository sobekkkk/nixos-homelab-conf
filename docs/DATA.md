# Données, secrets et identité

## 1. Configuration ≠ état

Git recrée les déclarations. Il ne contient pas les bases, historiques,
identités Tailscale, clés de boot ou comptes initiaux. Nix rollback ne restaure
pas ces éléments. La présente revue n'exécute aucun chantier de sauvegarde :
le propriétaire l'a différé et le réalisera séparément.

## 2. Inventaire d'état

| État | Emplacement déclaré | Sensibilité / impact |
| --- | --- | --- |
| Config NixOS | /etc/nixos + Git public | Intégrité : activation privilégiée |
| Portainer | portainer_data | Comptes, accès Git, contrôle Docker |
| Kuma | uptime-kuma-data | Comptes, sondes, webhook et historique |
| CA / état Caddy | uptime-kuma-caddy-data | Clé privée CA ; usurpation TLS possible |
| Config Caddy | uptime-kuma-caddy-config | État proxy ; source principale dans Compose |
| Netdata config | netdata-config | Paramètres locaux, source déclarée Compose |
| Netdata état | netdata-lib | Identité et historique/état selon agent |
| Netdata cache | netdata-cache | Données de métriques selon agent |
| Secret Discord Netdata | /var/lib/homelab-secrets/netdata-discord.conf | URL webhook ; fragment shell de confiance |
| PKI Secure Boot | /var/lib/sbctl | Clés sensibles, non recréées par flake |
| LUKS / TPM / EFI | Header, tokens, TPM, /boot | Accès disque et démarrage |
| Tailscale / SSH | État daemon et clés hôte | Identité machine ; pas de valeur dans Git |
| Journaux | journald / auditd | Informations opérationnelles sensibles |
| Snapshot curaté | /var/lib/homelab-security-snapshot | Preuves expurgées, root:homelab-audit |

Aucun emplacement de secret n'autorise sa lecture par un assistant.
Même les volumes de supervision doivent être traités comme sensibles.

## 3. Provisionnement des secrets

Netdata bind le fichier secret en lecture seule, create_host_path false.
Répertoire parent root 0700, fichier root 0644 selon le guide privé existant :
l'utilisateur de service le lit dans le conteneur, les comptes ordinaires
ne traversent pas le répertoire hôte. Root/Docker restent capables d'y accéder.
Le fragment shell n'est modifiable que par un administrateur de confiance.

Le webhook Kuma se configure dans l'application et reste dans son volume.
Le jeton GitHub lecture du dépôt privé est conservé par Portainer. Les secrets
ne doivent pas être passés par une commande enregistrée, une conversation,
une capture, un log debug ou un fichier public. Un secret partagé doit être
révoqué ; retirer le texte ne le rend pas secret à nouveau.

## 4. Rotation

1. Identifier le propriétaire, les lecteurs et l'impact d'une révocation.
2. Générer le remplaçant côté fournisseur et le saisir sur le canal sûr prévu.
3. Pour Netdata, éditer le fichier root ; le bind peut conserver un ancien inode :
   recréation du conteneur dans une activation autorisée.
4. Vérifier la réception sur la destination attendue sans partager la valeur.
5. Révoquer l'ancien secret et consigner uniquement le résultat/date.

Ne pas collecter docker inspect brut, l'environnement ou les configs sensibles
pour « vérifier » une rotation. Pas de NETDATA_ALARM_NOTIFY_DEBUG.

## 5. Ce qui reste externe / manuel

Installation initiale et matériel, enrollement TPM/PIN, clés Secure Boot,
passphrases et recovery, connexion Tailscale et ACL, CA clients, comptes
applicatifs, webhook et autorisations GitHub. Les comptes/sondes Kuma ne sont
pas tous provisionnés comme code. Cette plateforme est déclarative pour ses
déploiements, pas une full recovery automatisée.

Un futur travail de restauration devra fixer RPO/RTO et tester les données.
Aucun RPO/RTO n'est attesté aujourd'hui ; ne pas prétendre qu'un header LUKS
hors machine constitue une copie des fichiers.
