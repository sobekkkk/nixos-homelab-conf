# Politique de sécurité

Ce document décrit ce qu'une revue de sécurité doit protéger et ce qui constitue
un résultat utile pour ce homelab. Il guide l'audit ; il ne prouve pas à lui seul
que les contrôles fonctionnent.

## Système et périmètre

Le dépôt configure une unique machine NixOS personnelle nommée `homelab`. Elle
sert aujourd'hui de base d'administration et d'expérimentation ; aucun service
applicatif n'est encore exposé.

Le périmètre principal comprend :

- la configuration NixOS versionnée dans ce dépôt ;
- la chaîne de démarrage Secure Boot, Lanzaboote, TPM2 et LUKS2 ;
- l'administration locale et SSH du compte `sobek` ;
- le pare-feu, le durcissement noyau, AppArmor, les journaux et l'audit ;
- les tâches de maintenance Nix et l'usage interactif de Codex CLI.

La machine est administrée par une seule personne. SSH est le seul service
réseau attendu et doit rester joignable uniquement depuis le LAN IPv4
`192.168.1.0/24`. Tout nouveau service, port ou compte élargit le périmètre et
doit être documenté avant son activation.

## Modèle de menaces et frontières de confiance

Les actifs principaux sont les données du volume chiffré, les droits `root`, la
clé SSH d'administration, les secrets futurs des services, les clés Secure Boot
et l'intégrité de la configuration Git/NixOS.

Les entrées considérées comme potentiellement hostiles comprennent le trafic du
LAN, les dépôts et dépendances mis à jour, les fichiers ou instructions traités
par un outil d'administration, et toute donnée d'un futur service. Le LAN
réduit l'exposition mais n'est pas une frontière de confiance suffisante à lui
seul.

Les principales frontières sont :

1. réseau local vers `sshd`, protégé par nftables et l'authentification par clé ;
2. compte `sobek` vers `root`, protégé par PAM et un mot de passe `sudo` ;
3. configuration Git vers système actif, via évaluation, build et
   `nixos-rebuild` privilégié ;
4. firmware et démarrage vers volume LUKS2, via Secure Boot, démarrage mesuré,
   TPM2 et PIN ;
5. outils interactifs, dont Codex, vers fichiers et commandes autorisés par le
   compte qui les lance.

Le modèle détaillé et ses scénarios sont dans
[`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md).

## Invariants de sécurité

Une modification ne doit pas rompre les propriétés suivantes :

- aucune clé privée, passphrase, recovery key, sauvegarde LUKS, token ou donnée
  de service ne doit entrer dans Git, les logs ou une conversation ;
- aucune connexion SSH par mot de passe, aucun login `root` distant et aucun
  transfert SSH ne doivent être possibles ;
- seul `sobek` doit pouvoir ouvrir une session SSH et l'élévation doit continuer
  à demander son mot de passe ;
- aucun port entrant ne doit être ouvert globalement par défaut ;
- une nouvelle exposition réseau doit avoir une source, un port et un besoin
  explicitement documentés ;
- le démarrage normal doit conserver Secure Boot et le déverrouillage LUKS2 par
  TPM2 + PIN, sans retirer les moyens de récupération hors machine ;
- une configuration non évaluée ou non construite ne doit pas être activée ;
- Codex et les autres outils d'assistance ne doivent pas être lancés avec
  `sudo`, ni recevoir implicitement le droit de publier ou d'appliquer une
  action privilégiée ;
- les changements sensibles doivent rester attribuables grâce aux journaux et
  aux règles d'audit, dans les limites de rétention documentées.

## Résultats à signaler et sévérité

Un résultat est pertinent s'il montre un chemin réaliste permettant notamment :

- un accès réseau non prévu ou un contournement de l'authentification SSH ;
- une élévation de privilèges depuis une capacité réellement accessible ;
- l'extraction d'un secret, le déchiffrement hors politique ou la modification
  persistante du démarrage ;
- l'exécution d'une configuration ou d'une commande privilégiée sans validation
  attendue ;
- la désactivation silencieuse du pare-feu, de l'audit ou d'un invariant ci-dessus ;
- une perte durable de disponibilité ou d'intégrité avec un chemin d'attaque
  plausible.

La sévérité dépend du point de départ réel, de l'exposition, des privilèges
gagnés et des contrôles effectivement applicables. Une simple recommandation de
durcissement, une attaque nécessitant déjà `root`, ou l'absence d'un service non
prévu ne constitue pas automatiquement une vulnérabilité.

## Hors du périmètre actuel

Les éléments suivants ne sont pas contrôlés par ce dépôt et doivent être
signalés comme dépendances ou limites, pas supposés sûrs :

- routeur, Wi-Fi, autres appareils du LAN et poste client d'administration ;
- sécurité du compte GitHub, d'OpenAI et des fournisseurs de dépendances ;
- firmware, attaques matérielles invasives et disponibilité physique du serveur ;
- futurs conteneurs, applications et sauvegardes tant qu'ils ne sont pas ajoutés.

Ils redeviennent pertinents lorsqu'une configuration suivie ici leur accorde une
capacité, un secret ou une exposition susceptible de casser un invariant.

## Limites connues et contrôles compensatoires

- `sobek` est un administrateur `wheel` : sa compromission locale peut mener à
  `root`, mais `sudo` exige un mot de passe et utilise un pseudo-terminal.
- Les mises à jour sont volontaires. Cela permet leur revue et leur test, au prix
  d'un délai possible pour appliquer un correctif de sécurité.
- Les espaces de noms utilisateur sont activés pour le sandbox Nix et de futurs
  conteneurs rootless ; leur surface noyau doit rester prise en compte.
- L'audit privilégie la disponibilité (`failureMode = "printk"`) et peut donc se
  dégrader sans arrêter la machine ; journald et auditd bornent leur usage disque.
- Les sauvegardes automatisées ne sont pas encore définies. La sauvegarde du
  header LUKS est conservée hors machine, mais elle ne remplace pas une sauvegarde
  des données.
- Une future session Codex peut stocker des jetons sous `~/.codex/auth.json` ; ce
  fichier doit rester hors Git, avec des permissions restrictives.

## Signaler un problème

Ne pas publier de secret, de clé ou de preuve destructive dans une issue
publique. Pour le moment, ce projet personnel n'a pas de canal privé dédié :
ouvrir d'abord une discussion sans détail sensible avec le propriétaire du
dépôt, puis convenir d'un canal adapté.
