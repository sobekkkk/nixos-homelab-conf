# Supervision locale

Uptime Kuma est le premier service applicatif du homelab. Il est géré comme un
stack Portainer, pas comme un paquet installé sur l'hôte.

## Composition et exposition

Le stack `stacks/uptime-kuma/compose.yaml` contient :

- **Uptime Kuma 2.5.5**, avec ses réglages dans le volume local
  `uptime-kuma-data` ;
- **Caddy 2.11.4**, qui termine HTTPS avec une autorité locale, rejoint Kuma
  par le réseau Docker privé `uptime-kuma-net` et Portainer par
  `homelab-proxy`.

Kuma n'est publié que sur la boucle locale `127.0.0.1:3001`. Caddy publie
TCP/443 uniquement sur `192.168.1.69`, et la garde Docker le limite au LAN.
Tailscale Serve relaie Kuma vers le port HTTPS 8443 uniquement aux appareils
autorisés du tailnet ; le port 443 Tailscale reste réservé à Portainer. Les
ports 80, UDP/443, 8000 et 9000 ne sont pas publiés.

Pour cette migration, Caddy joint Portainer en HTTPS sur le réseau Docker privé
`homelab-proxy`, mais ne vérifie pas son certificat auto-signé en amont. Cette
exception ne concerne jamais les navigateurs : elle disparaîtra quand Portainer
recevra un certificat interne ou que son port direct aura été retiré et validé.

Les volumes `uptime-kuma-data`, `uptime-kuma-caddy-data` et
`uptime-kuma-caddy-config` ne sont pas encore sauvegardés. Les données de
supervision ne sont donc pas récupérables en cas de perte du disque.

## Déploiement dans Portainer

La configuration est un exemple sans secret suivi dans ce dépôt. Les prochains
stacks contenant des secrets ou données personnelles devront aller dans un dépôt
privé séparé.

Le premier déploiement a été fait le 30 septembre 2026 depuis l'éditeur Web de
Portainer, en copiant exactement le compose du commit `664f24a`. Cela a permis
de vérifier proprement l'initialisation du volume Kuma sans donner de droits
Docker à l'utilisateur de l'hôte. Les conteneurs `caddy` et `uptime-kuma` sont
respectivement *running* et *healthy*.

Le stack est maintenant lu par Portainer depuis le dépôt privé `homelab-apps`,
chemin `apps/uptime-kuma/compose.yaml`, sous le nom `uptime-kuma-gitops`.
Portainer vérifie le dépôt toutes les 15 minutes. Toute modification doit donc
être commitée dans ce dépôt privé ; ne jamais modifier le stack uniquement dans
son éditeur. Le Caddyfile est intégré au compose comme configuration Docker,
donc aucun montage relatif ni fichier séparé n'est nécessaire.

L'interface sera disponible à :

```text
https://portainer.home.arpa
https://status.home.arpa
https://homelab.tail239aaa.ts.net:8443
```

Les deux noms `*.home.arpa` doivent d'abord résoudre vers `192.168.1.69` sur le
PC d'administration. Leur certificat est émis par l'autorité locale Caddy.
L'URL Tailscale de Kuma est disponible hors du LAN depuis les appareils autorisés
du tailnet et utilise le certificat public Tailscale. Vérifier l'adresse locale
exacte avant toute exception navigateur ; l'import de l'autorité Caddy sur les
postes de confiance est le prochain raffinement.

La première étape garde temporairement `https://192.168.1.69:9443` disponible
afin de pouvoir déployer puis tester le proxy. Une fois les deux noms, le
certificat et les interfaces validés, une seconde modification supprimera ce
port direct de Portainer : TCP/443 deviendra la seule interface web publiée.

## Première configuration Kuma

Créer le compte administrateur avec un mot de passe long, unique et conservé
dans un gestionnaire de mots de passe. Commencer par des moniteurs TCP sans
secret : SSH (`192.168.1.69:22`), Portainer (`portainer.home.arpa:443`) et le
proxy HTTPS (`status.home.arpa:443`). Kuma conserve ses capacités Docker par
défaut pour initialiser son volume ; le stack garde néanmoins
`no-new-privileges` et ne lui publie aucun port. Ne pas utiliser de moniteur
ICMP/ping dans cette première version.

Notifications externes, webhooks et tokens seront ajoutés seulement lorsque
leur destination et leur stockage hors Git auront été décidés.

## Mise à jour et retrait

Modifier les versions d'image, relire le diff et redéployer le stack dans
Portainer. Ne jamais utiliser `latest` ou une commande Docker non documentée.
Pour retirer Kuma, arrêter le stack, exporter si nécessaire puis supprimer les
trois volumes uniquement si la perte de l'historique est voulue.
