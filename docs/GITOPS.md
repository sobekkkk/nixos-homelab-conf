# Applications Docker comme code

## Le modèle retenu

Le homelab utilise deux niveaux déclaratifs complémentaires :

```text
dépôt nixos-homelab-conf        dépôt privé homelab-apps
          |                               |
          | nixos-rebuild                  | Portainer GitOps (polling)
          v                               v
NixOS, Docker, réseau,               stacks Compose, versions,
Portainer et sécurité                volumes et réseaux applicatifs
```

NixOS reste la source de vérité de l'hôte : démarrage, chiffrement, réseau,
pare-feu, Docker et Portainer. Le dépôt privé `homelab-apps` sera la source de
vérité des applications. Portainer ne sert alors plus à écrire la configuration,
mais à lire un stack Git, l'appliquer et en montrer l'état.

Cette répartition évite deux mauvais compromis : lancer des commandes Docker
oubliées sur l'hôte, ou mettre des secrets applicatifs dans le dépôt NixOS
public.

## Déploiement d'une application

Chaque application vit dans son propre dossier :

```text
homelab-apps/
└── apps/
    └── nom-du-service/
        ├── compose.yaml
        ├── README.md
        └── .env.example
```

Le `README.md` indique l'objectif, les ports, les volumes, la sauvegarde, la
restauration et le contrôle de santé. `.env.example` ne contient que les noms
des variables ; les vraies valeurs restent hors Git et hors de l'historique du
shell.

Dans Portainer, un stack est créé depuis Git, avec le chemin du `compose.yaml`
et la branche principale. GitOps est activé en **polling**. C'est le bon choix
ici : le serveur n'est pas exposé à GitHub, donc un webhook public ne serait ni
nécessaire ni souhaitable. Portainer relève le commit distant et applique
uniquement un changement de la source.

Les images restent épinglées par tag et digest. Une mise à jour est donc un
commit relu, suivi du déploiement automatique par Portainer, plutôt qu'un
contenu changé silencieusement sous `latest`.

## État de transition

Le stack Uptime Kuma est pour l'instant une exception documentée dans ce dépôt
public, sans secret. Il a été déployé une première fois depuis l'éditeur
Portainer à partir du compose versionné. Dès que `homelab-apps` existe, il sera
migré vers un stack Git ; la recréation contrôlée conservera ses volumes.

## Conditions avant la migration

1. Créer le dépôt GitHub privé `homelab-apps`.
2. Créer dans ce dépôt le dossier `apps/uptime-kuma/` et y déplacer le compose
   versionné, sans données de volume ni secret.
3. Donner à Portainer un accès Git en lecture seule : clé de déploiement ou
   jeton GitHub limité au seul dépôt, conservé uniquement dans Portainer.
4. Recréer le stack Uptime Kuma depuis Git, sans supprimer les volumes
   existants, puis vérifier Caddy et Kuma.
5. Activer un polling modéré (par exemple toutes les 15 minutes) ; aucun
   webhook public et aucune option de redéploiement forcé par défaut.

La migration du stack est une opération applicative : elle doit être faite dans
une fenêtre où une courte indisponibilité de la supervision est acceptable.
