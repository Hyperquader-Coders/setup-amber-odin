# setup-amber-odin is a composite GitHub Action: action.yml is the whole
# artefact, so there is nothing to build. This exists for the suite's shared
# git targets; see amberlinux-apt/docs/PACKAGING.md for the contract.
BRANCH ?= main
REMOTE ?= origin
ROOT_COMMIT_MSG ?= Initial setup-amber-odin

.PHONY: deps check push force-push lint ci help check-no-agent-files

# targets: no test (action.yml is the whole artefact; `check` parses it and CI consumers exercise it)
# targets: no clean (nothing is built, so nothing is left to remove)

# The system packages the checks need, in one list: a development machine and the CI install the
# same, the CI with `make deps APT_FLAGS=-y`. A package missing on the runner is added here, not
# to a workflow.
DEPS := python3-yaml shellcheck shfmt
APT_FLAGS ?=

deps: ## install the system packages the checks need (sudo apt)
	sudo apt-get install $(APT_FLAGS) --no-install-recommends $(DEPS)

# The action is YAML; the only thing that can be wrong before a run is the syntax. The system's
# python3 is named by its path: python3-yaml is its package, and another python3 first on the
# PATH has no yaml module.
check: ## parse action.yml
	/usr/bin/python3 -c "import sys,yaml; yaml.safe_load(open('action.yml'))" && echo "action.yml OK"

push: ## push main to origin
	git push "$(REMOTE)" "$(BRANCH)"

# Rewrite the whole tree as one signed root commit and force-push it. The suite's
# repos carry no history until the first official release.
# Agent files are never published. Two ways they get in: already tracked, or
# present-and-unignored when `git add -A` below sweeps the whole tree. Both are
# checked here, because a squashed history shows no file being added: a stray
# path simply appears in the root commit as though it always belonged.
check-no-agent-files: ## refuse agent files that are tracked or not ignored
	@bad=$$(git ls-files | grep -E '(^|/)(\.mcp\.json|\.claude/|\.claude-amber/)' || true); \
	if [ -n "$$bad" ]; then \
		echo "agent files are tracked and must not be published:"; \
		printf '  %s\n' $$bad; \
		echo "fix: git rm -r --cached <path>, then add it to .gitignore"; \
		exit 2; \
	fi
	@for p in .mcp.json .claude .claude-amber; do \
		if [ -e "$$p" ] && ! git check-ignore -q "$$p"; then \
			echo "$$p exists and is not gitignored, so 'git add -A' would publish it"; \
			echo "fix: add $$p to .gitignore"; \
			exit 2; \
		fi; \
	done
	@echo "no agent files staged for publication"

force-push: check check-no-agent-files ## rewrite history as one signed root commit and force-push
	@test -z "$$(git status --porcelain)" || { \
		echo "Working tree is dirty. Commit, stash, or revert changes first."; \
		exit 2; \
	}
	@set -e; \
	orig_branch="$$(git branch --show-current)"; \
	test -n "$$orig_branch" || { echo "force-push: detached HEAD, check out a branch first"; exit 1; }; \
	tmp_branch="root-squash-$$(date +%s)"; \
	step="starting"; ok=0; \
	trap 'if [ "$$ok" != 1 ]; then echo "force-push FAILED while: $$step. Local history is intact on $$orig_branch; $(REMOTE)/$(BRANCH) was not replaced." >&2; git checkout -f "$$orig_branch" >/dev/null 2>&1 || true; git branch -D "$$tmp_branch" >/dev/null 2>&1 || true; exit 1; fi' EXIT; \
	step="creating the orphan branch"; git checkout --orphan "$$tmp_branch"; \
	step="staging the tree"; git add -A; \
	step="signing the root commit"; git commit -S -m "$(ROOT_COMMIT_MSG)"; \
	step="pushing to $(REMOTE)/$(BRANCH) (refused or unreachable)"; git push --force "$(REMOTE)" "$$tmp_branch:$(BRANCH)"; \
	step="verifying $(REMOTE)/$(BRANCH) equals the new commit"; \
	remote_sha="$$(git ls-remote "$(REMOTE)" "refs/heads/$(BRANCH)" | cut -f1)"; \
	test -n "$$remote_sha" && test "$$remote_sha" = "$$(git rev-parse HEAD)"; \
	ok=1; \
	git branch -M "$$tmp_branch" "$(BRANCH)"; \
	git branch --set-upstream-to="$(REMOTE)/$(BRANCH)" "$(BRANCH)" >/dev/null 2>&1 || { git fetch "$(REMOTE)" "$(BRANCH)" >/dev/null 2>&1 && git branch --set-upstream-to="$(REMOTE)/$(BRANCH)" "$(BRANCH)" >/dev/null; } || echo "warning: could not set upstream"; \
	echo "Rewrote $$orig_branch as signed root commit on $(REMOTE)/$(BRANCH)."

ci: check lint check-no-agent-files ## everything a push must pass

lint: ## shellcheck any shell scripts
	@if command -v shellcheck >/dev/null; then \
		git ls-files | while read -r f; do \
			case "$$f" in *.sh|*.bash) echo "$$f";; \
			*) head -1 "$$f" 2>/dev/null | grep -q '^#!.*sh' && echo "$$f";; esac; \
		done | xargs -r shellcheck --severity=warning && echo "shellcheck OK"; \
	else echo "shellcheck not installed, skipping (apt install shellcheck)"; fi

help: ## this list
	@awk 'BEGIN {FS = ":.*## "} \
	    /^##@ / {printf "\n%s\n", substr($$0, 5)} \
	    /^[a-z][a-z0-9-]*:.*## / {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Shell scripts are laid out by shfmt (sudo apt install shfmt), with tabs: every tracked file
# that is a shell script by its name or its first line. As in amber-house.
# apt's shfmt, the one a CI runner has, before any other on the PATH: versions differ in layout.
SHFMT ?= $(firstword $(wildcard /usr/bin/shfmt) shfmt)
SHFMT_FLAGS = -i 0
SH_SOURCES = git ls-files -z --cached --others --exclude-standard -- . | xargs -0 -r $(SHFMT) -f
.PHONY: fmt check-fmt fmt-sh check-fmt-sh
fmt-sh: ## lay the shell scripts out in place
	@$(SH_SOURCES) | xargs -r -d '\n' $(SHFMT) $(SHFMT_FLAGS) -w

check-fmt-sh: ## fail when a shell script is not as make fmt-sh leaves it
	@if ! command -v $(SHFMT) >/dev/null; then \
		if [ "$$GITHUB_ACTIONS" = true ]; then echo "shfmt is not installed on this runner; the workflow installs it"; exit 1; fi; \
		echo "shfmt not installed, skipping (sudo apt install shfmt)"; exit 0; \
	fi; \
	bad=$$($(SH_SOURCES) | xargs -r -d '\n' $(SHFMT) $(SHFMT_FLAGS) -l 2>&1) || true; \
	if [ -n "$$bad" ]; then echo "not formatted:"; echo "$$bad"; echo "fix: make fmt"; exit 1; fi; \
	echo "shfmt OK"

fmt: fmt-sh ## format the code in place: here, the shell scripts
check-fmt: check-fmt-sh ## fail on code that is not as make fmt leaves it
lint: check-fmt

# The one command after a fresh clone, the same in every repository: `deps` first (which CI calls
# on its own), then what this checkout needs.
.PHONY: init
init: deps ## everything a fresh clone needs: deps
