#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./git-auto-push.sh [options]

Default behavior:
  - Stages all changes (including new files),
  - Commits them with the current timestamp message,
  - Then pushes your current branch to its configured upstream (e.g. origin/master).
  - Skips committing if the working tree isn't dirty.

Options:
  --no-auto-commit         Push without auto-committing (refuses if working tree is dirty).
  --message "<msg>"       Commit message (used when auto-commit is enabled).
  --dry-run                Run git push --dry-run (no network changes).
EOF
}

AUTO_COMMIT=1
COMMIT_MESSAGE="${GIT_AUTO_COMMIT_MESSAGE:-}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-auto-commit) AUTO_COMMIT=0; shift ;;
    --message)
      COMMIT_MESSAGE="${2:-}"
      shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not inside a git repository." >&2
  exit 1
fi

# If your working tree is dirty, pushing won't include those changes anyway.
if [[ -n "$(git status --porcelain)" ]]; then
  if [[ "$AUTO_COMMIT" -ne 1 ]]; then
    echo "Working tree has uncommitted changes."
    echo "Commit them first, or re-run with: --auto-commit" >&2
    exit 1
  fi

  if [[ -z "$COMMIT_MESSAGE" ]]; then
    COMMIT_MESSAGE="Auto-commit $(date -Iseconds)"
  fi

  git add -A

  # Avoid empty commits in case nothing staged changed.
  if git diff --cached --quiet; then
    echo "No changes staged after git add -A; skipping commit." >&2
  else
    git commit -m "$COMMIT_MESSAGE"
  fi
fi

UPSTREAM_REF="$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)"
if [[ -z "$UPSTREAM_REF" ]]; then
  echo "No upstream configured for the current branch."
  echo "Set it with: git push -u origin HEAD" >&2
  exit 1
fi

REMOTE="${UPSTREAM_REF%%/*}"  # origin
BRANCH="${UPSTREAM_REF#*/}"  # main (or similar)

if [[ "$DRY_RUN" -eq 1 ]]; then
  git push --dry-run "$REMOTE" "$BRANCH"
else
  git push "$REMOTE" "$BRANCH"
fi

