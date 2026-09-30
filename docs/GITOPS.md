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

## Premier stack GitOps

Uptime Kuma a été migré le 30 septembre 2026 vers le dépôt privé
`homelab-apps`, chemin `apps/uptime-kuma/compose.yaml`. Portainer le suit sous
le nom `uptime-kuma-gitops`, avec un polling de 15 minutes. La recréation a
conservé les trois volumes nommés, puis Caddy et Kuma ont été vérifiés
respectivement *running* et *healthy*.

Le jeton GitHub associé est limité à la lecture du seul dépôt applicatif et est
conservé par Portainer, jamais dans Git ou dans NixOS. Aucun webhook n'est
exposé : le serveur reste inaccessible depuis Internet.

Pour chaque nouveau service, copier cette structure, relire le commit et créer
un stack Git Portainer avec le polling. Une modification locale dans Portainer
serait écrasée par la source Git : elle ne doit donc jamais être utilisée comme
source de vérité.
