#!/usr/bin/env bash
#
# Exclude unwanted plugins from the oh-my-zsh checkout.
#
# Runs as the `post-repos` bootstrap hook, after [bootstrap.repos] has cloned
# or fast-forwarded ~/.oh-my-zsh.
#
# Why sparse-checkout and not `rm -rf`: deleting tracked files leaves the repo
# dirty, and mise then refuses to converge it —
#   "repos: ~/.oh-my-zsh has local changes; commit, stash, or clean them"
# — which breaks `mise bootstrap` entirely. Sparse-checkout keeps the working
# tree clean, so `git pull --ff-only` still succeeds and the exclusion holds.
#
set -euo pipefail

OMZ="$HOME/.oh-my-zsh"

# Plugins to keep out of the working tree.
EXCLUDE=(
  '!/plugins/asdf'
)

[ -d "$OMZ/.git" ] || { echo "==> $OMZ is not a git checkout; skipping"; exit 0; }

echo "==> Applying oh-my-zsh sparse-checkout exclusions"
git -C "$OMZ" sparse-checkout set --no-cone '/*' "${EXCLUDE[@]}"

for pattern in "${EXCLUDE[@]}"; do
  path="${pattern#!}"
  if [ -e "$OMZ${path}" ]; then
    echo "    WARNING: ${path} still present"
  else
    echo "    excluded: ${path}"
  fi
done
