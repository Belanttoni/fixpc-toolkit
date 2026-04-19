# GitHub Setup Guide for FixPC Toolkit

## 1. Recommended repository name

Use one of these:

- `fixpc-toolkit`
- `pc-diagnostic-repair-tool`
- `fixpc-diagnostic-suite`

Recommended: **`fixpc-toolkit`**

## 2. Recommended repository visibility

Start with a **private** repository while the project is being reorganized.
You can switch to public later if you want to use it as a portfolio project.

## 3. GitHub configuration checklist

Create the repository with:

- Repository name: `fixpc-toolkit`
- Visibility: Private
- Add a README: Yes
- Add `.gitignore`: `VisualStudio` or leave empty and replace later
- License: Optional for now

## 4. Local machine prerequisites

Install these tools:

- Git for Windows
- GitHub Desktop or GitHub CLI (optional, but helpful)
- PowerShell 5.1 or later

## 5. Recommended authentication method

Use **Git Credential Manager** or **GitHub CLI** for HTTPS authentication instead of storing a token manually. GitHub Docs recommends both approaches, and also notes that SSH is available if you prefer key-based authentication. citeturn275846search2turn275846search9turn275846search10

### Option A: Git Credential Manager over HTTPS

This is the easiest option on Windows.

1. Install Git for Windows.
2. Open PowerShell.
3. Run:

```powershell
git config --global credential.helper manager
```

4. On first push, Git will open a sign-in flow.
5. Complete GitHub authentication in the browser.

### Option B: GitHub CLI

1. Install GitHub CLI.
2. Run:

```powershell
gh auth login
```

3. Choose:
   - GitHub.com
   - HTTPS
   - Authenticate in browser

### Option C: SSH

Use this if you already work comfortably with SSH keys.
GitHub supports SSH URLs for remotes after you generate a keypair and add the public key to your GitHub account. citeturn275846search9

## 6. Create the repository on GitHub

You can create a new repository from the GitHub web UI using **New repository**. GitHub also supports creating a repository with GitHub CLI. citeturn275846search0turn275846search12

Recommended settings:

- Owner: `Belanttoni`
- Repository: `fixpc-toolkit`
- Visibility: Private
- Initialize with README: Yes

## 7. Connect your local project to GitHub

If you already have a local project folder:

```powershell
cd C:\Path\To\FixPC-Toolkit
git init
git branch -M main
git remote add origin https://github.com/Belanttoni/fixpc-toolkit.git
```

GitHub documents `git remote add` as the standard way to connect a local repository to a remote repository. citeturn275846search1

## 8. First commit and first push

```powershell
git add .
git commit -m "Initial project structure and documentation"
git push -u origin main
```

## 9. Recommended branch strategy

Use a simple workflow:

- `main` → stable branch
- `dev` → active development
- `feature/*` → isolated work items

Examples:

- `feature/system-module`
- `feature/network-module`
- `feature/report-engine`
- `feature/ui-winforms-refactor`
- `feature/ui-wpf-v2`

Create `dev` after the first push:

```powershell
git checkout -b dev
git push -u origin dev
```

## 10. Recommended repository settings

### Branch protection

Protect `main` after the repository is working.
GitHub branch protection rules can block force pushes, prevent deletion, and require pull requests or checks before merging. citeturn275846search3turn275846search11

Recommended rule for `main`:

- Require pull request before merging
- Block force pushes
- Block deletion
- Optionally require linear history

### Issues

Enable Issues to track the roadmap.

### Discussions

Optional. Useful if you later open the project publicly.

### Releases

Use Releases to publish versions such as:

- `v0.1.0`
- `v0.2.0`
- `v1.0.0-winforms`
- `v2.0.0-wpf`

## 11. Recommended labels for issues

Create these labels:

- `architecture`
- `core`
- `system`
- `network`
- `hardware`
- `reports`
- `ui-winforms`
- `ui-wpf`
- `bug`
- `enhancement`
- `documentation`
- `good first task`
- `blocked`

## 12. Recommended milestones

Use milestones to map project phases:

- Phase 1 - Repository and project foundation
- Phase 2 - WinForms modular architecture
- Phase 3 - System module stabilization
- Phase 4 - Network module
- Phase 5 - Hardware module
- Phase 6 - Reporting and packaging
- Phase 7 - WPF V2 UI migration

## 13. Recommended project board columns

Use a GitHub Project with these columns:

- Backlog
- Ready
- In Progress
- Review
- Done

## 14. Suggested `.gitignore`

```gitignore
# Build output
bin/
obj/
out/
release/

# Logs
*.log

# Temporary files
*.tmp
*.bak
*.old
*.cache

# Reports generated locally
Reports/Output/
Exports/

# Packaged tools and downloaded binaries
Assets/Tools/Downloads/

# User-specific files
.vscode/
.idea/
*.user
*.suo

# PowerShell history and transcripts
*.ps1xml
*.clixml
*.txt

# OS files
Thumbs.db
.DS_Store
```

## 15. Recommended first GitHub issues

1. Create repository structure
2. Split current script into Core, Modules, Reports, and UI
3. Define module return contract
4. Build System module workflow
5. Add JSON report export
6. Add Network module foundation
7. Add Hardware module foundation
8. Design WinForms V1 UI improvements
9. Prepare WPF V2 migration plan
10. Add release/versioning process

## 16. Daily workflow recommendation

For each task:

```powershell
git checkout dev
git pull
git checkout -b feature/your-task-name
# work
git add .
git commit -m "Add module contract for analysis and repair workflow"
git push -u origin feature/your-task-name
```

Then open a Pull Request into `dev`.
Merge `dev` into `main` only for stable checkpoints.

## 17. Minimal launch plan

1. Create the repo on GitHub
2. Configure authentication with GCM or GitHub CLI
3. Push the documentation first
4. Create `dev`
5. Create milestones and labels
6. Open the first set of issues
7. Start refactoring the current WinForms version
