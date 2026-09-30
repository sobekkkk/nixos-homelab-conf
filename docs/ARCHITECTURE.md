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

Le pare-feu nftables bloque les entrées par défaut. SSH est accessible seulement
depuis le réseau local de confiance. Les redirections TCP ou socket Unix, le
transfert d'agent, X11 et les tunnels sont désactivés. SSH sert donc à
l'administration interactive et aux transferts de fichiers, sans devenir un
relais vers d'autres services du réseau.

Tailscale est installé directement sur l'hôte NixOS, jamais dans Docker. Il crée
une interface virtuelle `tailscale0` sur laquelle nftables n'accepte que SSH,
le relais HTTPS privé de Portainer (443) et celui de Kuma (8443). La politique
du tailnet décide quels appareils peuvent atteindre ces services, tandis que
`sshd` conserve ses contrôles de clé, de compte et de privilèges. Tailscale
Serve termine HTTPS puis relaie Portainer et Kuma localement ; il n'utilise
jamais Tailscale Funnel. Aucun port n'est ouvert sur le routeur ; le serveur
n'annonce ni route de sous-réseau ni exit node.
Portainer et les services Docker restent limités au LAN par `docker-lan-guard`.

Docker publie ses ports après traduction NAT ; ces ports ne passent donc pas
forcément par les règles `INPUT` classiques. Le service `docker-lan-guard`
installe une règle dans `DOCKER-USER` : tout port Docker publié est limité au
LAN IPv4 `192.168.1.0/24`, quelle que soit l'interface physique d'entrée, et
les arrivées IPv6 externes sont refusées. Les bridges Docker et la boucle locale
restent autorisés afin que les services internes puissent communiquer. Il n'y a
ni redirection de routeur, ni exposition Internet prévue par cette configuration.

## Conteneurs

Le moteur Docker est une brique de l'hôte NixOS ; il ne possède pas d'API TCP.
`sobek` n'appartient pas au groupe `docker`, car cet accès au socket serait
équivalent à `root`. Portainer CE est le seul conteneur démarré de manière
déclarative par NixOS : il sert de point de départ pour gérer les futurs stacks.

Son interface HTTPS est disponible sur `https://192.168.1.69:9443` depuis le
LAN. Le certificat initial est auto-signé. Depuis un appareil Tailscale autorisé,
elle est aussi disponible avec un certificat Tailscale sur
`https://homelab.tail239aaa.ts.net`. Les ports 8000 (Edge) et 9000 (HTTP
historique) ne sont pas publiés. Les données de Portainer vivent dans le volume
Docker nommé `portainer_data`; elles ne sont pas encore couvertes par une
sauvegarde automatisée.

Les applications sont des stacks Portainer documentés et versionnés dans un
dépôt privé distinct. Portainer les lit en GitOps par polling, sans webhook
public. Elles ne doivent pas être lancées à la main sur l'hôte ou ajouter un
port public sans une décision et une revue explicites. Le détail du flux est
dans [`GITOPS.md`](GITOPS.md).

Le premier stack de supervision est stocké dans `stacks/uptime-kuma/`. Caddy
expose TCP/443 sur l'adresse LAN `192.168.1.69` seulement, et garde Uptime Kuma
sur un réseau Docker privé. Kuma expose seulement `127.0.0.1:3001` à l'hôte :
Tailscale Serve le relaie en HTTPS privé sur le port 8443. Le port 443 de
l'adresse Tailscale reste réservé au relais HTTPS privé de Portainer. Caddy
rejoint aussi Portainer via le réseau `homelab-proxy`. Le proxy émet les certificats de
`portainer.home.arpa` et `status.home.arpa` via son autorité locale ; le poste
d'administration doit lui faire confiance avant que l'accès HTTPS soit considéré
comme entièrement vérifié. Pendant cette migration, 9443 reste disponible pour
valider le proxy puis sera retiré.

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
| `containers.nix` | Docker local, Portainer CE et garde réseau `DOCKER-USER`. |

## Principe d'évolution

Chaque nouveau service doit préciser au minimum :

1. son objectif et ses données ;
2. son mode d'accès et les ports nécessaires ;
3. sa stratégie de sauvegarde ;
4. comment le mettre à jour, le vérifier et le retirer.

Cette règle garde le projet accessible sans transformer chaque expérimentation
en dossier administratif.
