# Dossier d'architecture

Propriétaire : sobek. Revue documentaire : 30 septembre 2026.
Périmètre : un hôte NixOS, sa plateforme Docker et ses accès privés.
La rédaction de ce dossier ne modifie aucun service.

## Convention de preuve

| Terme | Signification |
| --- | --- |
| Déclaré | Source versionnée, pas nécessairement active |
| Observé | Vérification datée, périmètre et méthode identifiables |
| Cible | Comportement souhaité, pas encore établi |
| Non attesté | Preuve insuffisante disponible |
| Différé | Hors du chantier actuel, propriétaire identifié |

[STATUS.md](STATUS.md) centralise cette distinction. Les rapports historiques
restent immuables : une doc actuelle ne réécrit pas un audit.
Le code déclaré prévaut sur une description devenue obsolète.

## Parcours de lecture

1. [Architecture](ARCHITECTURE.md), [réseau](NETWORK.md), [état](STATUS.md).
2. [GitOps](GITOPS.md), [exploitation](OPERATIONS.md), [runbooks](RUNBOOKS.md).
3. [Supervision](SUPERVISION.md), [contrat conteneurs](CONTAINERS.md).
4. [Amorçage](BOOTSTRAP.md), [données et secrets](DATA.md).
5. [Politique de sécurité](../SECURITY.md), [menaces](THREAT_MODEL.md),
   [rapports](../security/reports/README.md), [décisions](../DECISIONS.md).
6. [Passerelle privée](PRIVACY_GATEWAY.md), [clients Windows/Android/TV](PRIVACY_GATEWAY_CLIENTS.md),
   [validation et mesures](PRIVACY_GATEWAY_VALIDATION.md).

## Maintenir le dossier

Le [portail Homepage](HOMEPAGE.md) est préparé sur branches de revue ; son
activation et ses accès doivent encore être validés par la recette dédiée.

URL, port, image, montage, privilège ou dépendance changé : actualiser le guide
et son contrôle. Nouvelle exception : décision motivée, risque, contrôle
compensatoire et critère de sortie. Une correction dans Git reste « à retester »
tant qu'elle n'a pas été activée et observée.

Les schémas Mermaid sont versionnés avec le texte et rendus par GitHub.
Ils ne présentent pas de cluster ou de service inexistant.
