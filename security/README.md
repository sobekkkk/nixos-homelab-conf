# Outillage d'audit

Ce répertoire rend l'audit reproductible sans stocker de preuves brutes ni de
secrets dans le dépôt. Les règles d'engagement sont dans [ROE.md](ROE.md) et le
périmètre machine dans [scope.yml](scope.yml).

## Rôles

| Emplacement | Rôle | Outils |
| --- | --- | --- |
| Windows | vue externe du LAN | Nmap, ssh-audit, testssl.sh, Nuclei, ZAP Baseline |
| NixOS (`sobek`) | revue white-box et lecture du snapshot | Gitleaks, Trivy, vulnix, Nix, collecteur root en lecture seule |
| Codex | corrélation, validation et rapport | lecture des sources et des artefacts |

Le profil Nuclei est volontairement lent et exclut `dos`/`fuzz`. Il désactive
Interactsh/OAST. Le baseline ZAP est passif ; le scan actif reste soumis au
checkpoint humain défini dans `ROE.md`.

## Préparation avant le baseline

1. Vérifier le commit et l'état Git ; ne pas corriger pendant la première passe.
2. Créer un dossier de preuves hors du dépôt, accessible uniquement à l'opérateur.
3. Après activation de `homelab-security-snapshot`, lire le dernier dossier dans
   `/var/lib/homelab-security-snapshot/latest` avec `sobek`.
4. Lancer le script Windows contre l'adresse explicitement autorisée et les cinq ports de scope.yml :
   `./security/scripts/windows-baseline.ps1`.
5. Utiliser `profiles/nuclei.yaml` pour Nuclei et suivre
   [profiles/zap-baseline.md](profiles/zap-baseline.md) pour ZAP.

Les packages NixOS déclarés permettent les vérifications white-box, mais leur
présence ne donne aucun privilège supplémentaire à `sobek`.
