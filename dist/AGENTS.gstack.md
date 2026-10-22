<!-- gstack-copilot:start (section gérée par install.sh, ne pas éditer entre ces marqueurs) -->
## GStack (gstack-copilot, GStack 1.91.176.0 @ 514fbfdc9)

Les skills GStack sont dans `.github/skills/gstack-*/`, leur runtime dans
`.github/skills/gstack/` et l'état utilisateur dans `~/.gstack/`. Ils
s'invoquent avec le préfixe `gstack-` (`/review` est une commande native de
Copilot). `/gstack` aiguille vers le bon skill en cas de doute.

Boucle de référence : `/gstack-office-hours` ou `/gstack-spec` pour cadrer,
`/gstack-plan-eng-review` pour verrouiller l'architecture (ou `/gstack-autoplan`
pour enchaîner toutes les revues de plan), implémentation après validation,
`/gstack-review` sur le diff, `/gstack-ship` pour livrer, `/gstack-retro` en fin
de cycle.

Routage :
* idée produit : `/gstack-office-hours`
* stratégie et périmètre : `/gstack-plan-ceo-review`
* architecture : `/gstack-plan-eng-review`
* bug : `/gstack-investigate`
* revue de code : `/gstack-review`
* livraison : `/gstack-ship`
* documentation : `/gstack-document-generate`, puis `/gstack-document-release` après livraison
* qualité globale : `/gstack-health`
* reprise de travail : `/gstack-context-save` et `/gstack-context-restore`
* opérations sensibles : `/gstack-careful`, `/gstack-freeze`, `/gstack-guard`

Correspondance des outils : les skills parlent de `AskUserQuestion` (poser une
question à l'utilisateur), de l'outil `Agent` (lancer un subagent) et de `Read`.
Dans le harness Copilot ce sont `ask_user`, `task` et `view`. Dans le harness
Local de VS Code, ce sont `#vscode/askQuestions`, `#agent/runSubagent` et
`#read/readFile`.

Les blocs bash des skills s'exécutent depuis la racine du dépôt et nécessitent
Bun (https://bun.sh).
<!-- gstack-copilot:end -->
