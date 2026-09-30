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

- Le retrait de TCP/9443 attend la validation de Caddy depuis un appareil du
  LAN et l'import de son autorité sur les clients de confiance. Le relais
  Tailscale est déjà une voie d'administration distante sûre, mais ne remplace
  pas ce test LAN ; conserver 9443 évite de perdre une voie de récupération.
- Le contrôle Portainer a répondu `204` le 29 septembre 2026 : le premier
  administrateur existe déjà. Le risque F-08 ne touche donc pas l'instance
  actuelle. Une recréation future de `portainer_data` exigera une fenêtre de
  maintenance et une restriction temporaire de 9443 au poste administrateur.
- La génération de démarrage actuelle est plus ancienne que la génération par
  défaut, situation normale après `switch` sans reboot. Aucun redémarrage n'a
  été déclenché uniquement pour aligner ces numéros ; il sera validé avec une
  voie de récupération lors d'une maintenance planifiée.

## 2026-09-30 — Tailscale limité à SSH

Tailscale est exécuté sur l'hôte, et non dans Docker : il doit pouvoir joindre
le réseau avant les conteneurs et rester disponible pour l'administration de
récupération. L'interface `tailscale0` n'est pas déclarée « fiable » dans son
ensemble. nftables accepte uniquement TCP/22 depuis cette interface ; ainsi un
futur service écoutant sur l'hôte ne deviendra pas automatiquement accessible
au tailnet.

Le serveur ne sera ni routeur de sous-réseau, ni exit node, ni point de
publication Tailscale Funnel. L'autorisation des appareils distants reste dans
la politique du tailnet, puis SSH exige toujours la clé du compte `sobek`.

## 2026-09-30 — Portainer privé via Tailscale Serve

Le port 9443 de Portainer reste limité au LAN par la garde Docker. Pour
l'administration hors domicile, Tailscale Serve termine HTTPS sur
`homelab.tail239aaa.ts.net` et relaie exclusivement vers `127.0.0.1:9443`.
Cette exposition est réservée aux appareils autorisés du tailnet et n'utilise
pas Tailscale Funnel : aucun port n'est ajouté au routeur et aucun service
applicatif ou de supervision ne rejoint le tailnet.

Le relais fait confiance au certificat auto-signé seulement sur la boucle
locale, entre `tailscaled` et Portainer. Le navigateur reçoit le certificat
public du nom Tailscale. Le compte Portainer reste une capacité d'administration
Docker équivalente à `root` : seuls les appareils personnels et de confiance
doivent être autorisés par la politique Tailscale.

## 2026-09-30 — Séparation du port HTTPS LAN et Tailscale

Tailscale Serve utilise TCP/443 sur l'adresse Tailscale du serveur, tandis que
Caddy sert les noms `*.home.arpa` uniquement au LAN. Le stack Caddy est donc
lié explicitement à `192.168.1.69:443`, plutôt qu'à toutes les interfaces.
Cette séparation évite un conflit de port et garantit qu'Uptime Kuma et Caddy
ne deviennent pas accessibles depuis le tailnet par effet de bord.

## 2026-09-30 — Capacités nécessaires à Uptime Kuma

Uptime Kuma ne démarrait pas avec `cap_drop: ALL` : l'image ne pouvait plus
créer son répertoire `data/upload/` dans le volume persistant. Cette restriction
est retirée pour Kuma, mais `no-new-privileges` et l'absence de port hôte ou de
socket Docker restent appliqués. Caddy conserve, lui, ses capacités minimales.
Une réduction supplémentaire devra être testée avec un profil de service réel,
pas ajoutée au hasard.

## 2026-09-30 — Premier déploiement de la supervision

Le stack Caddy/Uptime Kuma est déployé et vérifié dans Portainer : Caddy est
*running* sur `192.168.1.69:443`, Kuma est *healthy* et ne publie aucun port
hôte. L'adresse Tailscale garde son propre TCP/443 pour Portainer Serve. Le
déploiement a utilisé l'éditeur Web de Portainer à partir du commit `664f24a`;
ce compromis est temporaire car le dépôt actuel est public. Les futurs stacks
avec données ou secrets seront placés dans un dépôt privé et déployés en mode
Git afin de supprimer le risque de dérive entre Portainer et la source revue.

## 2026-09-30 — GitOps applicatif sans webhook public

L'hôte reste déclaré dans NixOS, tandis que les futurs stacks Compose vivront
dans un dépôt Git privé dédié. Portainer utilisera GitOps en polling plutôt
qu'un webhook : le serveur reste non publié sur Internet et chaque mise à jour
applicative part d'un commit relu. Les identifiants Git, lorsqu'ils seront
nécessaires, auront seulement un droit de lecture sur ce dépôt et resteront
dans Portainer, jamais dans la configuration NixOS ou dans Git.

## 2026-09-30 — Migration d'Uptime Kuma vers GitOps

Le premier stack applicatif a été recréé depuis le dépôt privé `homelab-apps`.
Portainer suit `apps/uptime-kuma/compose.yaml` toutes les 15 minutes, sans
redéploiement forcé ni webhook Internet. La suppression contrôlée de l'ancien
stack n'a pas supprimé les volumes nommés : Kuma a repris son état et est
*healthy*, tandis que Caddy est *running*. Le nom Portainer
`uptime-kuma-gitops` évite une collision avec l'ancien enregistrement pendant
la migration ; il n'affecte ni les volumes, ni l'exposition réseau.

## 2026-09-30 — Kuma privé via Tailscale Serve

Kuma reste isolé du LAN et d'Internet : le conteneur n'écoute que sur
`127.0.0.1:3001`. Tailscale Serve termine HTTPS avec le certificat du tailnet
et le relaie exclusivement sur TCP/8443 pour les appareils autorisés. Ce port
séparé évite une réécriture d'URL fragile et laisse TCP/443 au relais Portainer.
La règle nftables est limitée à `tailscale0`; aucun Funnel, port routeur ou
accès Docker supplémentaire n'est ajouté.

## 2026-09-30 — Relais local Docker pour Kuma

L'inspection de Kuma a confirmé la demande de publication
`127.0.0.1:3001:3001`, mais le moteur Docker ne créait pas la destination
effective avec `userland-proxy = false`. Le proxy utilisateur Docker est donc
réactivé. Kuma reste strictement sur la boucle locale : aucune interface LAN,
Tailscale ou Internet n'est ajoutée. Cette dépendance est préférable à une
adresse IP de conteneur, qui changerait lors d'un redéploiement GitOps.

## 2026-09-30 — nftables disponible pour Docker

Les journaux du démon Docker 29 ont montré que `nft` était absent de son
environnement systemd. Le démon ne pouvait donc pas réinstaller les règles
NAT d'une publication de port après un redémarrage. Le paquet `nftables` est
ajouté uniquement au `PATH` du service Docker. Cela rétablit la publication
locale de Kuma tout en laissant la garde `DOCKER-USER` et les restrictions
d'interface inchangées.

## 2026-09-30 — Kuma via Caddy plutôt qu'un port Docker local

La publication `127.0.0.1:3001` de Kuma restait inactive après redémarrage du
daemon, malgré sa présence dans la configuration du conteneur. La solution
retenue ne dépend plus du NAT Docker : Kuma reste sur son réseau privé et Caddy
est son unique proxy. Tailscale Serve rejoint Caddy sur l'adresse LAN locale,
en conservant le nom MagicDNS qui sélectionne le vhost Kuma. Le port public du
tailnet reste 8443, sans Funnel ni ouverture de routeur. Les essais de proxy
utilisateur et d'ajout de `nft` au démon sont retirés : ils ne sont plus utiles.

## 2026-09-30 — SNI stable entre Tailscale Serve et Caddy

Le relais Tailscale vers l'adresse IP de Caddy ne fournissait pas le nom TLS
attendu par Caddy. Le serveur résout désormais `status.home.arpa` par une
entrée statique vers son IP LAN, puis Tailscale Serve utilise ce nom comme
backend HTTPS. Ce choix évite une dépendance au DNS du routeur et conserve un
certificat Caddy cohérent, tandis que le client final reçoit toujours le
certificat Tailscale public sur le port 8443.
