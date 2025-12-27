#  dotfilesync (v3.0)

[![Bash Shell](https://img.shields.io/badge/shell-bash-4eaa25.svg)](https://www.gnu.org/software/bash/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**dotfilesync** is a high-performance, security-focused Bash utility designed to synchronize your local configuration files into a single, private GitHub Gist. 

Unlike traditional dotfile managers that require complex Git repo management, `dfsync` treats your Gist as an atomic key-value store. It is lightweight, configuration-driven, and utilizes your system's native encrypted Keychain for credential storage.

---

## 🚀 Key Features (Refactored v3.0)

### ⚡️ Atomic Batch Updates
Version 3.0 introduces a massive performance leap. Instead of N-number of HTTP requests for N-files, `dfsync` now:
1. Aggregates all selected local files into a single JSON object.
2. Performs **ONE** single `PATCH` request to the GitHub API.
3. Ensures atomicity: either all files update, or none do.

### 🤖 Automation Friendly (`-y` flag)
Full support for non-interactive environments (CRON jobs, LaunchAgents). Use the `-y` or `--yes` flag to bypass all confirmation prompts.

### 🔐 Secure Keychain Integration
Your GitHub Personal Access Token (PAT) is never stored in plain text.
* **macOS:** Uses the native **macOS Keychain** (`security` utility).
* **Linux:** Uses **Gnome Keyring** (`secret-tool`).

---

## 🛠 Prerequisites

Requires `jq` for JSON processing and `curl` for API interaction.

### macOS
```bash
brew install jq
```

### Linux (Debian/Ubuntu)
```bash
sudo apt-get install jq libsecret-tools
```

---

## 📦 Installation

1. **Fetch the script:**
   ```bash
   mkdir -p ${HOME}/.dotfilesync \
   && curl -fsSL https://raw.githubusercontent.com/snvishna/dotfilesync/master/src/dfsync.sh \
     >| ${HOME}/.dotfilesync/dfsync.sh \
   && chmod +x ${HOME}/.dotfilesync/dfsync.sh
   ```

2. **Add the alias to your shell config:**
   ```bash
   alias dfsync='bash ${HOME}/.dotfilesync/dfsync.sh'
   ```

3. **Run Setup:**
   ```bash
   dfsync setup
   ```
   
   ![](./resources/dfsync-setup.gif)

---

## 📖 Usage & Commands

### Pushing to Gist
```bash
# Interactive Mode (Prompt for each file, then batch upload)
dfsync push

# Automated Mode (Bypass prompts, sync everything instantly)
dfsync push -y
```

### Pulling from Gist
```bash
# Interactive Mode (Prompt before overwriting local files)
dfsync pull

# Automated Mode (Sync all files, creating local backups automatically)
dfsync pull -y
```

### Command Reference

| Command | Flag | Description |
| :--- | :--- | :--- |
| `setup` | N/A | Initial config, keychain storage, and Gist creation. |
| `push` | `-y`, `--yes` | **Local → Gist.** Batch uploads local changes. |
| `pull` | `-y`, `--yes` | **Gist → Local.** Syncs remote changes and creates backups. |
| `cleanup` | N/A | Safely removes Keychain credentials and local config. |

---

## 🔍 Technical Implementation

### Filename Mapping
`dfsync` maps nested local paths to a flat Gist structure by replacing `/` and `~` with periods.
* `~/.zshrc` → `.zshrc`
* `~/.config/wezterm/wezterm.lua` → `.config.wezterm.wezterm.lua`

### Resilience
The script uses `set -o pipefail` and `set -o errexit`. If the GitHub API returns an error during the batch upload, the script terminates immediately to protect the integrity of your local configuration.

### Stdin Handling
To support interactive prompts inside loops, `dfsync` explicitly reads from `/dev/tty`. This ensures that `read` commands don't consume the file-list stream, allowing for stable `y/n` confirmation.

---

## 🧹 Uninstallation

1. **Run Cleanup:** `dfsync cleanup`
2. **Delete Gist:** Delete the Gist manually via the URL provided by the cleanup command.
3. **Remove Files:** `rm -rf ${HOME}/.dotfilesync`

---

*Inspired by [Hassan Sani's post](https://hassansin.github.io/syncing-my-dotfiles-using-gist).*
