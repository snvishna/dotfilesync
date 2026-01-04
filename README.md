# ☁️ dotfilesync

**The minimalist's answer to dotfile management.**
Sync your shell configurations, editor settings, and scripts to a secret GitHub Gist—securely, instantly, and without the bloat.

Now with cross-platform support for **macOS** and **Linux**.

---

## 🎥 See it in action

### 1. Syncing (Push)
*Instant backup of your local settings to the cloud.*
![](./resources/dfsync-push.gif)

### 2. First Time Setup
*Linking your machine to GitHub securely.*
![](https://github.com/snvishna/dotfilesync/blob/master/resources/dfsync-setup.gif?raw=true)

---

## ⚡️ Why dotfilesync?

Most dotfile managers are over-engineered. They force you to move your files, create symlink farms, manage complex Git submodules, or trust proprietary cloud services.

**dotfilesync is different:**
* **📍 Non-Destructive:** Your files stay exactly where they are. No symlinks. No moving files.
* **🔒 Secure by Design:**
    * **macOS:** Uses the native **Keychain** to store tokens.
    * **Linux:** Uses a secured file with strict read-only permissions.
* **🚀 Zero Friction:** No `git add`, `git commit`, `git push`. Just `dfsync push`.
* **🛠 Zero Dependencies:** Written in pure Bash. Configuration is a simple JSON file.

---

## 📦 Installation

You do not need to clone this repository. Install the binary directly to your path using `curl`.

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/snvishna/dotfilesync/master/src/dfsync.sh -o ~/.local/bin/dfsync
chmod +x ~/.local/bin/dfsync
```

> **Note:** Ensure `~/.local/bin` is in your `$PATH`.

### Prerequisites
* **curl** (Standard on most systems)
* **jq** (Required for JSON parsing)

```bash
# macOS
brew install jq

# Linux (Ubuntu/Debian)
sudo apt-get install jq
```

---

## 🚦 Quick Start Guide

Follow these four steps to back up your environment in under 2 minutes.

### 1. Connect (Setup)
First, link your machine to GitHub securely. You will need a **GitHub Personal Access Token (Classic)** with **`gist`** scope.

* [Generate Token Here](https://github.com/settings/tokens/new?scopes=gist&description=dotfilesync)

Run the setup wizard:
```bash
dfsync setup
```
*Tip: Use `dfsync setup -y` to automatically accept default config paths.*

![](https://github.com/snvishna/dotfilesync/blob/master/resources/generate_personal_access_token.gif)

### 2. Track Files
Tell dfsync which files you want to manage. You can track individual files from anywhere in your home directory.

```bash
# Track your Zsh config
dfsync track ~/.zshrc

# Track your Starship prompt config
dfsync track ~/.config/starship.toml
```

### 3. Sync (Push)
Upload your tracked files to the cloud. If you don't have a Gist yet, this command creates one for you automatically.

```bash
dfsync push
```

### 4. Restore (Pull)
On a new machine (or if you accidentally delete a config), download the latest version from your Gist.

```bash
dfsync pull
```
*⚠️ Warning: This overwrites your local files with the version from the Gist.*

---

## ⚙️ Configuration

dfsync uses a single JSON file to track your state.
**Default Location:** `~/.config/dfsync.json`

### The Config Structure
```json
{
  "gist_id": "8f3... (Auto-generated)",
  "files": [
    "~/.zshrc",
    "~/.config/wezterm/wezterm.lua",
    "~/.vimrc"
  ]
}
```
You can edit this file manually if you prefer, or use the CLI commands (`track`/`untrack`) to manage it.

> **Legacy Support:** If you are upgrading from an older version, your existing config (`dotFilePaths` / `gistId`) works automatically.

---

## 🛠 CLI Reference

| Command | Usage | Description |
| :--- | :--- | :--- |
| **setup** | `dfsync setup [-y]` | Initialize token and config. `-y` accepts defaults. |
| **track** | `dfsync track <file>` | Add a file to the sync list. |
| **untrack** | `dfsync untrack <file>` | Remove a file from the sync list. |
| **push** | `dfsync push [-v]` | Upload tracked files. `-v` shows detailed logs. |
| **pull** | `dfsync pull [-v]` | Download files from Gist. `-v` shows detailed logs. |
| **config token** | `dfsync config token` | Update your GitHub Access Token. |
| **config path** | `dfsync config path` | Change the location of the `dfsync.json` file. |
| **help** | `dfsync help` | Show usage guide. |

---

## 🧠 Deep Dive

### Security Model
Unlike tools that store API tokens in plain text (`~/.npmrc`, `~/.git-credentials`), dotfilesync prioritizes security.

* **macOS:** Uses the native **Keychain** (Service: `dotfilesync`). The token is encrypted and only accessible when your Mac is unlocked.
* **Linux:** Stores the token in `~/.dfsync_token` with strict `600` permissions (read/write only by the owner).

### The "Flattening" Strategy
GitHub Gists do not support folders—they are flat lists of files. To support deep directory structures (like `~/.config/nvim/init.lua`), dotfilesync "flattens" filenames during upload using a double underscore delimiter (`__`).

* **Local:** `~/.config/nvim/init.lua`
* **Gist:** `_config__nvim__init.lua`

When you `pull`, the script intelligently reverses this transformation to restore files to their correct folders.

---

## ❓ Troubleshooting

**"jq not found"**
The script depends on `jq` to parse JSON. Install it via Homebrew (`brew install jq`) or apt (`sudo apt install jq`).

**"Token not found"**
If you upgraded from v1, run `dfsync config token <paste_token>` to migrate your token to the new secure storage.

**"404 Not Found" during Push**
Ensure your GitHub Token has the **`gist`** scope enabled. If the token is invalid, generate a new one and update it using `dfsync config token`.

---

## 📜 License
MIT
