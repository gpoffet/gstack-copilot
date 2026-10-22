# gstack-copilot

Les skills [GStack](https://github.com/garrytan/gstack) pour **GitHub Copilot**,
installés par projet : VS Code avec le harness Copilot, Copilot CLI et l'app
GitHub Copilot les utilisent tous.

*[English version](README.md)*

```bash
# depuis la racine de votre projet
curl -fsSL https://raw.githubusercontent.com/gpoffet/gstack-copilot/main/get.sh | bash
```

Ouvrez ensuite le chat Copilot et tapez `/gstack-office-hours`.

> gstack-copilot est un portage communautaire indépendant. Il n'est ni affilié
> à GStack, Garry Tan, GitHub ou Microsoft, ni approuvé par eux. GStack est
> l'œuvre de Garry Tan et de ses contributeurs ; ce dépôt ne fait que
> l'empaqueter pour Copilot.

## Ce que vous obtenez

GStack est un ensemble de skills qui guident un agent sur tout un cycle de
développement : cadrage produit, revues de plan, revue de code, livraison,
rétrospective. Son installeur officiel vise une installation par utilisateur et
demande un clone complet de GStack. gstack-copilot en fait une **installation
par projet**, versionnée avec le code : toute l'équipe a les mêmes skills sans
installer GStack.

| Étape | Skills |
|---|---|
| Cadrer | `/gstack-office-hours`, `/gstack-spec` |
| Revoir le plan | `/gstack-plan-ceo-review`, `/gstack-plan-eng-review`, `/gstack-plan-design-review`, `/gstack-plan-devex-review`, `/gstack-autoplan` (toutes les revues à la suite), `/gstack-plan-tune` |
| Construire et vérifier | `/gstack-review`, `/gstack-investigate`, `/gstack-health`, `/gstack-test-audit`, `/gstack-qa-only`, `/gstack-deslop-shared-libs` |
| Livrer et documenter | `/gstack-ship`, `/gstack-document-generate`, `/gstack-document-release`, `/gstack-retro`, `/gstack-learn` |
| Reprendre le travail | `/gstack-context-save`, `/gstack-context-restore` |
| Garde-fous | `/gstack-careful`, `/gstack-freeze`, `/gstack-guard`, `/gstack-unfreeze` |

`/gstack` aiguille vers le bon skill en cas de doute. Les skills portent le
préfixe `gstack-` parce que `/review` est une commande native de Copilot, et
parce que VS Code exige que le nom d'un skill soit celui de son dossier.

## Prérequis

* Linux, macOS ou WSL, avec `bash`, `git`, `curl` et `python3`.
* **[Bun](https://bun.sh) 1.4.2 ou plus récent.** Les outils de GStack sont
  écrits en TypeScript et tournent sur Bun. L'installeur propose de l'installer
  pour l'utilisateur courant, sans droits administrateur.
* VS Code avec GitHub Copilot, avec **Copilot** comme Session Target (ou
  Copilot CLI).

Windows natif n'est pas pris en charge : les skills et le hook de sécurité
reposent sur bash.

## Installer, mettre à jour, désinstaller

Toutes les commandes se lancent depuis la racine du projet.

| Action | Commande |
|---|---|
| Installer ou mettre à jour | `curl -fsSL https://raw.githubusercontent.com/gpoffet/gstack-copilot/main/get.sh \| bash` |
| Version précise | `curl -fsSL .../get.sh \| GSTACK_COPILOT_VERSION=v1.91.176.0-1 bash` |
| Sans question | `curl -fsSL .../get.sh \| bash -s -- --yes` |
| Sans le hook de sécurité | `curl -fsSL .../get.sh \| bash -s -- --no-hooks` |
| Désinstaller | `curl -fsSL .../get.sh \| bash -s -- --uninstall` |

`get.sh` télécharge la dernière [release](https://github.com/gpoffet/gstack-copilot/releases),
vérifie son empreinte SHA-256 publiée, puis lance `install.sh`. Pour lire le
script avant de l'exécuter :

```bash
curl -fsSLO https://raw.githubusercontent.com/gpoffet/gstack-copilot/main/get.sh
less get.sh
bash get.sh
```

On peut aussi cloner ce dépôt et lancer `/chemin/gstack-copilot/install.sh`
depuis le projet.

Le projet reçoit :

| Chemin | Contenu |
|---|---|
| `.github/skills/gstack-*/` | les skills, un dossier chacun |
| `.github/skills/gstack/` | le runtime : routeur `/gstack`, outils, bibliothèques, références, licences |
| `.github/hooks/gstack-safety.json` | le hook `preToolUse` de `/gstack-careful` et `/gstack-freeze` |
| `AGENTS.md` | une section entre marqueurs avec la boucle de travail et le routage ; le reste du fichier n'est pas touché |

Committez-les (`git add .github AGENTS.md`) pour que toute l'équipe ait les
skills. L'état utilisateur de GStack (réglages, apprentissages, journaux) reste
dans `~/.gstack/`, hors du dépôt. Une réinstallation remplace proprement la
version précédente, et la désinstallation rend `AGENTS.md` tel qu'il était.

## Harness Copilot ou Local

VS Code propose deux moteurs pour son agent. **Copilot** (recommandé) partage
son runtime avec Copilot CLI : le générateur de GStack écrit pour ses noms
d'outils (`ask_user`, `task`, `view`), et c'est son format de hooks qui est
installé. **Local**, l'ancien moteur, fait aussi tourner les skills : la section
d'`AGENTS.md` donne la correspondance de ses noms d'outils. Le hook accepte les
deux formats d'événement.

## Garde-fous : /gstack-careful et /gstack-freeze

Copilot ignore les hooks déclarés dans un skill : gstack-copilot installe donc
un hook de dépôt qui appelle les contrôles de sécurité d'origine de GStack.

* Sans mode actif, le hook ne décide rien et ne lance aucun processus Python.
* `/gstack-careful` pose un drapeau valable 12 heures. Les commandes
  destructrices demandent alors une confirmation (`git reset --hard`,
  `git push --force`, `DROP TABLE`...) ou sont refusées (`rm -rf /`, `rm -rf ~`).
* `/gstack-freeze <dossier>` refuse les modifications de fichiers hors de ce
  dossier (outils d'édition, de création et de patch). Les commandes terminal
  ne sont pas contrôlées sur ce point.
* `/gstack-unfreeze` lève la frontière, et met aussi fin au mode careful si on
  le lui demande.
* Le hook ne bloque jamais par erreur : en cas de problème interne il répond
  « pas de décision », car Copilot refuse l'outil quand un hook `preToolUse`
  échoue.

Comme tout plugin d'agent, le hook exécute du code sur votre machine. Lisez
`.github/skills/gstack/copilot/` avant d'installer si cela compte pour vous, ou
installez avec `--no-hooks`.

## Skills GStack non inclus

`skills.txt` liste les skills installés et, en commentaire, ceux qui sont exclus :

* ceux qui demandent le navigateur, le moteur de design ou le générateur PDF
  compilés de GStack (`/browse`, `/qa`, `/design-review`, `/canary`...) ;
* `/cso` : il exige un lanceur natif et Docker, et son modèle de confiance
  refuse un lanceur livré dans le dépôt audité ;
* les revues externes via d'autres CLI (`/codex`, `/claude-code`) et la mémoire GBrain ;
* `/gstack-upgrade` : les mises à jour passent par les releases de gstack-copilot.

Quand GStack annonce une nouvelle version pendant un skill, l'agent le signale
une fois et ne tente jamais de mise à jour sur place. Pour couper ce contrôle :
`.github/skills/gstack/bin/gstack-config set update_check false`.

## Migrer depuis l'ancien portage

L'ancien script `install-gstack.sh` copiait les skills dans `.agents/skills/`
avec des chemins absolus. L'installeur le détecte, propose de supprimer les
anciens dossiers et leur section d'`AGENTS.md`, puis installe la nouvelle
version. Il signale aussi les règles `chat.tools.terminal.autoApprove` de
`.vscode/settings.json` qui mentionnent encore `.agents/skills`, à nettoyer à
la main.

## Limites connues

* Le hook a été testé avec des événements simulés au format documenté. Les noms
  des outils d'édition de Copilot ne sont pas publiés : le hook reconnaît les
  noms contenant `edit`, `write`, `create`, `patch`, `replace` ou `insert`.
  Tapez `/hooks` dans le chat pour vérifier que le hook est chargé.
* Les skills sont volumineux (de 15 à 80 000 tokens environ une fois chargés) :
  un skill par conversation donne les meilleurs résultats.
* Le préambule de GStack charge son profil de modèle `claude` ; avec un autre
  modèle, ces consignes restent génériques et sans effet néfaste.

## Pour les mainteneurs

Voir la section *For maintainers* du [README anglais](README.md#for-maintainers) :
suivi automatique de GStack, build reproductible et publication des releases.

## Licence

MIT, voir [LICENSE](LICENSE). `dist/` contient des fichiers de GStack,
Copyright (c) 2026 Garry Tan, sous licence MIT, dont certains dérivés d'œuvres
sous Apache-2.0 ; leurs licences sont copiées dans chaque installation sous
`.github/skills/gstack/`.
