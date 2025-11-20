```markdown
# gitscripts — repository-local helpers

Purpose
- Minimal, cross-platform launcher for repository-local helper scripts and concise git aliases (git gs plus explicit per-runner aliases).

Principles
- Default to POSIX (no per-invocation detection).
- No runtime probing or expensive process spawns.
- Session-level override via a single env var: GITSCRIPTS_SHELL.
- Explicit runner aliases for deterministic CI: git gs-bash, git gs-pwsh, git gs-cmd.

Layout (repo)
- gitscripts/gitconfig/               — config fragments included from user config
  - gitconfig                         — central fragment users include
  - gitconfig-aliases-posix
  - gitconfig-aliases-pwsh
  - gitconfig-aliases-cmd
  - gitconfig-aliases-windows
  - gitconfig-aliases-windows-pwsh
- gitscripts/runners/                 — unified runner scripts (invoked by aliases)
  - gitscripts.sh | gitscripts.ps1 | gitscripts.cmd
- gitscripts/scripts/                 — tracked scripts (sh|ps1|cmd)
  - sh/, ps1/, cmd/
- gitscripts/user-scripts-untracked/  — per-user, gitignored scripts

Install (one-time)
1. Put the tree somewhere stable (e.g. `~/gitscripts` or `C:\Users\you\gitscripts`).
2. Add the central include to your global Git config:
   git config --global include.path "$HOME/gitscripts/gitconfig/gitconfig"

Behavior
- Default: `git gs` → POSIX runner (`git gs-bash`).
- Session override: set GITSCRIPTS_SHELL in the shell that invokes git:
  - bash/Git Bash: export GITSCRIPTS_SHELL=bash
  - PowerShell: $env:GITSCRIPTS_SHELL = 'pwsh'
  - cmd.exe: set GITSCRIPTS_SHELL=cmd
- Deterministic aliases:
  - git gs-bash, git gs-pwsh, git gs-cmd

Notes
- Runners look for scripts in:
  - tracked scripts: `gitscripts/scripts/sh`, `gitscripts/scripts/ps1`, `gitscripts/scripts/cmd`
  - tracked top-level `gitscripts/` files (if any)
  - user scripts: `gitscripts/user-scripts-untracked/`
- Add per-user scripts into `gitscripts/user-scripts-untracked/` — this directory is gitignored.

Troubleshooting
- "Not a git repository" — run inside a repository.
- PowerShell not found — set `GITSCRIPTS_SHELL` or call `git gs-bash`.

Contributing
- sh → gitscripts/scripts/sh/*.sh
- ps1 → gitscripts/scripts/ps1/*.ps1
- cmd/bat → gitscripts/scripts/cmd/*.cmd or *.bat
```