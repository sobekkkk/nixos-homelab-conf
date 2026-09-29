# ZAP Baseline

Utiliser uniquement le baseline scan ZAP pendant la première passe : découverte
et règles passives, sans scan actif, authentification, fuzzing ni test de charge.

La cible doit provenir de `../scope.yml`. Conserver le rapport HTML/JSON hors du
dépôt, avec la version de l'image ou de ZAP. Toute alerte est un `candidate`
jusqu'à corrélation avec la configuration effective et validation manuelle.

L'Automation Framework ZAP avec un `activeScan` est volontairement absent de ce
profil ; son ajout exige l'approbation prévue dans `../ROE.md`.
