# Dark-Moon auto-hébergé : base de laboratoire

Cette adaptation conserve la licence GPL-3.0 et l'attribution ASC-IT du dépôt.
Elle modifie uniquement ce fork. Aucun autre dépôt, compte, modèle ou service
Résurgence n'est modifié. Le Compose upstream reste disponible, avec ses risques.
Le nouvel installateur utilise exclusivement `docker-compose.lab.yml`.

## Architecture et limites effectives

OpenCode charge les agents, les deux plugins Darkmoon et le MCP embarqué.
Le MCP utilise normalement Docker pour exécuter la toolbox : `docker.from_env`,
recherche du conteneur, `exec_create` et `exec_start`. Les scans, workflows et
vérifications d'outils dépendent de ce chemin. Un socket monté en lecture seule
ne rendrait pas l'API Docker inoffensive.

Le laboratoire par défaut n'a **aucun socket Docker**, aucun montage Kubernetes,
aucun port publié, aucune capacité Linux ajoutée. Toutes les capacités sont
retirées, `no-new-privileges` est activé, les ressources OpenCode sont limitées.
Le réseau dédié est `internal`. Les configurations, credentials, sessions,
rapports, agents et workflows utilisent des volumes nommés dédiés au projet.
Le CPU est le fonctionnement par défaut.

`DARKMOON_TOOLBOX_ENABLED=false` empêche réellement la connexion au daemon :
la toolbox retourne un échec explicite. Le MCP continue à offrir ses fonctions
sans exécution Docker. Ce n'est pas une toolbox simulée et ce profil ne permet
pas une campagne complète. Les images conservent root et un système de fichiers
inscriptible, nécessaires aux chemins upstream et à l'entrypoint actuel.
Les plugins et les outils locaux OpenCode s'exécutent toujours dans le conteneur.

Le réseau interne bloque la sortie ordinaire ; ce n'est pas une politique de
cibles, ni une garantie d'inaccessibilité de l'hôte. Utiliser une VM dédiée et
un pare-feu externe pour les campagnes. Le modèle de périmètre
[`scope.example.json`](scope.example.json) est **descriptif**, sans enforcement
par le MCP : hôtes autorisés/exclus, débit, comptes, types de tests et absence
d'actions destructives doivent encore être imposés au réseau et à l'orchestrateur.
Aucune cible Résurgence n'est préconfigurée. Ne pas lancer de campagne en se
reposant seulement sur ce fichier ou sur les instructions d'un agent.

### Activation avancée explicite

`docker-compose.lab.advanced.yml` active la vraie toolbox et monte uniquement
le socket indiqué par `DARKMOON_LAB_DOCKER_SOCKET`. Il ne monte pas le socket
dans la toolbox elle-même, ne partage pas le réseau hôte et ne monte pas ~/.kube.
Les outils requérant NET_RAW/NET_ADMIN ou des credentials cloud ne fonctionneront
pas tous : ces privilèges ne sont pas ajoutés automatiquement.

**Accéder à ce daemon donne le contrôle de tous ses conteneurs et potentiellement
de l'hôte. Un réseau Docker ne confine pas un agent possédant ce socket.**
Réserver ce profil à une VM jetable, sans données ni daemon d'autres projets,
avec restrictions réseau externes. Ne jamais l'utiliser sur un Engine partagé.
Le socket permettrait de créer un autre conteneur privilégié : `cap_drop` ne
protège pas l'hôte de cet accès. Ce profil n'est pas un bac à sable sûr à lui seul.

## Installation et cycle de vie

Prérequis : Linux ou distribution Linux dans WSL2, Bash, Python 3.12, Docker
Engine et Compose **2.30+** (`env_file.format: raw`). Sous Windows, travailler
dans le système de fichiers Linux WSL2 ; activer l'intégration Docker de la
distribution. Ne pas exposer un daemon TCP sans TLS. Une VM Linux dédiée reste
préférable pour la toolbox avancée.

`install.sh` est désormais non interactif : préparer `.opencode.env`, puis :

```bash
./install.sh install        # vérifie, valide, crée/démarre sans purge
./install.sh reconfigure    # après édition du provider ; conserve les volumes
./install.sh update         # pull de l'identité d'image choisie, puis up
./install.sh diagnose       # validation + état Compose, aucune campagne
./install.sh stop           # arrêt, conservation des conteneurs et données
./install.sh reset          # confirmation exacte ; enlève conteneurs/réseau seulement
```

`--init` reste un alias de reconfigure, `--reset` de reset.
`install-dev.sh` délègue au même cycle conservateur ; les builds sont explicites.
`setup.sh`, `setup_py.sh`, `setup_ruby.sh` installent la toolbox pendant le build,
ce ne sont pas des scripts d'onboarding à exécuter sur l'hôte.

Le formulaire interactif upstream est remplacé par un fichier explicite : aucun
`eval`/`source` de dotenv, pas de reset automatique, pas de probe GPU, pas de
`--volumes`, `--rmi all`, suppression de bind mounts ou prune global.
Les fichiers provider sont chmod 600. La réinitialisation des **données** n'est
pas automatisée : `reset` ne supprime jamais credentials, rapports ou sessions.

Le fichier provider est littéral (Compose raw) : **ne pas mettre de guillemets
shell autour des valeurs**. `$`, apostrophes et antislashs restent des données.
Les valeurs multilignes ne sont pas prises en charge. Le validateur n'accepte
que les familles OPENCODE_, OPENROUTER_, ANTHROPIC_ et refuse les chemins de
configuration. Ne pas stocker une copie de `.opencode.env` dans Git.

## Providers et persistance

### Authentification existante

```dotenv
OPENCODE_AUTH_MODE=existing
OPENCODE_MODEL=openai/identifiant-accessible-dans-votre-build
```

Choisir un identifiant réellement listé par `opencode models` après connexion.
Aucune clé API n'est requise. `auth.json` n'est ni lu, supprimé, réécrit ou chmodé
par apply-settings en mode existing. L'outil de connexion OpenCode reste libre
d'y enregistrer/renouveler les identifiants. Le volume `state` est persistant.

### API cloud

```dotenv
OPENCODE_AUTH_MODE=managed
OPENROUTER_PROVIDER=openai
OPENCODE_MODEL=identifiant-du-modele
OPENROUTER_API_KEY=valeur-saisie-localement
```

Malgré son nom historique, OPENROUTER_API_KEY est utilisé pour le provider indiqué
(openai, anthropic, openrouter, etc.). Le mode managed remplace **explicitement**
l'entrée auth de ce seul provider ; les autres entrées sont conservées.
Utiliser existing pour conserver une connexion interactive du provider sélectionné.
L'identifiant de modèle cloud n'inclut pas ce premier préfixe provider ; un modèle
OpenRouter peut lui-même contenir `/`.

### Endpoint Anthropic-compatible

```dotenv
ANTHROPIC_BASE_URL=https://votre-endpoint.example/v1
ANTHROPIC_MODEL=identifiant-du-modele
ANTHROPIC_API_KEY=valeur-locale-si-requise
```

Le modèle est enregistré dans le provider anthropic ; le SDK utilise les variables
Anthropic. Un endpoint qui exige une clé reste inutilisable sans sa vraie clé.
Aucun appel réseau provider n'a été exécuté en Cloud.

### Ollama, llama.cpp, endpoint OpenAI-compatible

```dotenv
OPENCODE_LOCAL_MODE=true
OPENCODE_LOCAL_PROVIDER_ID=ollama
OPENCODE_LOCAL_PROVIDER_NAME=Ollama local
OPENCODE_LOCAL_BASE_URL=http://ollama:11434/v1
OPENCODE_LOCAL_MODEL=modele-deja-installe
```

Pour llama.cpp : provider `llama.cpp`, URL de votre `llama-server` avec `/v1`.
Pour un autre endpoint, utiliser un identifiant simple et la même interface.
`OPENCODE_LOCAL_API_KEY` est facultatif. Une clé locale configurée est dans le
JSON généré (mode 600) ; protéger aussi les sauvegardes et les volumes.

Priorité managed : local explicite > Anthropic-compatible > cloud > fallback
`opencode/big-pickle`. Les configurations partielles explicites échouent plutôt
que de basculer silencieusement vers un autre provider. Existing prend priorité
sur toutes ces variables.

Avec `docker-compose.lab.ollama.yml`, Ollama est accessible à l'adresse du service
`ollama`, sans port publié. `localhost` dans OpenCode désigne OpenCode, pas l'hôte.
Pour un moteur déjà installé sur l'hôte, l'overlay cloud fournit
`host.docker.internal` (host-gateway sur Linux). Le moteur doit écouter sur une
interface joignable ; limiter son accès par pare-feu, ne pas l'exposer publiquement.
Le Compose upstream en réseau hôte conserve une topologie différente.

Aucun modèle n'est téléchargé automatiquement. Le volume `ollama-models` doit
contenir un modèle installé volontairement. Pour en télécharger un, une sortie
réseau temporaire serait nécessaire et doit être décidée localement.
L'overlay `docker-compose.lab.ollama-gpu.yml` active NVIDIA explicitement.
Installer les pilotes et NVIDIA Container Toolkit selon leurs documentations.
Sous WSL2, utiliser le pilote NVIDIA Windows compatible WSL, sans installer un
second pilote noyau Linux. Vérifier la VRAM réelle : RTX 2060 généralement 6 Go.
La taille de quantification, le contexte et l'offload déterminent la mémoire ;
aucune qualité de pentest autonome n'est garantie pour un petit modèle.

### Fusion de configuration

`apply-settings.sh` sérialise avec Python et remplace les fichiers atomiquement
(fichier temporaire voisin, fsync, rename, mode 600). Chaque fichier est atomique,
les deux fichiers ne constituent pas une transaction commune. Ne pas lancer deux
reconfigurations concurrentes. Le script ne démarre plus de TUI en arrière-plan.
Un JSON utilisateur invalide est conservé et provoque une erreur ; JSONC n'est
pas accepté pour ce fichier géré.

Darkmoon gère model/small_model, les modèles des 51 agents intégrés, les valeurs
par défaut de leurs prompts et modes, son entrée MCP et ses deux plugins. Les
champs utilisateur, agents supplémentaires, providers personnalisés et entrées
MCP étrangères sont conservés. Les plugins sont dédupliqués. Un provider local
sélectionné met à jour ses options/modèles sans supprimer les autres providers. La clé locale est remplacée par la valeur
actuelle de OPENCODE_LOCAL_API_KEY (ou une chaîne vide) pour éviter de transmettre
une ancienne clé à un nouvel endpoint.
L'entrée MCP `darkmoon` est réservée au câblage Darkmoon ; son champ `enabled`
existant est conservé. Déplacer une configuration MCP personnelle sous un autre
nom avant reconfiguration. Les autres propriétés de cette entrée réservée sont
remplacées, notamment les URL/commandes de transport.

Les politiques `permission` globales et par agent restent intactes. Sur un fichier
neuf, la politique globale est `{"*":"ask"}`. Une ancienne politique `allow` reste
**allow**, par respect de votre configuration : la remplacer manuellement par ask
avant une première campagne. Les prompts et règles agent/MCP ne sont pas une
barrière de sécurité ; un appel MCP générique peut regrouper plusieurs actions.
Le contrôle effectif repose surtout sur l'absence de socket, les capacités et les
restrictions du réseau/de la VM. Le comportement interactif du binaire reste à
vérifier localement ; ne pas automatiser les confirmations.

## ChatGPT/Codex et Claude : ce qui est vérifié

Le Dockerfile upstream clonait une branche flottante de `ASCIT31/opencode`.
Le build utilise désormais le commit **b0e41ff2c4069bafdaac9c11327659b1bf911f87**,
Bun **1.3.14** et `bun install --frozen-lockfile`. OPENCODE_REF est un argument
de build à réviser explicitement lors des mises à jour. Les dépendances système
et Python des images upstream ne sont pas toutes verrouillées : ce pin seul
n'assure pas une reconstruction bit à bit.

Inspection source réalisée le 19 octobre 2026 :

- [`plugin/openai/codex.ts`](https://github.com/ASCIT31/opencode/blob/b0e41ff2c4069bafdaac9c11327659b1bf911f87/packages/opencode/src/plugin/openai/codex.ts)
  propose « ChatGPT Pro/Plus (browser) » et « ChatGPT Pro/Plus (headless) ».
  Il utilise auth.openai.com, PKCE/device flow, renouvelle les credentials et filtre
  les modèles accessibles en OAuth. C'est un plugin **intégré à OpenCode**,
  pas un plugin tiers ajouté par ce travail.
- [`providers.ts`](https://github.com/ASCIT31/opencode/blob/b0e41ff2c4069bafdaac9c11327659b1bf911f87/packages/opencode/src/cli/cmd/providers.ts)
  fournit `opencode providers login --provider openai --method 'ChatGPT Pro/Plus (headless)'`.
  Cette révision n'enregistre pas de commande `opencode auth login`.
- [`auth/index.ts`](https://github.com/ASCIT31/opencode/blob/b0e41ff2c4069bafdaac9c11327659b1bf911f87/packages/opencode/src/auth/index.ts)
  persiste les entrées OAuth/API dans le répertoire de données `auth.json`, mode 600.

Cela établit la **présence de l'intégration native OpenCode dans le source**.
Cela ne prouve ni une autorisation officielle d'OpenAI pour ce fork, ni l'accès
réel de votre compte, ni ses quotas, ni le succès du build complet. Aucun compte,
cookie ou jeton personnel n'a été utilisé. Ne pas confondre OAuth ChatGPT et
facturation API OpenAI. Vérifier les conditions et méthodes proposées par votre
build au moment de l'installation, sans récupération manuelle de tokens.
Claude Pro/Max et Claude Code ne valent pas une clé API Anthropic ; aucune
compatibilité abonnement Claude n'est revendiquée ou ajoutée ici.

| Provider | Configuré | Auth persistante | Testé | Limites |
|---|---|---|---|---|
| ChatGPT/Codex | existing + intégration native dans le source épinglé | préservée | génération/persistance ; source inspecté | build, login et compte non testés |
| OpenAI API | managed | entrée API fusionnée | faux identifiants | aucun appel réel |
| Anthropic API | managed / endpoint dédié | autres credentials conservés | faux identifiants | aucun appel réel |
| OpenRouter | managed | entrée API fusionnée | faux identifiants | aucun appel réel |
| Ollama | OpenAI-compatible + overlay CPU/GPU | auth existante conservée | génération/Compose | moteur/modèle/GPU non testés |
| llama.cpp | OpenAI-compatible | auth existante conservée | génération | serveur non démarré |

## Sauvegarde, mise à jour et retour arrière

Avant de changer d'image, arrêter les campagnes et sauvegarder les volumes ;
les archives contiennent des credentials. Ne pas les committer. Exemple, sur le PC :

```bash
umask 077
mkdir -p backups
docker compose -p darkmoon-lab -f docker-compose.lab.yml exec -T opencode \
  tar czf - -C /root .config/opencode .local/share/opencode .opencode/agents \
  -C /opt/darkmoon/mcp/server/src/tools workflows > backups/state.tgz
cp .opencode.env backups/provider.env
```

Le Compose upstream utilisait des bind mounts ; le nouveau profil ne les importe
pas automatiquement. Conserver ces anciens dossiers et importer une copie dans
les volumes dédiés **avant** un premier démarrage réel. Ne pas croire que l'ancien
`auth.json` apparaît automatiquement dans le nouveau volume. Vérifier propriété,
chemins et sauvegarde avant copie. Aucun transfert de données personnel n'a été
exécuté en Cloud.

Enregistrer les identités d'images et le commit Git avant mise à jour. Pour revenir
en arrière, utiliser ce commit dans une copie propre et sélectionner l'ancienne
identité d'image ; conserver/restaurer les volumes à partir d'une sauvegarde
compatible. Ne pas utiliser `git reset --hard` dans un arbre avec vos modifications.
`update` ne télécharge pas une image désignée par son ID local et ne découvre
pas de nouvelle version à votre place : avec une image
immuable il réutilise la même version jusqu'à modification explicite de l'image.

## Dépannage

- Échec avant démarrage : vérifier `.opencode.env` brut, les variables requises,
  l'identité d'image et Compose >=2.30. Le validateur ne journalise pas les valeurs.
- JSON utilisateur invalide : sauvegarder/corriger le fichier ; aucune régénération
  destructive n'est effectuée. Ne pas désactiver la validation.
- MCP indique unhealthy en profil de base : résultat attendu, toolbox désactivée.
- Provider inaccessible : réseau interne par défaut ; l'overlay cloud ouvre la
  sortie sans filtrage par destination. Prévoir proxy/pare-feu de la VM.
- OAuth navigateur : le callback localhost du conteneur n'est pas celui du PC.
  Préférer la méthode headless présente dans cette révision, sans publier de port.
- Agent absent : vérifier les volumes d'agents/workflows ; le seeding ne remplace
  jamais un dossier déjà peuplé. Compléter manuellement les nouveaux defaults.
- Consulter `docker compose ... logs --tail 100 opencode` localement. Traiter les
  journaux comme sensibles, notamment ceux des outils et providers tiers.

Voir [validation](VALIDATION.md) et [checklist PC](LOCAL.md).
