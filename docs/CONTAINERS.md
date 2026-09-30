# Contrat de déploiement des applications

## 1. Répartition

NixOS déclare moteur, garde réseau, réseau homelab-proxy et Portainer.
Le dépôt privé homelab-apps déclare les autres stacks. Portainer lit Git,
déploie et montre l'état ; son éditeur n'est pas la source de vérité.

Un service par dossier, image officielle épinglée par tag et digest, volume
nommé stable. Pas de commande docker run oubliée, de stack concurrente ou de
tag latest. Un digest garantit l'identité du contenu, pas sa sécurité.

## 2. Fiche obligatoire d'un nouveau service

| Rubrique | Questions |
| --- | --- |
| Objectif / propriétaire | Quel besoin, qui maintient, quand le retirer ? |
| Dépendances | DNS, proxy, service externe, base de données ? |
| Exposition | Clients autorisés, ports, TLS, authentification ? |
| Données | Volumes, format, migrations, caractère remplaçable ? |
| Secrets | Source, point d'injection, permissions, rotation ? |
| Privilèges | Utilisateur, capacités, montages hôte, namespaces ? |
| Ressources | CPU/RAM mesurés, budget disque, logs bornés ? |
| Déploiement | Compose, branche, polling, checks, rollback ? |
| Exploitation | Santé, sonde, alertes, diagnostic, retrait ? |
| Récupération | Ce qui doit être reprovisionné ; limites de restauration ? |

Ne pas inventer des limites CPU/RAM sans essai : proposer un budget et vérifier
le comportement sous charge représentative autorisée. Les stacks actuelles
n'ont pas toutes des limites mémoire/CPU explicites.

## 3. Baseline attendue

- Pas de port hôte par défaut : proxy existant si nécessaire et accès privé.
- Pas de privileged, réseau host, PID host ou montage racine pour un service
  ordinaire. Chaque exception exige justification et test.
- Pas de socket Docker pour les applications ; Portainer est l'exception
  d'administration explicite. Ne pas fournir un proxy Docker global GET-only.
- no-new-privileges et réduction de capacités quand compatibles ; utilisateur
  non root et rootfs readonly à tester, pas à cocher sans validation.
- Logs bornés, restart documenté, contrôle de santé fonctionnel.
- Aucun secret dans configs.content, .env committé ou variables affichées.
- Vérifier DNS et sorties nécessaires. Réseau internal + second NAT n'est pas
  une isolation Internet ; bridge partagé n'est pas une ACL par application.
- Ne pas retirer la garde Docker pour dépanner.

Netdata est une exception d'observation hôte, non un modèle à copier.
Ses accès sensibles sont dans [ARCHITECTURE.md](ARCHITECTURE.md).

## 4. Ajout d'une application

1. Créer apps/<service>/compose.yaml et README dans le dépôt privé.
2. Documenter la fiche ci-dessus et les éventuels écarts.
3. Vérifier modèle Compose, images, secrets absents et liens de documentation.
4. Faire autoriser publication/activation si le polling main applique le patch.
5. Créer le stack Git avec le bon chemin, accès de lecture minimal et polling.
6. Contrôler nom réel, images, volumes, ports, point HTTP et permissions.
7. Ajouter les sondes/alertes utiles ; consigner l'état réellement observé.

Les sauvegardes sont différées au propriétaire. Ne pas qualifier des données
importantes de protégées tant que leur récupération n'est pas attestée.

## 5. Retrait

Décrire les clients et dépendances avant arrêt. Retirer les routes/sondes devenues
inutiles dans un changement autorisé ; conserver les données selon la décision
du propriétaire. Suppression de volumes ou révocation de secrets : action séparée,
cible explicite, perte comprise. Un retrait de stack n'est pas une autorisation
de purger tous les volumes.

Guides : [GitOps](GITOPS.md), [données](DATA.md), [runbooks](RUNBOOKS.md).
