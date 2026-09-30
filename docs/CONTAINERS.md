# Conteneurs sans bazar

Cette page pose les règles de départ pour héberger de petits services sans
transformer le serveur en collection de commandes oubliées.

## Qui fait quoi ?

| Couche | Responsable | But |
| --- | --- | --- |
| Hôte | NixOS | Docker, pare-feu, mises à jour système, journaux et sécurité. |
| Interface | Portainer CE | Voir les conteneurs et déployer les futurs stacks Docker. |
| Applications | Stacks Portainer | Un service précis, ses données, ses variables et sa documentation. |

Portainer est lui-même déclaré dans NixOS pour éviter le paradoxe d'un outil
qui devrait se déployer lui-même. Il est le seul conteneur de départ. Tous les
autres services passeront par une stack Portainer, idéalement suivie dans un
dépôt Git privé séparé de la configuration NixOS. Le modèle de déploiement est
décrit dans [`GITOPS.md`](GITOPS.md) : Portainer lira les stacks depuis Git et
les appliquera automatiquement par polling, sans rendre le serveur public.

## Accès initial

Depuis le LAN, ouvrir :

```text
https://192.168.1.69:9443
```

Portainer crée d'abord un certificat auto-signé. L'avertissement du navigateur
est normal tant qu'il concerne exactement cette adresse locale. Créer ensuite
le premier administrateur avec un mot de passe long, unique et conservé dans un
gestionnaire de mots de passe. Le port 9443 est le seul port Portainer publié.

Portainer reçoit le socket Docker en écriture pour pouvoir administrer Docker :
une compromission de son compte administrateur ou de Portainer a donc un impact
proche de `root` sur cet hôte. Cela explique le choix LAN uniquement, HTTPS, pas
de compte `docker` pour `sobek`, et pas d'exposition Internet directe.

## Règle réseau importante

Les ports publiés par Docker peuvent contourner les règles pare-feu normales.
`docker-lan-guard` s'exécute avant Portainer et restreint la chaîne Docker
`DOCKER-USER` au LAN IPv4, quelle que soit l'interface physique par laquelle
le trafic arrive. Il bloque aussi les arrivées IPv6 externes vers les ports
Docker publiés. Les bridges Docker et la boucle locale sont les seules
exceptions, nécessaires aux communications internes entre conteneurs.

Ce n'est pas une autorisation d'exposer librement des services : un nouveau port
reste une décision documentée. Les ports 80/443, un nom de domaine, un proxy
inverse et un accès depuis Internet sont un futur chantier, avec son propre
modèle de menaces.

## Avant de déployer une application

1. Créer ou mettre à jour son compose/stack dans le dépôt privé des services.
2. Noter ses volumes, ses secrets hors Git, ses ports et la façon de restaurer
   ses données.
3. Déployer la stack dans Portainer depuis ce dépôt, jamais en copiant un
   secret dans ce dépôt NixOS ou dans une commande d'historique shell.
4. Vérifier les journaux et l'accès uniquement depuis le LAN.
5. Mettre en place puis tester la sauvegarde avant d'y placer des données
   importantes.

Pour l'instant, les sauvegardes automatisées ne sont pas prêtes : aucun service
contenant des données importantes ne doit donc être considéré comme protégé.

## Exception de démarrage : supervision

Le stack Uptime Kuma est conservé dans `stacks/uptime-kuma/` dans ce dépôt afin
de servir d'exemple petit, lisible et sans secret. Il est déployé par Portainer
et non par une commande Docker lancée sur l'hôte. Caddy devient l'unique entrée
HTTPS locale, avec `portainer.home.arpa` et `status.home.arpa`. Son guide est
dans [`SUPERVISION.md`](SUPERVISION.md). Les prochains stacks qui contiendront
des secrets ou des données personnelles devront migrer vers leur propre dépôt
privé.
