#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 GET MADE
# Keeps the vault in sync with a Git repository.
#
# - Changes made by agents on the server are committed and pushed.
# - Changes made in Obsidian (pushed by the Obsidian Git plugin) are pulled.
# - On conflicts the Obsidian version wins; the agent version stays in the
#   Git history.
# - Protected folders (PROTECTED_PATHS) may only change through Git. If an
#   agent writes there, its version is copied to REJECTED_DIR and the
#   folder is reset.
# - Hidden folders (HIDDEN_PATHS) live only in Git and Obsidian. They are
#   never checked out on the server, so agents can neither find nor read them.
set -u

VAULT="${VAULT_DIR:-/vault}"
BRANCH="${GIT_BRANCH:-main}"
INTERVAL="${SYNC_INTERVAL:-120}"
PROTECTED="${PROTECTED_PATHS-knowledge about-me}"
HIDDEN="${HIDDEN_PATHS-private}"
FOLDERS="${VAULT_FOLDERS-knowledge docs about-me agents inbox}"
REJECTED="${REJECTED_DIR:-inbox/_rejected}"
REMOTE="${GIT_REMOTE:-}"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*"; }

git config --global user.name "${GIT_AUTHOR_NAME:-vault-sync}"
git config --global user.email "${GIT_AUTHOR_EMAIL:-vault-sync@localhost}"
git config --global init.defaultBranch "$BRANCH"
git config --global --add safe.directory "$VAULT"
git config --global core.quotePath false
if [ -n "${GIT_TOKEN:-}" ]; then
	# The token stays in the environment and never ends up in .git/config.
	git config --global credential.helper \
		'!f() { echo "username=x-access-token"; echo "password=${GIT_TOKEN}"; }; f'
fi

cd "$VAULT" || { log "Vault directory $VAULT is missing"; exit 1; }

remote_has_branch() {
	git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1
}

scaffold() {
	for d in $FOLDERS; do
		mkdir -p "$d"
		if [ -z "$(ls -A "$d" 2>/dev/null)" ]; then
			: >"$d/.gitkeep"
			# Stage right away so protection does not reject the file as foreign.
			git add -- "$d/.gitkeep" 2>/dev/null
		fi
	done
	if [ ! -e .gitignore ]; then
		cat >.gitignore <<'EOG'
# Device-specific Obsidian state
.obsidian/workspace*.json
.obsidian/cache
.trash/
.DS_Store
EOG
	fi
}

# Keep hidden folders off the server with a sparse checkout.
apply_hidden() {
	if [ -n "$HIDDEN" ]; then
		set -- '/*'
		for h in $HIDDEN; do set -- "$@" "!/$h/"; done
		git sparse-checkout set --no-cone "$@" 2>/dev/null ||
			log "Could not set sparse checkout"
	elif [ "$(git config --get core.sparseCheckout)" = "true" ]; then
		git sparse-checkout disable 2>/dev/null
	fi
}

init_repo() {
	[ -d .git ] && return 0
	log "Initialising Git repository in the vault"
	git init -q || return 1
	if [ -n "$REMOTE" ]; then
		git remote add origin "$REMOTE"
		if remote_has_branch; then
			git fetch -q origin "$BRANCH" || return 1
			# Point the index at the remote, keep existing files and only
			# check out files that are missing locally.
			git reset -q "origin/$BRANCH"
			apply_hidden
			git ls-files -d -z | xargs -0 -r git checkout -q --
			log "Adopted existing vault from the remote"
		fi
	fi
}

# Strips the metadata header (frontmatter) and leading blank lines.
strip_frontmatter() {
	awk 'NR==1 && $0=="---" { fm=1; next }
		fm==1 { if ($0=="---") fm=2; next }
		{ if (!started && $0 ~ /^[[:space:]]*$/) next; started=1; print }'
}

reject() {
	dest="$REJECTED/$stamp/$1"
	mkdir -p "$(dirname "$dest")"
	cp -p "$1" "$dest"
	log "Protected: change to '$1' rejected, copy saved to '$dest'"
}

# Reverts changes in protected folders that did not come through Git.
# Exception: Basic Memory adds a metadata header (title, type, permalink)
# when indexing. If only that header changed, the file is kept.
protect() {
	git rev-parse -q --verify HEAD >/dev/null 2>&1 || return 0
	stamp="$(date -u +%Y%m%d-%H%M%S)"
	for p in $PROTECTED; do
		# Modified or deleted files Git already knows
		git ls-files -m -z -- "$p" | tr '\0' '\n' |
			while IFS= read -r f; do
				[ -n "$f" ] || continue
				if [ -f "$f" ]; then
					old="$(git show "HEAD:$f" | strip_frontmatter)"
					new="$(strip_frontmatter <"$f")"
					[ "$old" = "$new" ] && continue
					reject "$f"
				else
					log "Protected: deletion of '$f' reverted"
				fi
				git checkout -q HEAD -- "$f"
			done
		# New files that did not come through Git
		git ls-files -o --exclude-standard -z -- "$p" | tr '\0' '\n' |
			while IFS= read -r f; do
				[ -n "$f" ] || continue
				reject "$f"
				rm -f -- "$f"
			done
	done
	# Hidden folders: nothing may exist here on the server.
	for p in $HIDDEN; do
		[ -d "$p" ] || continue
		git ls-files -o --exclude-standard -z -- "$p" | tr '\0' '\n' |
			while IFS= read -r f; do
				[ -n "$f" ] || continue
				reject "$f"
				rm -f -- "$f"
			done
		find "$p" -depth -type d -empty -delete 2>/dev/null
	done
}

sync_once() {
	protect
	git add -A
	if ! git diff --cached --quiet; then
		git commit -q -m "vault: changes from server ($(date -u +%Y-%m-%dT%H:%MZ))" &&
			log "Committed local changes"
	fi
	[ -n "$REMOTE" ] || return 0

	if remote_has_branch; then
		git fetch -q origin "$BRANCH" || { log "Fetch failed"; return 1; }
		if git rev-parse -q --verify HEAD >/dev/null 2>&1; then
			if ! git merge -q --no-edit -X theirs "origin/$BRANCH" >/dev/null 2>&1; then
				git merge --abort 2>/dev/null
				log "Merge conflict that cannot be resolved automatically. Please check by hand."
				return 1
			fi
		fi
	fi
	git rev-parse -q --verify HEAD >/dev/null 2>&1 || return 0
	if [ "$(git rev-parse HEAD)" != "$(git rev-parse -q --verify "origin/$BRANCH" 2>/dev/null)" ]; then
		git push -q origin "HEAD:$BRANCH" && log "Pushed" || log "Push failed"
	fi
}

init_repo || { log "Initialisation failed"; exit 1; }
# Set the remote on every start so it can also be added later.
if [ -n "$REMOTE" ]; then
	if git remote get-url origin >/dev/null 2>&1; then
		git remote set-url origin "$REMOTE"
	else
		git remote add origin "$REMOTE"
	fi
fi
apply_hidden
scaffold
[ -n "$REMOTE" ] || log "No GIT_REMOTE set: the vault is only versioned locally"

# RUN_ONCE=1 runs exactly one pass (for tests and debugging).
if [ "${RUN_ONCE:-0}" = "1" ]; then
	sync_once
	exit $?
fi

log "Syncing every ${INTERVAL}s, protected: ${PROTECTED:-none}, hidden: ${HIDDEN:-none}"
while :; do
	sync_once
	sleep "$INTERVAL"
done
