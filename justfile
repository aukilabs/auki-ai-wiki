# Show available recipes
default:
    @just --list

# Show branch + dirty/clean state across all repos
status:
    #!/usr/bin/env bash
    set -euo pipefail
    _print_status() {
        local label="$1"
        local dir="${2:-.}"
        local branch
        branch=$(git -C "$dir" branch --show-current 2>/dev/null)
        if [ -z "$branch" ]; then
            branch="(detached!)"
        fi
        local count
        count=$(git -C "$dir" status --short | awk 'END{print NR}')
        if [ "$count" -gt 0 ]; then
            printf "%-45s %s (dirty, %s files)\n" "$label" "$branch" "$count"
        else
            printf "%-45s %s\n" "$label" "$branch"
        fi
    }
    git submodule foreach --quiet 'echo "$displaypath"' | while read -r path; do
        _print_status "$path" "$path"
    done
    _print_status "." "."

# Alias for branch
checkout name: (branch name)

# Checkout/create <name> in parent and all submodules
branch name:
    #!/usr/bin/env bash
    set -euo pipefail
    export BRANCH_NAME="{{name}}"
    echo "=== Switching to branch '$BRANCH_NAME' ==="
    git submodule foreach --quiet '
        echo "--- $name ---"
        git fetch origin --quiet
        if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
            git checkout "$BRANCH_NAME" --quiet
            echo "  checked out $BRANCH_NAME"
        elif git ls-remote --exit-code --heads origin "$BRANCH_NAME" > /dev/null 2>&1; then
            git checkout --track "origin/$BRANCH_NAME" --quiet
            echo "  checked out $BRANCH_NAME (tracking origin)"
        else
            default_branch=$(git remote show origin | grep "HEAD branch" | sed "s/.*: //")
            git checkout -b "$BRANCH_NAME" "origin/${default_branch}" --quiet
            echo "  created $BRANCH_NAME from origin/${default_branch}"
        fi
    '
    echo "--- parent ---"
    git fetch origin --quiet
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        git checkout "$BRANCH_NAME" --quiet
        echo "  checked out $BRANCH_NAME"
    elif git ls-remote --exit-code --heads origin "$BRANCH_NAME" > /dev/null 2>&1; then
        git checkout --track "origin/$BRANCH_NAME" --quiet
        echo "  checked out $BRANCH_NAME (tracking origin)"
    else
        default_branch=$(git remote show origin | grep "HEAD branch" | sed "s/.*: //")
        git checkout -b "$BRANCH_NAME" "origin/${default_branch}" --quiet
        echo "  created $BRANCH_NAME from origin/${default_branch}"
    fi
    echo "=== Done ==="

# Pull latest from remote for parent and all submodules
sync:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Syncing submodules ==="
    git submodule foreach --quiet '
        echo "--- $name ---"
        git fetch origin --quiet
        branch=$(git branch --show-current)
        if [ -z "$branch" ]; then
            echo "  (detached HEAD, skipping pull)"
        elif ! git rev-parse --abbrev-ref "@{u}" >/dev/null 2>&1; then
            echo "  (no upstream tracking branch, skipping pull)"
        else
            git pull --ff-only
        fi
    '
    echo "--- parent ---"
    parent_branch=$(git branch --show-current)
    if [ -z "$parent_branch" ]; then
        echo "  (detached HEAD, skipping pull)"
    elif ! git rev-parse --abbrev-ref "@{u}" &>/dev/null; then
        echo "  (no upstream tracking branch, skipping pull)"
    else
        git pull --ff-only
    fi
    echo "=== Done ==="

# Stage all changes in dirty repos (git add -A)
add:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Staging changes ==="
    git submodule foreach --quiet '
        count=$(git status --short | wc -l | tr -d " ")
        if [ "$count" -gt 0 ]; then
            echo "--- $name ---"
            git add -A
            echo "  staged $count file(s)"
        fi
    '
    count=$(git status --short | wc -l | tr -d " ")
    if [ "$count" -gt 0 ]; then
        echo "--- parent ---"
        git add -A
        echo "  staged $count file(s)"
    fi
    echo "=== Done ==="

# Commit across repos. With message: unified. Without: interactive per-repo.
commit msg="":
    #!/usr/bin/env bash
    set -euo pipefail
    export COMMIT_MSG="{{msg}}"
    if [ -n "$COMMIT_MSG" ]; then
        echo "=== Committing: $COMMIT_MSG ==="
        git submodule foreach --quiet '
            if ! git diff --cached --quiet 2>/dev/null; then
                echo "--- $name ---"
                git commit -m "$COMMIT_MSG"
            fi
        '
        if ! git diff --cached --quiet 2>/dev/null; then
            echo "--- parent ---"
            git commit -m "$COMMIT_MSG"
        fi
        echo "=== Done ==="
    else
        echo "=== Interactive commit ==="
        while read -r path; do
            if ! git -C "$path" diff --cached --quiet 2>/dev/null; then
                echo ""
                echo "--- $path ---"
                git -C "$path" diff --cached --stat
                echo ""
                printf "  Commit message (empty to skip): "
                read -r cmsg < /dev/tty
                if [ -n "$cmsg" ]; then
                    git -C "$path" commit -m "$cmsg"
                else
                    echo "  skipped"
                fi
            fi
        done < <(git submodule foreach --quiet 'echo "$displaypath"')
        if ! git diff --cached --quiet 2>/dev/null; then
            echo ""
            echo "--- parent ---"
            git diff --cached --stat
            echo ""
            printf "  Commit message (empty to skip): "
            read -r cmsg < /dev/tty
            if [ -n "$cmsg" ]; then
                git commit -m "$cmsg"
            else
                echo "  skipped"
            fi
        fi
        echo "=== Done ==="
    fi

# Push repos that have unpushed commits on the current branch
push:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Pushing changed repos ==="
    _push_if_needed() {
        local label="$1"
        local dir="${2:-.}"
        local branch
        branch=$(git -C "$dir" branch --show-current 2>/dev/null)
        if [ -z "$branch" ]; then
            echo "--- $label ---"
            echo "  skipped (detached HEAD)"
            return
        fi
        local upstream
        if upstream=$(git -C "$dir" rev-parse --abbrev-ref "@{u}" 2>/dev/null); then
            local count
            count=$(git -C "$dir" log "$upstream..HEAD" --oneline | wc -l | tr -d " ")
            if [ "$count" -gt 0 ]; then
                echo "--- $label ---"
                git -C "$dir" push -u origin "$branch"
                echo "  pushed $count commit(s)"
            fi
        else
            local has_commits
            has_commits=$(git -C "$dir" log --oneline -1 2>/dev/null | wc -l | tr -d " ")
            if [ "$has_commits" -gt 0 ]; then
                echo "--- $label ---"
                git -C "$dir" push -u origin "$branch"
                echo "  pushed (new remote branch)"
            fi
        fi
    }
    while read -r path; do
        _push_if_needed "$path" "$path"
    done < <(git submodule foreach --quiet 'echo "$displaypath"')
    _push_if_needed "parent" "."
    echo "=== Done ==="

# Create GitHub PRs for repos with pushed feature branches
pr:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Creating PRs ==="
    _maybe_pr() {
        local label="$1"
        local dir="${2:-.}"
        local branch
        branch=$(git -C "$dir" branch --show-current 2>/dev/null)
        if [ -z "$branch" ]; then return; fi
        local default_branch
        default_branch=$(git -C "$dir" remote show origin 2>/dev/null | grep "HEAD branch" | sed "s/.*: //")
        if [ "$branch" = "$default_branch" ]; then return; fi
        if ! git -C "$dir" ls-remote --exit-code --heads origin "$branch" > /dev/null 2>&1; then
            return
        fi
        local existing
        existing=$(cd "$dir" && gh pr list --head "$branch" --json number --jq 'length' 2>/dev/null || echo "0")
        if [ "$existing" -gt 0 ]; then
            local url
            url=$(cd "$dir" && gh pr list --head "$branch" --json url --jq '.[0].url' 2>/dev/null)
            echo "--- $label ---"
            echo "  PR already exists: $url"
            return
        fi
        echo "--- $label ---"
        local url
        url=$(cd "$dir" && gh pr create --fill 2>&1)
        echo "  $url"
    }
    while read -r path; do
        _maybe_pr "$path" "$path"
    done < <(git submodule foreach --quiet 'echo "$displaypath"')
    _maybe_pr "parent" "."
    echo "=== Done ==="

# Delete local branches whose remote was merged & deleted
prune:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Pruning merged branches ==="
    _prune_repo() {
        local label="$1"
        local dir="${2:-.}"
        local current
        current=$(git -C "$dir" branch --show-current 2>/dev/null)
        local default_branch
        default_branch=$(git -C "$dir" remote show origin 2>/dev/null | grep "HEAD branch" | sed "s/.*: //")
        git -C "$dir" fetch --prune --quiet
        local header_printed=false
        while read -r b; do
            if [ "$b" = "$current" ] || [ "$b" = "$default_branch" ]; then
                continue
            fi
            if ! git -C "$dir" ls-remote --exit-code --heads origin "$b" > /dev/null 2>&1; then
                if [ "$header_printed" = false ]; then
                    echo "--- $label ---"
                    header_printed=true
                fi
                git -C "$dir" branch -d "$b" 2>/dev/null && echo "  deleted $b (merged)" || true
            fi
        done < <(git -C "$dir" branch --merged "origin/$default_branch" 2>/dev/null | sed 's/^[* ] //')
    }
    while read -r path; do
        _prune_repo "$path" "$path"
    done < <(git submodule foreach --quiet 'echo "$displaypath"')
    _prune_repo "parent" "."
    echo "=== Done ==="

# Show last N commits across parent and all submodules (default: 5)
log n="5":
    #!/usr/bin/env bash
    set -euo pipefail
    if ! [[ "{{n}}" =~ ^[0-9]+$ ]]; then
        echo "error: n must be a positive integer, got '{{n}}'" >&2
        exit 1
    fi
    echo "=== Last {{n}} commits ==="
    git submodule foreach --quiet '
        echo "--- $name ---"
        git log --oneline -'"{{n}}"'
        echo ""
    '
    echo "--- parent ---"
    git log --oneline -"{{n}}"
    echo ""
    echo "=== Done ==="

# Show uncommitted diffs across parent and all submodules
diff:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Uncommitted diffs ==="
    git submodule foreach --quiet '
        d=$(git diff)
        if [ -n "$d" ]; then
            echo "--- $name ---"
            printf "%s\n" "$d"
            echo ""
        fi
    '
    d=$(git diff)
    if [ -n "$d" ]; then
        echo "--- parent ---"
        printf "%s\n" "$d"
    fi
    echo "=== Done ==="

# Add a GitHub repo as a submodule under reference-code/
# Usage: just add-repo <url> [optional-folder-name]
add-repo url name="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n {{quote(name)}} ]; then
        ./add-reference-repo.sh {{quote(url)}} {{quote(name)}}
    else
        ./add-reference-repo.sh {{quote(url)}}
    fi
