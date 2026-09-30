# Réseau, DNS et TLS

## 1. Contrat

Administration uniquement LAN et tailnet. Pas d'entrée Internet publique
intentionnelle ; des sorties GitHub, registres, Tailscale et Discord existent.
Routeur, UPnP, IPv6 et ACL tailnet sont externes au code : ne pas les supposer sûrs.

## 2. Chemins déclarés

```mermaid
flowchart LR
    LAN[Client LAN] -->|TCP 22| SSH[OpenSSH via nftables]
    LAN -->|TCP 443 · home.arpa| C[Caddy]
    LAN -->|TCP 9443 · conservé| P[Portainer]
    T[Client tailnet autorisé] -->|TCP 22| SSH
    T -->|HTTPS 443| SP[Serve Portainer]
    T -->|HTTPS 8443| SK[Serve Kuma]
    T -->|HTTPS 8444| SN[Serve Netdata]
    SP -->|HTTPS 127.0.0.1:9443| P
    SK -->|HTTPS status.home.arpa:443| C
    SN -->|HTTPS netdata.home.arpa:8444| C
    C -->|HTTPS portainer:9443| P
    C -->|HTTP uptime-kuma:3001| K[Kuma]
    C -->|HTTP netdata:19999| N[Netdata]
```

Le filtrage des ports Docker publiés n'est pas le chemin INPUT de SSH/Serve.

## 3. Annuaire

| Service | LAN | Tailscale |
| --- | --- | --- |
| SSH | ssh sobek@192.168.1.69 | ssh sobek@100.120.235.24 ou homelab via MagicDNS |
| Portainer | https://portainer.home.arpa | https://homelab.tail239aaa.ts.net/ |
| Portainer direct | https://192.168.1.69:9443 | Non prévu directement |
| Kuma | https://status.home.arpa | https://homelab.tail239aaa.ts.net:8443/ |
| Netdata | https://netdata.home.arpa | https://homelab.tail239aaa.ts.net:8444/ |

LAN : 192.168.1.0/24 ; hôte : 192.168.1.69. Ces adresses décrivent
l'installation, pas une extension de l'autorisation de scan.
SSH exige une clé et une empreinte hôte vérifiée. Portainer/Kuma ont leurs
comptes applicatifs. Vérifier le mode d'identité Netdata ; ne pas en inventer un.

Les noms home.arpa doivent résoudre vers l'hôte sur les clients LAN ; leur DNS
client n'est pas provisionné ici. NixOS fournit seulement les mappings
status.home.arpa et netdata.home.arpa côté serveur pour le SNI des backends Serve.
Ne pas confondre Host HTTP et SNI TLS.

## 4. Flux autorisés par conception

| Source | Destination | Usage | Limite |
| --- | --- | --- | --- |
| LAN IPv4 | Hôte 22 | SSH | Source LAN, clé, AllowUsers |
| tailscale0 | Hôte 22,443,8443,8444 | Administration | nftables + ACL tailnet externe |
| LAN IPv4 | Docker 443,9443,8444 | HTTPS | DOCKER-USER ; Caddy lié à l'IP LAN |
| Caddy | Portainer 9443 / Netdata 19999 | Proxy | Bridge partagé homelab-proxy |
| Caddy | Kuma 3001 | Proxy | uptime-kuma-net interne |
| Kuma | Caddy 443 /health/* | Sondes | Chemin interne, pas test distant |
| Kuma | DNS / Discord HTTPS | Notifications | Bridge NAT kuma-egress |
| Netdata | Discord HTTPS | Alertes | Bridge homelab-proxy |
| Portainer / hôte | GitHub / registres | Déploiement | Sorties, identifiants si requis |

Les bridges partagés ne font pas de microsegmentation par service.
kuma-egress n'est pas une allowlist Discord : autres sorties possibles si l'hôte
les permet. Le réseau interne de Kuma ne neutralise pas son autre bridge NAT.

## 5. Garde Docker

Ports globalement autorisés vides dans le firewall NixOS. Les publications
Docker après DNAT traversent FORWARD : INPUT fermé ne suffit pas.
docker-lan-guard accroche HOMELAB-DOCKER-GUARD à DOCKER-USER.

Ordre IPv4 : established/related, loopback, docker0, bridges br-+, source LAN,
DROP. IPv6 : exceptions internes puis DROP, sans LAN IPv6 autorisé.
La garde IPv6 est installée seulement si DOCKER-USER IPv6 existe.
Retester après changement de backend Docker ; la garde n'est pas un filtrage
de toutes les sorties par destination.

## 6. TLS et exceptions

| Segment | Confiance actuelle |
| --- | --- |
| Client LAN → Caddy | CA interne ; racine à importer après vérification hors bande |
| Client tailnet → Serve | Certificat du nom Tailscale ; validation côté client |
| Serve → backend HTTPS | https+insecure : certificat backend non vérifié |
| Caddy → Portainer | tls_insecure_skip_verify : auto-signé non vérifié |
| Caddy → Kuma / Netdata | HTTP sur bridge ; pas TLS applicatif |
| Kuma → /health/* Caddy | Exception TLS pour les sondes internes uniquement |

TLS valide en façade n'est pas TLS vérifié de bout en bout. Retirer 9443 ne
supprime pas automatiquement l'exception Caddy → Portainer. Ne jamais importer
une racine récupérée sur un canal non authentifié ni partager sa clé privée.
Le vhost interne caddy n'est pas une URL cliente prévue ; il ne bénéficie pas
d'un contrôle d'origine distinct déclaré. Voir [STATUS.md](STATUS.md).

## 7. Contrôles

Tester chaque point depuis LAN puis tailnet autorisé. Les refus depuis une
autre origine exigent une cible de test explicitement autorisée. Pas de Funnel,
route annoncée, exit node ou redirection routeur à ajouter pour réparer un accès.
Diagnostic : [RUNBOOKS.md](RUNBOOKS.md).

Références : [Docker et pare-feu](https://docs.docker.com/engine/network/packet-filtering-firewalls/),
[Tailscale Serve](https://tailscale.com/docs/reference/tailscale-cli/serve).
