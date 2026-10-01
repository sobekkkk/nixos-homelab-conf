# Décisions de sécurité

## 2026-09-30 — Dossier d'architecture et manuel d'exploitation

La documentation est restructurée en architecture, réseau/TLS, GitOps,
exploitation, runbooks, supervision, données/secrets, amorçage et état attesté.
Les schémas Mermaid restent dans Git pour suivre les changements de code.
Le dossier reprend une démarche d'ingénierie/SRE, sans inventer de cluster,
certification, SLO ni haute disponibilité.

Les deux sources sont figées pour cette revue : infrastructure main `3de2ac3`,
applications main `768f95f`. Les rapports historiques restent inchangés.
Les sauvegardes sont différées au propriétaire conformément à sa demande ;
aucune opération de sauvegarde, de déploiement ou de durcissement n'est lancée.
Les contrôles portent sur les liens et blocs documentaires et la concordance
des descriptions avec les sources, pas sur un nouveau retest serveur.

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

## 2026-09-30 — Netdata sans socket Docker

Netdata complète Uptime Kuma : Kuma teste la disponibilité, Netdata sert à
comprendre l'état de l'hôte, des unités systemd et des cgroups Docker en temps
réel. Il est conteneurisé et versionné dans le dépôt GitOps privé, sans port
hôte. Caddy le publie seulement sur le LAN et Tailscale Serve seulement aux
appareils autorisés du tailnet, sur le port HTTPS distinct 8444.

Le socket Docker n'est pas partagé avec Netdata. Une analyse des proxys de
socket disponibles a montré qu'un accès global aux endpoints `containers`, même
en GET-only, peut exposer journaux, processus ou systèmes de fichiers de tous
les conteneurs. Cette visibilité n'est pas nécessaire pour les métriques de
ressources : Netdata observe les cgroups en lecture seule, et Portainer reste
l'inventaire et le point d'administration Docker. Ce compromis réduit fortement
la portée d'une compromission de Netdata sans perdre la supervision utile.

## 2026-09-30 — Relais Netdata séparé du vhost Kuma

Les deux services Tailscale utilisent le même nom public du tailnet. Lorsqu'ils
étaient tous deux relayés vers Caddy sur TCP/443, le nom HTTP du client pouvait
sélectionner le vhost Kuma, même via le port externe 8444. Caddy publie donc un
listener TCP/8444 distinct, lié uniquement à l'adresse LAN. Tailscale Serve le
rejoint localement pour Netdata ; Kuma garde son relais vers le vhost HTTPS
`status.home.arpa` sur 8443. Netdata reste sans port direct : seul Caddy est
publié, et `docker-lan-guard` limite le listener intermédiaire au LAN.

Le relais Tailscale utilise néanmoins le nom `netdata.home.arpa:8444`, et non
l'adresse IP du listener : Caddy doit recevoir un SNI qui correspond à un
certificat interne. Ce nom est résolu localement de façon statique vers
`192.168.1.69`; les clients ne le voient jamais, car Tailscale termine leur TLS
avec le certificat public du tailnet.

## 2026-10-01 — Passerelle privée dans une VM NixOS dédiée

Séparer le routage Tailscale/Mullvad/AdGuard des applications Docker et du
réseau administratif de l'hôte. QEMU tourne sous un compte sans sudo ni socket
Docker ; réseau utilisateur, SSH bootstrap uniquement sur loopback 2222.
Une exception PermitOpen limitée à ce port remplace l'interdiction globale
des tunnels uniquement pour ce besoin de bootstrap. L'accès LAN/Tailscale
actuel du serveur doit rester indépendant de la sortie VPN.

Les sources de la VM résident dans `hosts/privacy-gateway`, celles du
superviseur dans `modules/privacy-gateway-vm.nix`. La flake construit directement
l'invité avec son nixpkgs verrouillé : pas de pointeur externe vers un ancien
artefact du store, ni d'évaluation impure nécessaire au déploiement.

La clé privée est saisie par le propriétaire hors chat, fichier hôte root:root
0600, puis LoadCredential et partage invité en lecture seule. Aucun secret
dans Git, le Nix store ou les logs. Le compte invité à clé gateway-admin a
sudo sans mot de passe dans l'invité uniquement ; pas de délégation sudo hôte.

Les configurations invité/hôte compilent. La première activation reste un
`test`, avec backup, avant recette IPv4/IPv6/DNS/kill switch et persistance.
Les règles client Android/TV non gérés ne sont pas un verrouillage obligatoire
de la sortie. Déploiement et tests runtime non encore réalisés ; voir
`docs/PRIVACY_GATEWAY.md`. Le propriétaire accepte les commandes sudo manuelles.

La première recette a identifié un montage masqué par qemu-vm, un enregistrement
du store read-only impossible, et un conflit de priorités wg-quick/Tailscale.
Choix correctifs : mount unit explicite, Nix désactivé dans l'appliance immuable,
table/priorités de routage explicites. Les tests runtime invités et SSH/DNS
Tailscale passent après corrections transitoires ; le redémarrage autonome et
le test exit node client restent à valider avant persistance.

Le deuxième test a révélé que NixOS encapsule postUp dans un script : `%i`
n'y est pas interpolé par wg-quick. Employer le nom d'interface explicite
pour le fwmark, sans changer les exceptions du pare-feu. Correctif runtime
validé IPv4/IPv6/DNS ; nouvelle activation requise pour prouver sa persistance.
L'approbation Tailscale de l'exit node est maintenant vérifiée depuis Windows
et l'invité (routes par défaut IPv4/IPv6 autorisées).

Le premier essai exit node Windows a confirmé le routage HTTPS mais révélé
un défaut DNS : avec resolved et resolvconf désactivés, networking.nameservers
ne créait pas /etc/resolv.conf. Déclarer explicitement ce fichier vers
127.0.0.1 (AdGuard uniquement), car le proxy DNS exit node Tailscale le lit.
Aucun résolveur de secours externe n'est ajouté. La correction runtime rend
la résolution Windows et l'API Mullvad fonctionnelles via l'exit node.

## Débit de la passerelle : conserver la sortie stricte, corriger la MTU

La MTU initiale 1280 de Mullvad fragmentait le transport chiffré Tailscale
(dont l'interface interne est elle-même à 1280). Un téléchargement client
de 2 Mo à MTU 1280 plafonnait à 72 136 octets/s et échouait au timeout,
avec 3 864 fragments IPv4 supplémentaires. Passer seulement wg-mullvad à
1420 a supprimé la croissance de ce compteur pendant les nouveaux tests.
L'uplink invité reste à 1500 et tailscale0 à 1280. Choix : aucun bypass du
transport Tailscale vers l'uplink, aucun DNS de secours, aucun assouplissement
du kill switch. MSS non modifiée faute de preuve qu'une correction soit requise.

Mesures client de 8 Mo : 10,79 Mbit/s IPv4 et 13,62 Mbit/s IPv6. Ce sont des
mesures ponctuelles HTTP, pas une garantie de débit IPTV ou de capacité maximale.
Test VPN coupé depuis Windows : HTTPS avec adresses forcées en IPv4 et IPv6
expire sans succès, puis le tunnel rétabli confirme Mullvad exit IP true.
La nouvelle configuration compile ; prochaine activation test requise avant
persistance. Aucun contournement universel des filtrages FAI/plateformes promis.

Après activation test et switch propriétaire, les générations active et
persistée sont identiques (dw1g960133js7dar8lck17irv13nvxnj), services hôte
actifs et sortie Mullvad confirmée. Pas de reboot hôte ni de validation TV
revendiqués. Guide clients sans verrouillage MDM : une connexion Tailscale
seule ne force pas l'exit node. Sauvegardes et états externes restent distincts.
# 2026-10-01 — Portail Homepage privé (préparé)

Homepage est un portail de liens, pas un nouveau monitoring. Réutiliser Caddy
et ajouter un relais Tailscale dédié sur 8445 conserve les trois accès actuels.
Pas de socket Docker, de widget à secrets ou de découverte automatique ;
configuration applicative inline, image tag/digest, processus non-root et
stockage éphémère borné. Allowed-hosts n'est pas une authentification : LAN de
confiance et politique tailnet restent les frontières d'accès. Une auth
applicative serait requise si ce périmètre devenait non fiable. Les ACL externes
Tailscale ne sont pas changées par cette proposition.

Publication sur branches uniquement avant approbation explicite des actions
Docker, pare-feu et rebuild. Recette client et runtime à exécuter avant de
revendiquer un déploiement fonctionnel. Sauvegardes toujours hors chantier.
