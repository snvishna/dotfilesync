Sync dotfiles with Gist
=======================

What is dotfilesync?
--------------------

dotfilesync is a bash script that syncs a list of local files that _you_ define, into a secret gist, that _you_ own.

dotfilesync is very easy to use as it stores your gist credentials into an encrypted Keychain, so you don't have to provide it each time.

You are not limited to syncing only dotfiles. Although this tool is meant for you to sync local dotfiles, it can also be used to sync any file that can be synced with gist.

This script is inspired by [this](https://hassansin.github.io/syncing-my-dotfiles-using-gist) post on how the author syncs zshrc to their gist.

Features
--------

### Config driven

dotfilesync uses a JSON config using a hardcoded path - `${HOME}/.dotfilesync/config.json` - to retrieve metadata needed to sync local files to gist.

A sample config shape can look like this:

```js
{
  "githubUser": "snvishna",
  "gistId": "8f1bd18cf47f9d3efb8dc0a88a4e57aa",
  "dotFilePaths": [
    "~/.dotfilesync/config.json",
    "~/.zshrc",
    "~/.bash_profile",
    "~/.ssh/config",
    "~/.scripts/a.sh",
    "~/.scripts/b.sh"
  ]
}
```

### Tools used as Keychain

This tool stores and manage your GitHub Personal Access Token within into an encrypted Keychain. This way your token is safe and encrypted by the Keychain, and you don't have to provide it each time you run the command to sync files.

For OS X based operating systems, the [OSX security](https://ss64.com/osx/security.html) command is used.

For Linux based operating systems, the [secret-tools](http://www.linuxfromscratch.org/blfs/view/svn/gnome/libsecret.html) command is used to interact with [GnomeKeyring](https://wiki.gnome.org/Projects/GnomeKeyring). For more info about keyrings used on Linux systems [read this article](https://rtfm.co.ua/en/what-is-linux-keyring-gnome-keyring-secret-service-and-d-bus/#Linux_keyring_vs_gnome-keyring).

### Sync multiple files into a single secret gist

All local files that are listed in the `config.json` file are synced into a single gist. As long as you have a valid `config.json` file in the `${HOME}/.dotfilesync` directory

### Auto-generate gist filenames

The file names in gist are automatically created. This script is opinionated on the file names being created. The characters "/" and "~" are replaced with periods (.). Duplicate consecutive periods in the name are also removed.

### Prompts before syncing each file

Every file listed in the `config.json`, whether being pushed to or pulled from gist, is synced only after a confirmation prompt. A sync is performed __only__ after you enter a "y" or a "yes" (case-insensitive). Any other input is ignored from sync.

### Creates a backup of the local file contents before overriding

During a fetch operation (syncing local files from gist), a sync is performed, only after creating a backup of the local file. The backup file name is auto-generated based on the current timestamp.

Prerequisites
-------------

This script uses [jq](https://stedolan.github.io/jq/download/) to parse the `config.json` on the local filesystem.

## OS X
You can run the following command on OS X, if you have [Homebrew](https://brew.sh/) installed:

       brew install jq

## Linux
You can install the required packages on a Debian based distro running the following command:

       apt-get install jq libsecret-tools

Installation
------------

Ensure the [prerequisite](#prerequisites) tools are setup. Installing dotfilesync is easy and a one-time effort:

1. Start a Zsh shell:

       zsh

2. Fetch the script locally:

  * With curl:

        mkdir -p ${HOME}/.dotfilesync \
        && curl -fsSL https://raw.githubusercontent.com/snvishna/dotfilesync/master/src/dfsync.sh \
          >| ${HOME}/.dotfilesync/dfsync.sh

  * With wget:

        mkdir -p ${HOME}/.dotfilesync \
        && wget -nv -O - https://raw.githubusercontent.com/snvishna/dotfilesync/master/src/dfsync.sh \
          >| ${HOME}/.dotfilesync/dfsync.sh

3. Add an entry in zshrc:

    You'll find the zshrc file in your $HOME directory. Open it with your favorite text editor and add the following alias in there:

        alias dfsync='bash ${HOME}/.dotfilesync/dfsync.sh'
    
    You can now use the `dfsync` command after you restart the terminal, or source your zsh config.

4. Create Person Access Token on GitHub:

    You can create a new [person access tokens page](https://github.com/settings/tokens/new) for running the script on the command line. Follow [these instructions](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) on how to create one. Make sure you have the __gist__ scope selected to grant permission on this token.

    Once you generate the personal access token, either copy it on your clipboard, or save it somewhere, since the script will need this to store within the Keychain, before syncing your files in gist.
    
    ![](./resources/generate_personal_access_token.gif)

5. Run setup:

    Run the command `dfsync setup` from your terminal. It prompts for your GitHub username and the personal access token. Refer to the [Commands](#commands) section for more details on this command.

    ![](./resources/dfsync-setup.gif)

6. You're done! Enjoy dotfilesync!

Usage
-----

* Update the `config.json` file with a list of local file paths that you'd like to sync with gist. You can now run `dfsync push` to upload these files in the gist.

    ![](./resources/dfsync-push.gif)

Commands
--------

* __dfsync setup__

  It is run only __once__ as part of the installation instructions. This command does the following:

  * Prompts for your GitHub username and the personal access token. It then stores this information securely in the Keychain.

  * Creates a new secret gist in your account with the description - "Generated by dotfilesync utility".

  * It then creates a new `config.json` file, and auto-populates your Github username and the gistId fields.

  * Saves this file in the `${HOME}/.dotfilesync` directory.

  * It also syncs this config file to this gist.

  > It is a good practice to leave the `config.json` file to sync with your gist, so you can recover or download these files with the `dfsync pull` command when you need them.

* __dfsync push__

  Use this command to push all local file contents into the secret gist defined in the `config.json` file. This command will prompt you before syncing each file. You can type "Y" or "y" for the file contents to be pushed. You can type any other character, or just hit enter to skip syncing this file. This command will work only after the `dfsync password save` is run once, so the personal access token is saved.

* __dfsync pull__

  Use this command to fetch all local file contents into the secret gist defined in the `config.json` file. This command will prompt you before syncing each file. You can type "Y" or "y" for the file contents to be fetched. You can type any other character, or just hit enter to skip syncing this file.

  To be safe and not corrupt your local file contents, the command will initiate a backup of the local files (using a timestamp), and only then overwrites the contents of the file. Use can use these backup files to recover to the previous state.

  This command will work only after the `dfsync password save` is run once, so the personal access token is saved.

* __dfsync cleanup__

  This command will do the following:

  * Delete the saved GitHub gist credentials from the Keychain.
  * Delete `config.json` file from the `${HOME}/.dotfilesync` directory.
  * It does not automatically delete the saved gist from your GitHub account. Rather, it prints out the HTTP link to your gist, so you can choose to delete it.
  * It provides a link to the uninstall instructions in this README, so you can run the commands to delete the script and update the zsh config.

Uninstall
---------

You can cleanup the script and all resources created by it, using the following instructions:

* __Run__ `dfsync cleanup`

  You can run the command to 1) Delete the saved GitHub gist credentials from the Keychain 2) Delete `config.json` file from the `${HOME}/.dotfilesync` directory.

* __Delete the gist__

  To be safe, the clean up command __does not automatically__ delete your gist from your account. You can choose to do this manually. The URL to your gist will be printed on the terminal when you run `dfsync cleanup`.

* __Delete the local file__

  You can now delete the dotfilesync directory from your machine. Run the following command: `rm -rf ${HOME}/.dotfilesync`

* __Remove alias from zsh config__

  You should now remove the `dfsync` alias from the zsh config. Otherwise this command will fail on the missing file path.
