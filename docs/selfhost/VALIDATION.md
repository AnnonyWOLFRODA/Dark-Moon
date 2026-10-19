# Bilan vérifiable de la session Cloud

Base inspectée : `3385fd4874b2b793c18f148de637a250fe1ae829`, branche de session
`work`, arbre propre avant intervention. Aucun AGENTS.md présent sous /workspace.
Licence GPL-3.0 conservée, attribution upstream conservée.

## Modifications livrées

- existing : credentials jamais touchés, modèle explicite sans clé API.
- Génération JSON par sérialisation, fusion contrôlée, écritures atomiques mode 600,
  conservation des politiques globales/par agent et des providers personnalisés.
- Conservation des 51 agents, plugins et câblage MCP ; prise en charge des champs
  mode/prompt de la révision OpenCode inspectée et des champs historiques.
- Plus de suppression d'auth au changement de provider, plus de TUI parasite.
- Installation/actualisation/reconfiguration sans purge et sans exécuter dotenv.
  Reset confirmé limité aux conteneurs/réseau ; données et caches conservés.
- Profil lab sans socket, port publié, kubeconfig ou capacités supplémentaires.
  Toolbox désactivée au niveau client, MCP toujours disponible ; vrai contrôle
  de readiness MCP sur HTTP à l'installation locale.
- Overlays explicites cloud, toolbox avancée sur VM dédiée, Ollama CPU et NVIDIA.
- Build OpenCode épinglé, inspection de son OAuth natif ; aucun login effectué.
- Tests offline, CI sans publication, documentation et checklist locale.

## Tests exécutés

Exécuter depuis `/workspace/Dark-Moon` avec
`PATH="/workspace/.venvs/darkmoon/bin:$PATH"` :

| Commande | Résultat | Portée et limites |
|---|---|---|
| `python -m pip install -r mcp/requirements.txt -r tools/selfhost/requirements.txt` | succès, répété | environnement virtuel externe au checkout ; fastmcp 4.1.1, Python 3.12 |
| `python -m pytest -q mcp/tests` (avant changements du client Docker) | 107 réussis | baseline MCP ; aucun Engine |
| `python -m pytest -q -p no:cacheprovider tests/selfhost mcp/tests` | 151 réussis | 44 nouveaux cas et 107 existants ; aucun skip/xfail |
| `bash tools/selfhost/check.sh` | succès | regroupe les vérifications ci-dessous, aucun conteneur |
| `bash -n` des scripts modifiés et du check | succès | syntaxe Bash ; pas une validation runtime Docker |
| `shellcheck install.sh install-dev.sh conf/apply-settings.sh conf/entrypoint-opencode.sh tools/selfhost/check.sh` | succès | ShellCheck 0.11.0 |
| `bash tools/check-no-regression.sh` | PASS | wiring des agents, JSON généré contenant les 51 agents |
| validation JSON par `json.loads` | succès | conf/opencode.json et scope.example.json |
| `docker compose ... config --quiet` | succès | base, cloud, advanced, Ollama+GPU ; fichiers provider temporaires factices, Compose 2.40.3 |
| `python tools/selfhost/check-secrets.py` | succès | signatures de tokens connues seulement ; ne prouve pas l'absence de tout secret |
| `git diff --check` | succès | pas d'erreurs d'espacement |
| `git ls-remote origin HEAD` | succès | accès Git fourni par la plateforme, sans token utilisateur |

Les cas de tests couvrent sélection des providers et modèles, fallback,
configurations partielles/invalides, échappement de caractères spéciaux, auth
existing opaque, fusion/politiques utilisateur, idempotence, fichiers sensibles,
conservation de sessions/rapports/agents/workflows, MCP stdio et HTTP réels avec
Docker désactivé, fichier dotenv contenant une substitution de commande factice,
installation/réinstallation/reconfiguration/update/diagnose/stop/reset simulés,
échecs d'opérations externes, absence de Docker et image mutable refusée.

Les premiers tests de persistance ont révélé une erreur de fixture (dossier state
non créé, alors que le nouveau script ne crée volontairement pas d'auth en fallback).
La fixture a été corrigée, puis la suite complète réexécutée. ShellCheck a aussi
signalé une déclaration export masquant un statut ; corrigée et revérifiée.
Aucun échec non expliqué n'est masqué par un skip ou une désactivation d'assertion.

Les tests MCP démarrent uniquement des sous-processus temporaires et effectuent
list_tools, health_check et get_session ; le test HTTP vérifie le vrai helper de
readiness. Ils ne lancent ni commande toolbox, campagne, cible ni modèle. Le retour
unhealthy de la toolbox désactivée est **attendu**, pas un succès toolbox.
Les sous-processus de test sont arrêtés après chaque vérification.

## Non exécuté en Cloud

- Build complet OpenCode ou toolbox, installation upstream sur l'hôte.
- Démarrage/redémarrage de conteneurs, contrôle réel des volumes/capacités/réseaux.
- Chargement de modèles, Ollama/llama.cpp réels, GPU ou NVIDIA Container Toolkit.
- Connexion ChatGPT/Codex, Claude ou API réelle ; validation des quotas/droits.
- Confirmation interactive des permissions du binaire OpenCode construit.
- Migration des anciens bind mounts et restauration d'une sauvegarde personnelle.
- Campagne pentest, scan, exploitation ou test de services Résurgence.
- Exécution du workflow GitHub Actions distant, push, publication d'images,
  déploiement ou fusion de PR.

Le mécanisme de création de PR n'est pas disponible dans les connecteurs de cette
session. Les changements sont livrés dans la branche locale `work`, accompagnés
d'un patch exportable ; aucune PR distante n'est prétendue créée.

## Configuration Cloud sauvegardée

`install_script` : recrée/rafraîchit le venv `/workspace/.venvs/darkmoon`, installe
les dépendances de test et lance les checks offline dans le bon répertoire.
`start_skill` : utilise le checkout existant, active le venv, relance ces checks,
interdit de démarrer agents/conteneurs/pentests sur cette machine partagée et
renvoie les validations matérielles/auth à la checklist PC. Aucun worktree à créer.

Les deux champs ont été enregistrés dans le brouillon de configuration. Aucun
secret, variable runtime ou domaine supplémentaire n'a été ajouté. Le brouillon
n'exécute pas les scripts et n'est pas une publication. Pour le réutiliser dans
de nouvelles tâches, examiner/enregistrer la configuration dans les paramètres
d'environnement, puis publier l'environnement. La restauration dans une nouvelle
tâche n'a pas été validée.

## Risques résiduels et périmètre restant

La base est prête pour développer/tester **offline** cette adaptation. Le
laboratoire complet n'est pas déclaré validé. Les images restent root, les
confirmations OpenCode ne remplacent pas une isolation de VM, le profil avancé
donne le contrôle du daemon choisi, et l'overlay cloud ouvre la sortie sans
filtrage par destination. Le périmètre Résurgence n'est pas techniquement imposé
par le MCP. Les profils upstream, conservés, restent plus permissifs et ne doivent
pas être confondus avec le lab.

La migration de données, la reconstruction, les comptes et le confinement réel
restent à vérifier sur le PC. Les procédures et les commandes exactes figurent
dans [À faire lorsque je serai sur mon PC fixe](LOCAL.md).
