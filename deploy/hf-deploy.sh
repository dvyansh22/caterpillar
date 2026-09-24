#!/usr/bin/env bash
# Deploy the task-time ETA service to a Hugging Face Docker Space.
#
# Prereqs (one time):
#   1. Create the Space on https://huggingface.co/new-space
#        - SDK: Docker (blank), Hardware: CPU basic (free)
#   2. Auth for the push: run `pip install huggingface_hub && huggingface-cli login`
#        (paste a WRITE token from https://huggingface.co/settings/tokens), OR let
#        `git push` prompt for username + token.
#
# Usage:
#   deploy/hf-deploy.sh https://huggingface.co/spaces/<user>/<space-name>
set -euo pipefail

SPACE_URL="${1:?Pass your HF Space git URL, e.g. https://huggingface.co/spaces/you/smart-operator-eta}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"

echo "Cloning $SPACE_URL ..."
git clone "$SPACE_URL" "$WORK/space"
cd "$WORK/space"

# Assemble the minimal Space: root Dockerfile + Space README + backend/ + ml/.
cp "$REPO/Dockerfile" .
cp "$REPO/deploy/hf-space-README.md" README.md
rm -rf backend ml
cp -r "$REPO/backend" .
cp -r "$REPO/ml" .

# Don't ship generated data or trained models (the build regenerates them), or caches.
rm -rf ml/data/synthetic/* ml/models/*.joblib 2>/dev/null || true
find . -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true

git add -A
git commit -m "Deploy Smart Operator task-time ETA service" || { echo "Nothing to commit."; exit 0; }
git push

echo
echo "Pushed. Watch the build on the Space page; when it is 'Running', the base URL is:"
echo "  ${SPACE_URL/huggingface.co\/spaces/<user>-<space>.hf.space}  (or see the Space's 'Embed this Space' link)"
echo "Test it:  curl <space-url>/health"
