# 🔄 dfsync (Dotfile Sync)

**dfsync** is a lightweight, zero-dependency, enterprise-grade utility to synchronize your dotfiles to a GitHub Gist. 

Designed for **power users** who practice "Infrastructure as Code," it adheres strictly to **XDG standards**, supports **atomic operations**, and features a **dynamic configuration resolution ladder**.

## 🌟 Features

* **🔒 Secure:** Uses system Keychain (macOS `security` / Linux `libsecret`)—never stores tokens in plain text.
* **📍 Location Agnostic:** Run the binary from anywhere. It automatically resolves config via a priority ladder.
* **🛡️ Atomic & Safe:** Performs "dry runs" by default. Backs up local files before overwriting.
* **☁️ Gist-Based:** Free, versioned, and accessible cloud storage.
* **📦 XDG Compliant:** Keeps your home directory clean (`~/.config`, `~/.local`).

---

## 🛠 Prerequisites

Ensure you have the necessary tools installed. `dfsync` is lightweight but relies on these core utilities:

1.  **Zsh or Bash** (Standard on most systems)
2.  **cURL** (For network requests)
3.  **jq** (For JSON processing)

```bash
# macOS
brew install jq curl

# Ubuntu/Debian
sudo apt-get install jq curl libsecret-tools
```

---

## 🚀 Installation

We recommend installing `dfsync` as a native user binary. This removes the need for messy aliases in your `.zshrc`.

```bash
# 1. Create the binary folder
mkdir -p ~/.local/bin

# 2. Install the script
cp src/dfsync.sh ~/.local/bin/dfsync
chmod +x ~/.local/bin/dfsync

# 3. Ensure path availability (Add to .zshrc if missing)
export PATH="$HOME/.local/bin:$PATH"
```

*You can now run `dfsync` from any terminal window.*

---

## 🔐 Authentication

`dfsync` needs a Personal Access Token (PAT) to talk to GitHub.

### 1. Generate Token
1.  Go to [GitHub Tokens (Classic)](https://github.com/settings/tokens/new).
2.  Generate a new token with the **`gist`** scope.
3.  Copy the token.

![](./resources/generate_personal_access_token.gif)

### 2. Add to Keychain
Store the token securely in your OS keychain using the service name **`dotfiles_sync`**.

**macOS:**
```bash
security add-generic-password -a "YOUR_GITHUB_USER" -s "dotfiles_sync" -w "YOUR_TOKEN_HERE"
```

**Linux:**
```bash
printf "YOUR_TOKEN_HERE" | secret-tool store --label "dotfiles_sync" user "YOUR_GITHUB_USER" usage "dotfiles_sync"
```

---

## ⚙️ Configuration

### 1. The Config File
Create your config file at the standard XDG location: `~/.config/dfsync.json`.

```json
{
  "githubUser": "snvishna",
  "gistId": "YOUR_SECRET_GIST_ID",
  "dotFilePaths": [
    "~/.config/.zshrc",
    "~/.config/starship.toml",
    "~/.config/manifests/Brewfile",
    "~/.local/bin/my-script"
  ]
}
```

### 2. Register Config (The Resolution Ladder)
Tell `dfsync` where to look. This creates a persistent pointer so you don't need environment variables later.

```bash
dfsync config set ~/.config/dfsync.json
```

---

## 📖 Usage

### Push to Cloud
Uploads your local files to the Gist.

```bash
# Interactive Mode (Safest)
dfsync push

# Batch Mode (For scripts/backup routines)
dfsync push -y
```

![](./resources/dfsync-push.gif)

### Pull from Cloud
Downloads files from the Gist to your local machine.

```bash
# Interactive Mode
dfsync pull

# Force/Batch Mode
dfsync pull -y
```

### Check Status
See which configuration file is currently active.

```bash
dfsync config show
```

---

## 🤖 Automation & "Zen" Architecture

For a clean, maintenance-free setup, we recommend the **Manifest Architecture**.

1.  **Separate Configs from Artifacts:** Keep your `.config` root clean.
2.  **Automate Dumps:** Use a wrapper script to dump `Brewfile`, VS Code extensions, etc., into a `manifests/` folder before syncing.

**Recommended Structure:**
```text
~/.config/
├── dfsync.json                 # Main Config
└── manifests/                  # Auto-generated dumps
    ├── Brewfile
    ├── vscode_extensions.txt
    ├── npm_globals.txt
    └── last_backup.log
```

Run your backup command (e.g., `backup`) to regenerate manifests and trigger `dfsync push -y` automatically.
