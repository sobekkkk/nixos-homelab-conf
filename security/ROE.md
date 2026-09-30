# Règles d'engagement

## Autorisation

L'évaluation concerne uniquement le serveur `homelab` (`192.168.1.69`) et les
interfaces/ports explicitement énumérés dans `scope.yml`. L'autorisation ne
s'étend ni au routeur, ni aux autres machines du LAN, ni à Internet.

## Baseline autorisé sans étape supplémentaire

- lecture du dépôt, de l'historique Git et du snapshot système ;
- inventaire de ports et de versions contre l'hôte unique autorisé ;
- vérification SSH/TLS, scan web passif et contrôles Nuclei non destructifs ;
- analyse des images, dépendances et CVE, sans extraire de secrets.

## Approbation humaine obligatoire immédiatement avant

- scan web actif, exploitation ou PoC allant au-delà d'une reproduction minimale ;
- brute force, password spraying, tests d'authentification répétés ou OAST ;
- déni de service, fuzzing, persistance, exfiltration ou suppression de données ;
- changement de configuration, de pare-feu, de Docker, des comptes, rebuild ou
  redémarrage ;
- toute cible, adresse IPv6, URL ou port non déclaré dans `scope.yml`.

## Preuves

Ne pas enregistrer de clés, tokens, cookies, mots de passe, contenu de volumes
ou données personnelles. Les sorties servant de preuve sont horodatées et
stockées hors Git ; les rapports ne contiennent que des extraits expurgés et des
références d'artefacts.

## Publication unattended autorisée

Après un baseline autorisé, le runner versionné peut créer et pousser une
branche neuve nommée codex/pentest-*. Cette exception est limitée à un unique
rapport expurgé sous security/reports/ après validation; elle n'autorise ni push
sur main, ni pull request automatique, ni modification de configuration, ni
publication de preuve brute. L'absence d'authentification Codex doit être
signalée comme action différée, jamais contournée par une clé copiée dans le
dépôt ou l'environnement.
