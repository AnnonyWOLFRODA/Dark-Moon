# À faire lorsque je serai sur mon PC fixe

Ces opérations sont **non exécutées en Cloud**. Le profil de base sert à valider
la configuration/auth ; il ne permet pas de campagne toolbox. Faire les étapes
avancées dans une VM Linux dédiée et jetable, jamais sur un Docker partagé.

## 1. Récupérer les changements

En l'absence de PR créée par la session, télécharger `darkmoon-selfhost.patch`
à côté du futur checkout, puis, depuis ce dossier :

```bash
git clone https://github.com/AnnonyWOLFRODA/Dark-Moon.git
cd Dark-Moon
git switch --detach 3385fd4874b2b793c18f148de637a250fe1ae829
git switch -c selfhost-hardening
git apply --check ../darkmoon-selfhost.patch
git apply ../darkmoon-selfhost.patch
```

Si le fork est déjà cloné, conserver ses changements et effectuer ces opérations
dans une copie propre ; ne pas écraser le checkout existant.

## 2. Vérifier les prérequis et les tests offline

Utiliser Linux ou le terminal de la distribution WSL2, pas PowerShell :

```bash
bash --version
python3 --version
git --version
python3 -m venv /tmp/darkmoon-tests
/tmp/darkmoon-tests/bin/python -m pip install -r mcp/requirements.txt -r tools/selfhost/requirements.txt
PATH="/tmp/darkmoon-tests/bin:$PATH" bash tools/selfhost/check.sh
```

## 3. Vérifier Docker et construire explicitement

Le build OpenCode est coûteux ; utiliser les caches et ne lancer qu'un build à
la fois. Le build toolbox installe de nombreux outils ; il n'est requis que pour
le profil avancé. Ces builds n'ont pas été testés en Cloud.

```bash
docker version
docker info
docker compose version   # >=2.30
free -h
df -h .
docker build -f Dockerfile.opencode -t darkmoon-opencode:selfhost .
export DARKMOON_OPENCODE_IMAGE="$(docker image inspect --format '{{.Id}}' darkmoon-opencode:selfhost)"
```

## 4. Vérifier NVIDIA si nécessaire

```bash
nvidia-smi
```

Relever la mémoire et le modèle exact. Le mode CPU ne dépend pas de ce résultat.
Pour l'overlay GPU, vérifier aussi les prérequis NVIDIA Container Toolkit sur
le daemon choisi ; ne pas installer de pilotes Linux noyau dans WSL2.

## 5. Configurer le provider

```bash
umask 077
# Seulement si aucun fichier n'existe ; ne pas écraser votre configuration.
if [ ! -e .opencode.env ]; then
  cp docs/selfhost/provider.env.example .opencode.env
fi
chmod 600 .opencode.env
${EDITOR:-vi} .opencode.env
python3 tools/selfhost/validate-env.py .opencode.env
```

Choisir les variables du [guide providers](README.md). Ne saisir les vraies
clés que localement. Les noms de modèles dans les exemples doivent être remplacés
par ceux effectivement disponibles.

## 6. Démarrer le laboratoire

Le mode sans sortie réseau fonctionne avec un Ollama déjà approvisionné :

```bash
# Si Ollama est déjà présent localement, sélectionner son image immuable.
# Cette commande suppose que l'image nommée ollama/ollama est déjà installée.
export DARKMOON_OLLAMA_IMAGE="$(docker image inspect --format '{{.Id}}' ollama/ollama)"
local_llm=(docker compose -p darkmoon-lab -f docker-compose.lab.yml -f docker-compose.lab.ollama.yml)
"${local_llm[@]}" config --quiet
"${local_llm[@]}" up -d
"${local_llm[@]}" exec -T ollama ollama list
```

Ne pas poursuivre ce chemin sans modèle déjà installé. Ajouter explicitement
`-f docker-compose.lab.ollama-gpu.yml` pour NVIDIA, après vérification du runtime.
Aucun `ollama pull` n'est exécuté automatiquement.

Pour une API cloud ou une connexion interactive, la sortie réseau doit être
ouverte explicitement. Cet overlay ne filtre pas les destinations ; ne l'utiliser
qu'après configuration du pare-feu/proxy de la VM :

```bash
cloud=(docker compose -p darkmoon-lab -f docker-compose.lab.yml -f docker-compose.lab.cloud.yml)
"${cloud[@]}" config --quiet
"${cloud[@]}" up -d
"${cloud[@]}" logs --tail 100 opencode
```

Les commandes `install.sh` concernent seulement le profil de base. Employer la
même liste `-f` pour toute opération sur un profil optionnel. Ne pas alterner
install.sh et un Compose optionnel en supposant que les overlays sont mémorisés.

## 7. Connexion OpenCode interactive, si proposée par le build

Avec OPENCODE_AUTH_MODE=existing :

```bash
"${cloud[@]}" exec opencode opencode --help
"${cloud[@]}" exec opencode opencode providers login --help
"${cloud[@]}" exec opencode opencode providers login --provider openai --method 'ChatGPT Pro/Plus (headless)'
"${cloud[@]}" exec opencode opencode models
```

Suivre le flux natif dans le navigateur. Ne pas extraire/coller de cookies ou
jetons. Si cette méthode manque ou est refusée, arrêter cette validation et
utiliser un provider officiellement disponible pour ce compte. Ne pas supposer
que ChatGPT Plus/Pro ou Claude Pro/Max donne accès à une API facturée séparément.
Après login, choisir le modèle réellement listé, éditer .opencode.env et refaire
`"${cloud[@]}" up -d`. Ne pas publier le callback navigateur du conteneur.

## 8. Vérifier la persistance sans afficher les credentials

Ne lancer aucun modèle pendant la comparaison : un renouvellement OAuth normal
pourrait modifier légitimement auth.json.

```bash
before=$("${cloud[@]}" exec -T opencode sha256sum /root/.local/share/opencode/auth.json)
"${cloud[@]}" restart opencode
after=$("${cloud[@]}" exec -T opencode sha256sum /root/.local/share/opencode/auth.json)
test "$before" = "$after"
"${cloud[@]}" exec -T opencode stat -c '%a' /root/.local/share/opencode/auth.json
```

Un succès confirme la conservation au redémarrage, pas la validité des tokens.
Vérifier les journaux si l'entrypoint n'a pas encore terminé son démarrage.

## 9. Vérifier les restrictions du profil de base

```bash
docker compose -p darkmoon-lab -f docker-compose.lab.yml config
"${cloud[@]}" exec -T opencode test ! -S /var/run/docker.sock
"${cloud[@]}" exec -T opencode sh -c 'grep -E "CapEff|NoNewPrivs" /proc/1/status'
"${cloud[@]}" port opencode 8181  # aucun port publié attendu
```

Examiner également les montages et le réseau résolus. Le profil cloud ouvre la
sortie : seul un pare-feu/proxy externe peut en limiter les cibles. Une réponse
à une commande de diagnostic ne prouve pas une isolation complète. Ne pas faire
de tentative de connexion à une infrastructure Résurgence pour tester l'isolation.

## 10. Premier contrôle local non destructif d'une cible volontairement vulnérable

Cette étape est **bloquée tant que la VM dédiée et son confinement externe ne
sont pas en place**. Le contrôle ci-dessous est une requête HEAD directe, pas
une campagne autonome. Il ne valide pas la portée des commandes d'un agent.
L'image cible doit avoir été obtenue volontairement au préalable (pas de modèle
LLM). Exporter son identité après inspection de l'image locale :

```bash
export DARKMOON_TARGET_IMAGE="$(docker image inspect --format '{{.Id}}' bkimminich/juice-shop)"
docker build -f Dockerfile -t darkmoon-toolbox:selfhost .
export DARKMOON_TOOLBOX_IMAGE="$(docker image inspect --format '{{.Id}}' darkmoon-toolbox:selfhost)"
# Uniquement le socket du daemon de la VM dédiée, jamais celui d'une machine partagée.
export DARKMOON_LAB_DOCKER_SOCKET=/var/run/docker.sock
advanced=(docker compose -p darkmoon-lab -f docker-compose.lab.yml -f docker-compose.lab.advanced.yml)
"${advanced[@]}" config --quiet
"${advanced[@]}" up -d
network=$(docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{$name}}{{end}}' darkmoon-lab-toolbox)
docker run -d --name darkmoon-local-target --network "$network" "$DARKMOON_TARGET_IMAGE"
# Attendre l'initialisation en examinant les logs, puis un seul contrôle HTTP :
docker logs --tail 30 darkmoon-local-target
"${advanced[@]}" exec -T darkmoon curl --connect-timeout 5 --max-time 10 -I http://darkmoon-local-target:3000/
```

Aucun port cible n'est publié. Aucun scan ni exploitation n'est lancé. Une campagne
Darkmoon complète reste à valider séparément, avec provider, prompts, contrôles MCP
et limitations réseau externes. Ne pas utiliser la whitelist du prompt comme
seule autorisation technique.

## 11. Arrêter proprement

Exécuter uniquement les lignes correspondant aux profils réellement démarrés :

```bash
"${cloud[@]}" stop
"${local_llm[@]}" stop
"${advanced[@]}" stop
docker stop darkmoon-local-target
```

Ne pas supprimer de volumes pour arrêter. Laisser les images et caches en place.

## 12. Diagnostiquer

```bash
./install.sh diagnose
"${cloud[@]}" ps
"${cloud[@]}" logs --tail 100 opencode
"${local_llm[@]}" logs --tail 100 ollama
"${advanced[@]}" logs --tail 100 opencode darkmoon
```

Traiter les logs comme sensibles. Utiliser uniquement les commandes des profils
activés. Sauvegarder avant une mise à jour ; ne pas compenser une erreur de
configuration par une purge des volumes ou une désactivation TLS.
