#!/usr/bin/env bash
# Personnalise le modèle pour votre équipe, une fois, juste après « Use this template » :
#   ./init.sh <équipe> [app]      (app : hello par défaut)
# Remplace monequipe et hello dans deploy/ et .github/, renomme deploy/hello en deploy/<app>. Rien d'autre : relisez le
# diff (git diff), puis commitez. Relancé avec les mêmes noms, il ne change rien.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
TEAM="${1:-}"; APP="${2:-hello}"

echo "[1/3] Noms"
[[ "$TEAM" =~ ^[a-z0-9]+$ ]] || { echo "usage: ./init.sh <équipe> [app] ; équipe : minuscules et chiffres, celle donnée par l'admin" >&2; exit 2; }
[[ "$APP" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || { echo "app « $APP » : minuscules, chiffres et tirets, ni au début ni à la fin" >&2; exit 2; }
[ $(( ${#TEAM} + ${#APP} + 1 )) -le 63 ] || { echo "namespace $TEAM-$APP trop long (63 caractères au plus)" >&2; exit 2; }
[ $(( ${#APP} + 4 )) -le 63 ] || { echo "hôte $APP-dev.alson-lab.fr trop long (app : 59 caractères au plus)" >&2; exit 2; }

echo "[2/3] Remplacements"
if ! grep -rqw monequipe deploy .github 2>/dev/null; then
  if [ -d "deploy/$APP" ] && grep -qE "^ +team: $TEAM( |$)" "deploy/$APP/dev/kustomization.yaml" 2>/dev/null; then
    echo "déjà personnalisé pour $TEAM/$APP : rien à faire"; exit 0
  fi
  echo "modèle déjà personnalisé avec d'autres noms : refaites-le depuis le modèle d'origine" >&2; exit 1
fi
[ "$APP" = hello ] || { [ ! -e "deploy/$APP" ] || { echo "deploy/$APP existe déjà" >&2; exit 1; }; mv deploy/hello "deploy/$APP"; }
# perl plutôt que sed : \b (mot entier) est le même sur macOS, Linux et Git pour Windows. hello-page et hello-dev
# changent aussi (le tiret coupe le mot), « Hello » de la page reste.
while IFS= read -r f; do
  T="$TEAM" A="$APP" perl -pi -e 's/\bmonequipe\b/$ENV{T}/g; s/\bhello\b/$ENV{A}/g' "$f"
done < <(grep -rlwE 'monequipe|hello' deploy .github)

echo "[3/3] Résultat"
grep -rqw monequipe deploy .github && { echo "monequipe encore présent : signalez-le à l'admin" >&2; exit 1; }
echo "Personnalisé pour l'équipe $TEAM, app $APP (namespace $TEAM-$APP, hôtes $APP-dev.alson-lab.fr et $APP.alson-lab.fr)."
echo "Ensuite : git diff, puis une branche et une PR (README, étape 3)."
