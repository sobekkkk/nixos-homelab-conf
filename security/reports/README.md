# Rapports d'audit

Ce répertoire conserve les rapports de synthèse approuvés pour le dépôt. Il ne
contient **jamais** les captures brutes, secrets, clés, cookies, identifiants,
adresses de volumes ou données personnelles.

## Rapports disponibles

- [Revue agent du 30 septembre](20260930T140410Z-agent-review.md) : limites
  de la baseline Windows, vulnix non concluant, aucune vulnérabilité serveur
  confirmée dans cette couverture.
- [Baseline 13:51 UTC](20260930T135101Z-unattended-baseline.md),
  [baseline 13:42 UTC](20260930T134246Z-unattended-baseline.md) et
  [baseline 13:11 UTC](20260930T131123Z-unattended-baseline.md) :
  passes figées, artefacts privés référencés, pas de remédiation implicite.

L'état courant et les retests ouverts sont synthétisés dans
[docs/STATUS.md](../../docs/STATUS.md). Un rapport ci-dessous est historique,
pas une certification de la version actuellement déployée.

- [Rapport consolidé du 29 septembre 2026](2026-09-29-white-box-read-only.md) : F-01 à F-08, issus des revues white-box et du scan Codex Security.
- [Remédiation du 29 septembre 2026](2026-09-29-remediation.md) : classifications après revue, correctifs proposés et retests nécessaires.
- [Baseline LAN du 29 septembre 2026](2026-09-29-lan-baseline.md) : contrôle Nmap non destructif des ports autorisés depuis le poste Windows.

## Structure d'un rapport

Chaque rapport doit contenir :

1. le périmètre, l'autorisation, la date et les limites de la revue ;
2. les révisions et artefacts de preuve, sans recopier leur contenu sensible ;
3. les faits observés, distincts de la configuration déclarée ;
4. les écarts et findings, avec statut, sévérité, confiance et conditions ;
5. les contrôles positifs vérifiés ;
6. les recommandations priorisées et des étapes de retest non destructives.

Les preuves brutes restent hors Git, dans l'emplacement contrôlé par
l'opérateur. Un rapport décrit les fichiers consultés et leurs horodatages afin
de rester vérifiable sans élargir l'exposition des informations collectées.
