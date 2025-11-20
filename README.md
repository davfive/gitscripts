# gitscripts — repository-local helper ds

## Purpose
Minimal, cross-platform launcher for repository-local helper scripts and concise git aliases (git gs plus explicit per-runner aliases).

## Usage
```
# Normal usage (uses session-default runner)
git gs --help # shows list of available gitscripts
git gs <script-basename> [options/args]

# Run test scripts (also server as examples)
git gs .test
git gs .usertest

# Always available to run shell-specific runners (if your platform supports it)
git gs-cmd <script-basename>    # force cmd runner
git gs-sh <script-basename>     # force POSIX runner
git gs-pwsh <script-basename>   # force PowerShell runner
```

## Install (one-time)
1. Download and configure git
```
git clone git@github.com:davfive/gitscripts.git ~/gitscripts
git config --global include.path "$HOME/gitscripts/gitconfig/gitconfig"
```
2. (optional) Add GITSCRIPTS_SHELL for cmd/pwsh users\
   Set GITSCRIPTS_SHELL in the shell that invokes git:
   - cmd.exe: `set GITSCRIPTS_SHELL=cmd`
   - PowerShell:  `$env:GITSCRIPTS_SHELL = 'pwsh'`
   - posix shell: `export GITSCRIPTS_SHELL=sh`      # default (no need to set)
3. (optional) Make your favorite gitscripts top-level git commands\
   Update your ~/.gitconfig with
   ```
   ...
   [alias]
   add?=!gs add-select

## Troubleshooting
- Ensure your ~/.gitconfig include.path points gitspaces/gitconfig/gitconfig using an absolute path.
- If you see "Not a git repository", run the command from inside a Git repository.
- If a script is not found, confirm it exists under scripts/ or user-scripts-untracked/.
- If you see "Permission denied" on POSIX systems, your scripts likely aren't executable. Try
  ```
  cd /path/to/gitscripts
  find . -type f -name "*.sh" -print0                     # confirm list
  find . -type f -name "*.sh" -print0 | xargs -0 chmod +x # make executable

## Internals
- git aliases gs and gs-{cmd,ps1,sh} call gitscripts/runners/gitscript.{ext}
- gitscript.{ext} finds and runs requested script

### Layout
```
gitscripts/
├── gitconfig/
│   ├── gitconfig                          # for [include]:plan i ~/.gitconfig
│   └── gitconfig-setdefault-{cmd,pwsh,sh} # Set default
├── runners/
│   └── gitscripts.{sh,ps1,cmd}            # invoked by gs-* aliases to dispatch scripts
├── scripts/{cmd,ps1,sh}/                  # shell-specific gitscripts
└── userscripts-untracked/                 
    └── <userscript>{cmd,ps1,sh}           # add your own, gitignored scripts 
```

## Contributing
- sh → gitscripts/scripts/sh/*.sh
- ps1 → gitscripts/scripts/ps1/*.ps1
- cmd/bat → gitscripts/scripts/cmd/*.cmd or *.bat

See also: CONTRIBUTING.md and CONTRIBUTORS