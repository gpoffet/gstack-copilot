# gstack-copilot

Installe [GStack](https://github.com/garrytan/gstack) dans un projet pour
**GitHub Copilot** : VS Code avec le harness Copilot, Copilot CLI et l'app
GitHub Copilot, qui partagent le même runtime.

GStack fournit des skills qui couvrent un cycle complet : cadrage produit,
revue de plan, revue de code, livraison, rétrospective. Son installeur officiel
vise une installation par utilisateur (`~/.copilot/skills`) et nécessite le
clone complet de GStack. gstack-copilot en fait une **installation par projet**,
versionnée avec le code, sans dépendre d'un clone de GStack sur la machine.

## Ce que fait le dépôt

* `build.sh` récupère GStack au commit épinglé dans `GSTACK_REF`, lance son
  générateur officiel pour Copilot (`gen:skill-docs --host copilot`), puis
  `scripts/assemble.py` produit `dist/` :
  * les skills sélectionnés dans `skills.txt`, nommés `gstack-<skill>` ;
  * le runtime de GStack (`bin/`, `lib/`, références) dans `.github/skills/gstack/` ;
  * un hook Copilot qui applique `/gstack-careful` et `/gstack-freeze` ;
  * la section à insérer dans `AGENTS.md`.
* `install.sh` copie `dist/` dans un projet, sans aucune réécriture à
  l'installation. Il sait mettre à jour, désinstaller et migrer l'ancien portage.
* `tests/smoke.sh` installe dans un dépôt jetable et vérifie les binaires, les
  préambules des skills, le hook et la désinstallation. La CI le lance, et
  vérifie aussi que `dist/` correspond exactement à `GSTACK_REF`.

`dist/` est committé : installer dans un projet ne demande ni Bun pour générer,
ni accès à GitHub.

## Prérequis

Sur la machine qui utilise les skills :

* Linux, macOS ou WSL, avec `bash`, `git` et `python3` ;
* **[Bun](https://bun.sh) 1.4.2 ou plus récent** : les outils de GStack sont
  écrits en TypeScript et l'appellent. `install.sh` propose de l'installer
  pour l'utilisateur courant, sans droits administrateur ;
* VS Code avec GitHub Copilot, en choisissant **Copilot** comme Session Target
  (ou Copilot CLI).

Windows natif n'est pas pris en charge : le hook de sécurité et les skills
reposent sur bash.

## Installer dans un projet

```bash
git clone https://github.com/gpoffet/gstack-copilot ~/gstack-copilot
cd ~/projets/mon-projet
~/gstack-copilot/install.sh
git add .github AGENTS.md && git commit -m "chore: install gstack-copilot"
```

Le projet reçoit :

| Chemin | Contenu |
|---|---|
| `.github/skills/gstack-*/` | les skills, un dossier par skill |
| `.github/skills/gstack/` | le runtime : routeur `/gstack`, binaires, bibliothèques, références |
| `.github/hooks/gstack-safety.json` | le hook `preToolUse` de `/gstack-careful` et `/gstack-freeze` |
| `AGENTS.md` | une section délimitée par des marqueurs, avec la boucle de travail et le routage |

L'état utilisateur de GStack (configuration, apprentissages, journaux) reste
dans `~/.gstack/`, hors du dépôt.

Options : `--yes` pour ne poser aucune question, `--no-hooks` pour ne pas
installer le hook, `--force` pour remplacer un dossier `gstack-*` qui ne vient
pas de gstack-copilot, `--uninstall` pour tout retirer.

## Utiliser les skills

Dans le chat, tape `/gstack-` pour voir la liste. Les skills portent le préfixe
`gstack-` parce que `/review` est une commande native de Copilot, et parce que
VS Code exige que le nom d'un skill soit celui de son dossier.

| Étape | Skills |
|---|---|
| Cadrer | `/gstack-office-hours`, `/gstack-spec` |
| Revoir le plan | `/gstack-plan-ceo-review`, `/gstack-plan-eng-review`, `/gstack-plan-design-review`, `/gstack-plan-devex-review`, `/gstack-autoplan` (toutes les revues à la suite), `/gstack-plan-tune` |
| Construire et vérifier | `/gstack-review`, `/gstack-investigate`, `/gstack-health`, `/gstack-test-audit`, `/gstack-qa-only`, `/gstack-deslop-shared-libs` |
| Livrer et documenter | `/gstack-ship`, `/gstack-document-generate`, `/gstack-document-release`, `/gstack-retro`, `/gstack-learn` |
| Reprendre une session | `/gstack-context-save`, `/gstack-context-restore` |
| Garde-fous | `/gstack-careful`, `/gstack-freeze`, `/gstack-guard`, `/gstack-unfreeze` |

`/gstack` aiguille vers le bon skill en cas de doute.

### Harness Copilot ou Local

VS Code propose deux moteurs pour son agent intégré. **Copilot** (recommandé)
partage son runtime avec Copilot CLI : ce sont ses noms d'outils (`ask_user`,
`task`, `view`) que le générateur de GStack utilise, et c'est son format de
hooks que gstack-copilot installe. **Local**, l'ancien moteur, fonctionne aussi
pour les skills : la section d'`AGENTS.md` donne la correspondance de ses noms
d'outils. Le hook est écrit pour accepter les deux formats d'événement, mais il
n'a été vérifié qu'avec des événements simulés : voir « Limites connues ».

## Garde-fous : /gstack-careful et /gstack-freeze

Copilot ignore les hooks déclarés dans un skill. gstack-copilot installe donc
un hook de dépôt, `.github/hooks/gstack-safety.json`, qui appelle les scripts
de contrôle d'origine de GStack.

* Sans `/gstack-careful` ni `/gstack-freeze` actifs, le hook ne décide rien et
  ne lance aucun processus Python.
* `/gstack-careful` pose un drapeau valable 12 heures. Tant qu'il existe, les
  commandes destructrices sont soumises à confirmation (`git reset --hard`,
  `git push --force`, `DROP TABLE`...) ou refusées (`rm -rf /`, `rm -rf ~`).
* `/gstack-freeze <dossier>` refuse les modifications de fichiers hors du
  dossier choisi (outils d'édition, de création et de patch). Les commandes
  terminal ne sont pas contrôlées sur ce point.
* `/gstack-unfreeze` lève la frontière, et retire aussi le drapeau careful si on
  le lui demande.
* Le hook ne bloque jamais par erreur : s'il plante, il répond « pas de
  décision », car Copilot refuse l'outil quand un hook `preToolUse` échoue.

## Mettre à jour

GStack publie plusieurs versions par jour. Pour suivre une nouvelle version :

```bash
cd ~/gstack-copilot
git -C .build/gstack fetch origin main && git -C .build/gstack rev-parse FETCH_HEAD > GSTACK_REF
./build.sh && tests/smoke.sh
git add GSTACK_REF dist && git commit -m "chore: GStack $(cat dist/.github/skills/gstack/VERSION)"
```

Puis dans chaque projet : `~/gstack-copilot/install.sh`. L'installation
précédente est remplacée, `AGENTS.md` est mis à jour entre ses marqueurs.

Quand GStack signale une nouvelle version pendant un skill, l'agent le
mentionne une fois sans tenter de mise à jour sur place. Pour couper ce
contrôle : `.github/skills/gstack/bin/gstack-config set update_check false`.

## Choisir les skills

`skills.txt` liste les skills installés, avec en commentaire ceux qui sont
exclus et pourquoi. Après modification : `./build.sh`, `tests/smoke.sh`, puis
réinstaller dans les projets. Les exclusions principales :

* les skills qui demandent le navigateur, le moteur de design ou le générateur
  PDF compilés de GStack (`/browse`, `/qa`, `/design-review`, `/canary`...) ;
* `/cso` : il exige un lanceur natif et Docker, et son modèle de confiance
  refuse justement un lanceur qui viendrait du dépôt audité ;
* les revues externes via d'autres CLI (`/codex`, `/claude-code`) et la mémoire
  GBrain ;
* `/gstack-upgrade`, remplacé par le circuit de mise à jour ci-dessus.

## Migrer depuis l'ancien portage

L'ancien script `install-gstack.sh` copiait les skills dans `.agents/skills/`
avec des chemins absolus. `install.sh` le détecte, propose de supprimer les
anciens dossiers et l'ancienne section d'`AGENTS.md`, puis installe la nouvelle
version. Il signale aussi les règles `chat.tools.terminal.autoApprove` de
`.vscode/settings.json` qui pointent encore vers `.agents/skills`, à nettoyer à
la main.

## Limites connues

* Le hook n'a été vérifié qu'avec des événements simulés au format documenté.
  Les noms des outils d'édition du harness Copilot ne sont pas listés
  publiquement : le hook reconnaît les noms contenant `edit`, `write`, `create`,
  `patch`, `replace` ou `insert`. À confirmer dans une vraie session (`/hooks`
  dans le chat montre les hooks chargés).
* Les skills sont volumineux (de 15 à 80 000 tokens environ une fois chargés) : un
  seul skill à la fois par conversation donne les meilleurs résultats.
* Le préambule de GStack charge le profil de modèle `claude` ; avec un autre
  modèle dans Copilot, ces consignes restent génériques et sans effet néfaste.

## Structure du dépôt

```
GSTACK_REF            commit GStack épinglé
skills.txt            skills installés
build.sh              régénère dist/
install.sh            installe dans un projet
scripts/assemble.py   transforme la sortie du générateur GStack en dist/
templates/            hook, compléments de skills, section AGENTS.md
tests/                contrôles statiques et test d'installation
dist/                 résultat du build, committé
```

## Licence

GStack est distribué sous licence MIT (Copyright (c) 2026 Garry Tan), avec des
fichiers dérivés d'œuvres sous Apache-2.0 : `LICENSE`, `NOTICE.md` et
`licenses/` sont copiés dans chaque installation sous `.github/skills/gstack/`.
