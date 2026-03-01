---
allowed-tools: Read, Bash, Write
argument-hint: [base-branch] [pr-title]
description: Create a GitHub pull request from the current branch using gh
model: sonnet
---

# Create Pull Request

Create a pull request from the current branch: $ARGUMENTS

## Current State

- Current branch: !`git branch --show-current`
- Git status: !`git status --short --branch`
- Upstream branch: !`git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "No upstream"`
- Recent branch commits: !`git log --oneline -10`

## Important

- Never open PRs directly from `main`
- Direct PR from `develop` to `main` is not allowed
- For version releases, use `release/v<version>` branch and target `main`
- For `main` target PRs, allow only `release/v<version>` or `hotfix/*` head branches
- Ensure local branch is pushed before creating PR
- Use `gh pr create` with a structured body

## Task

1. **Resolve PR parameters**
   - Parse `$ARGUMENTS`
   - If base branch is not provided, default to `main`
   - If PR title is not provided, generate from branch commit intent

2. **Validate branch safety**
   ```bash
   BASE_BRANCH="${BASE_BRANCH:-main}"
   CURRENT_BRANCH=$(git branch --show-current)
   if [ "$CURRENT_BRANCH" = "main" ]; then
     echo "Do not create PR from main. Switch to a feature, release, or hotfix branch first."
     exit 1
   fi

   if [ "$CURRENT_BRANCH" = "develop" ] && [ "$BASE_BRANCH" = "main" ]; then
     echo "Direct PR from develop to main is not allowed. Create release/v<version> first."
     exit 1
   fi

   if [ "$BASE_BRANCH" = "main" ]; then
     case "$CURRENT_BRANCH" in
       release/v*|hotfix/*)
         ;;
       *)
         echo "PR to main must come from release/v<version> or hotfix/* branch."
         exit 1
         ;;
     esac
   fi
   ```

3. **Push branch if needed**
   ```bash
   git push -u origin "$CURRENT_BRANCH"
   ```

4. **Build PR summary from commit range**
   ```bash
   BASE_BRANCH="${BASE_BRANCH:-main}"
   git fetch origin "$BASE_BRANCH"
   MERGE_BASE=$(git merge-base HEAD "origin/${BASE_BRANCH}")
   git log --oneline "${MERGE_BASE}"..HEAD
   git diff --stat "origin/${BASE_BRANCH}"...HEAD
   ```

5. **Create PR with structured body**
   ```bash
   gh pr create --base "$BASE_BRANCH" --title "<PR_TITLE>" --body "$(cat <<'EOF'
   ## Summary
   - <Key change 1>
   - <Key change 2>

   ## Verification
   - <Test or check 1>
   - <Test or check 2>

   ## Notes
   - <Optional release or migration notes>
   EOF
   )"
   ```

6. **Return result**
   - Print created PR URL
   - Print base branch, head branch, and title used

Keep the PR summary concise, user-facing, and aligned with recent commit intent.
