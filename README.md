# ☁️ dotfilesync

**The minimalist's answer to dotfile management.**
Sync your shell configurations, editor settings, and scripts to a secret GitHub Gist—securely, instantly, and without the bloat.

Now with **Interactive Mode**, **Batch Syncing**, and **Cross-Platform Support** (macOS & Linux).

---

## 🎥 See it in action

### 1. Interactive Push (Default)
*Review changes file-by-file before uploading.*
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
    * **macOS:** Uses native **Keychain** (encrypted at rest).
    * **Linux:** Uses a locked-down file (`600` permissions) readable only by you.
* **🤝 Interactive or Automated:** Confirm every file operation manually, or use `-y` for instant batch processing.
* **🛠 Zero Dependencies:** Written in pure Bash. Configuration is a simple JSON file.

---

## 📦 Installation

You do not need to clone this repository. Install the binary directly to your path using `curl`.

'''bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/snvishna/dotfilesync/master/src/dfsync.sh -o ~/.local/bin/dfsync
chmod +x ~/.local/bin/dfsync
'''

> **Note:** Ensure `~/.local/bin` is in your `$PATH`.

### Prerequisites
* **curl** (Standard on most systems)
* **jq** (Required for JSON parsing)

'''bash
# macOS
brew install jq

# Linux (Ubuntu/Debian)
sudo apt-get install jq
'''

---

## 🚦 Quick Start Guide

### 1. Connect (Setup)
First, link your machine to GitHub. You need a **Personal Access Token (Classic)** with **`gist`** scope.
* [Generate Token Here](https://github.com/settings/tokens/new?scopes=gist&description=dotfilesync)

Run the setup wizard:
'''bash
dfsync setup
'''
*(Use `dfsync setup -y` to auto-accept default config paths).*

![](https://github.com/snvishna/dotfilesync/blob/master/resources/generate_personal_access_token.gif)

### 2. Track Files
Tell dfsync which files you want to manage.

'''bash
dfsync track ~/.zshrc
dfsync track ~/.config/starship.toml
'''

### 3. Sync (Push)
Upload your tracked files.

**Interactive Mode (Safest):**
'''bash
dfsync push
# Prompts: "Upload /Users/me/.zshrc? [y/N]"
'''

**Batch Mode (Fastest):**
'''bash
dfsync push -y
# Uploads everything immediately.
'''

### 4. Restore (Pull)
On a new machine, download your configs.

'''bash
dfsync pull
'''
*Prompts you before overwriting any local file, unless you use `-y`.*

---

## 🛠 CLI Reference

Flags can be placed anywhere (e.g., `dfsync -y push` or `dfsync push -y`).

| Command | Usage | Description |
| :--- | :--- | :--- |
| **setup** | `dfsync setup [-y]` | Initialize token and config. |
| **track** | `dfsync track <file>` | Add a file to the sync list. |
| **untrack** | `dfsync untrack <file>` | Remove a file from the sync list. |
| **push** | `dfsync push [-y] [-v]` | Upload files. Default is interactive. `-y` auto-confirms. |
| **pull** | `dfsync pull [-y] [-v]` | Download files. Default is interactive. `-y` auto-confirms. |
| **config** | `dfsync config token` | Update your GitHub Access Token. |
| **help** | `dfsync help` | Show usage guide. |

**Global Options:**
* `-y`, `--yes`: Non-interactive mode. Auto-answers "yes" to all prompts.
* `-v`, `--verbose`: Enable detailed debug logs (HTTP status, payload sizes, etc).

---

## ⚙️ Configuration

dfsync uses a single JSON file to track your state.
**Default Location:** `~/.config/dfsync.json`

### The Config Structure
'''json
{
  "gist_id": "8f3... (Auto-generated)",
  "files": [
    "~/.zshrc",
    "~/.config/wezterm/wezterm.lua",
    "~/.vimrc"
  ]
}
'''
> **Note:** Backward compatibility with older config schemas (`dotFilePaths`, `gistId`) is built-in.

---

## 🧠 Deep Dive

### Security Model
* **macOS:** Uses the native **Keychain** (Service: `dotfilesync`). The token is encrypted and only accessible when your Mac is unlocked.
* **Linux:** Stores the token in `~/.dfsync_token`. The script enforces `chmod 600` on this file, meaning no other user on the system can read it.

### The "Flattening" Strategy
GitHub Gists do not support folders. To support deep directory structures (like `~/.config/nvim/init.lua`), dotfilesync "flattens" filenames during upload using a double underscore delimiter (`__`).
* **Local:** `~/.config/nvim/init.lua`
* **Gist:** `_config__nvim__init.lua`

---

## ❓ Troubleshooting

**"jq not found"**
The script depends on `jq` to parse JSON. Install it via Homebrew (`brew install jq`) or apt (`sudo apt install jq`).

**"Token not found"**
If you upgraded from v1, run `dfsync config token <paste_token>` to migrate your token to the new secure storage.

**Script crashes or weird errors?**
Run with verbose mode to see exactly what's happening:
'''bash
dfsync push -v
'''

---

## 📜 License
MIT
