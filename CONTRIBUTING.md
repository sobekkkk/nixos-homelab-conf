# Contribuer sans se prendre la tête

Ce homelab sert d'abord à apprendre. Une bonne contribution est donc une
contribution qui rend le système plus clair, plus sûr ou plus facile à réparer.

## Avant un commit

1. Relire le diff et vérifier qu'il ne contient aucun secret.
2. Mettre à jour le README ou un fichier dans `docs/` si le comportement,
   l'architecture ou une commande change.
3. Vérifier la configuration :

   ```bash
   cd /etc/nixos
   git diff --check
   nix eval --raw .#nixosConfigurations.homelab.config.system.build.toplevel.drvPath
   ```

4. Utiliser un message de commit court qui explique l'intention, par exemple
   `Enable persistent audit logging`.

## Quelques habitudes utiles

- Préférer les petits changements indépendants aux gros changements difficiles à
  diagnostiquer.
- Tester avec `nixos-rebuild test` avant `switch` lorsqu'un service ou le réseau
  est concerné.
- Ne pas ouvrir de port ou ajouter de service public sans l'avoir documenté.
- Garder les détails personnels et les secrets hors de Git.
- Pour un stack conteneur, documenter ses ports, ses volumes, ses mises à jour
  et sa sauvegarde avant son premier déploiement dans Portainer.

## Documentation et validation

Le dossier commence dans [docs/README.md](docs/README.md). Un changement réseau
met à jour la matrice et les schémas ; un montage ou privilège met à jour les
données et les limites ; une alerte met à jour sa couverture et son runbook.
Ne pas transformer une intention en résultat observé ni effacer un rapport figé.

Depuis le clone Windows, vérifier les liens et blocs du dossier :

```powershell
./docs/Test-Documentation.ps1
```

Cette vérification n'évalue pas Nix, ne rend pas Mermaid et ne teste pas le
serveur. Les schémas doivent aussi être relus dans le rendu GitHub de la PR.
Une correction documentaire ne nécessite pas de rebuild NixOS.

Le projet peut évoluer tranquillement : documenter ce qui a été appris compte
autant que faire fonctionner la machine.
