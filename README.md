Sync dotfiles with Gist
=======================

What is dotfilesync?
--------------------

dotfilesync is a bash script that syncs a list of local files that _you_ define, into a secret gist, that _you_ own.

dotfilesync is very easy to use as it stores your gist credentials into Mac OS X Keychain, so you don't have to provide it each time.

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

### Uses OS X Keychain

The tool uses [OSX security](https://ss64.com/osx/security.html) command to manage your GitHub Personal Access Token within your Keychain. This way your token is safe and encrypted by the Keychain, and you don't have to provide it each time you run the command to sync files.

### Sync multiple files into a single secret gist

All local files that are listed in the `config.json` file are synced into a single gist. As long as you have a valid `config.json` file in the `${HOME}/.dotfilesync` directory

### Auto-generate gist filenames

The file names in gist are automatically created. This script is opinionated on the file names being created. The characters "/" and "~" are replaced with periods (.). Duplicate consecutive periods are also removed.

### Prompts before syncing each file

Every file listed in the `config.json`, whether being pushed to or pulled from gist, is synced only after a confirmation prompt. A sync is performed __only__ you enter a "y" or a "yes" (case-insensitive). Any other input is ignored from sync.

### Creates a backup of the local file contents before overriding

During a fetch operation (syncing local files from gist), a sync is performed, only after creating a backup of the local file. The backup file name is auto-generated based on the current timestamp.

Installation
------------

Installing dotfilesync is easy and a one-time effort:

1. Start a Zsh shell:

       zsh

2. Fetch the script locally:

  * With curl:

        mkdir -p ${HOME}/.dotfilesync \
        && curl -fsSL https://raw.githubusercontent.com/snvishna/dotfilesync/master/src/dfsync_osx.sh \
          >| ${HOME}/.dotfilesync/dfsync.sh

  * With wget:

        mkdir -p ${HOME}/.dotfilesync \
        && wget -nv -O - https://raw.githubusercontent.com/snvishna/dotfilesync/master/src/dfsync_osx.sh \
          >| ${HOME}/.dotfilesync/dfsync.sh

3. Fetch config.json template locally:

  * With curl:

        curl -fsSL https://raw.githubusercontent.com/snvishna/dotfilesync/master/config_template.json \
          >| ${HOME}/.dotfilesync/config.json

  * With wget:

        wget -nv -O - https://raw.githubusercontent.com/snvishna/dotfilesync/master/config_template.json \
          >| ${HOME}/.dotfilesync/config.json

4. Create a new gist:

    You can follow [these instructions](https://help.github.com/en/github/writing-on-github/creating-gists) on how to create a new secret gist online.
    
    ![](./resources/create_secret_gist.gif)

5. Create Person Access Token on GitHub:

    You can create a new [person access tokens page](https://github.com/settings/tokens/new) for running the script on the command line. Follow [these instructions](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) on how to create one. Make sure you have the __gist__ scope selected to grant permission on this token.

    Once you generate the personal access token, either copy it on your clipboard, or save it somewhere, since the script will need this to store within the OS X Keychain, before syncing your files in gist.
    
    ![](./resources/generate_personal_access_token.gif)

6. Update the config:

    Once you have a list of local files that you'd like to sync with your private gist, you'll need to list them in the `config.json` file.

        vi ${HOME}/.dotfilesync/config.json
  
    Enter your GitHub username, the Personal Access Token created above, and a list of local file paths that you would like to sync. You can refer to the sample config shape in the _Features_ section of this doc for more information on how to list this metadata.

7. Add an entry in zshrc:

    You'll find the zshrc file in your $HOME directory. Open it with your favorite text editor and add the following alias in there:

        alias dfsync='bash ${HOME}/.dotfilesync/dfsync.sh'


8. You're done! Enjoy dotfilesync!

Usage
-----

You can run the following commands:

* __dfsync password save__

  This command is used only once to save your person access token in your OS X Keychain. You won't have to do this again, once added. The username associated with this access token is defined in the `config.json` file.

* __dfsync push__

  Use this command to push all local file contents into the secret gist defined in the `config.json` file. This command will prompt you before syncing each file. You can type "Y" or "y" for the file contents to be pushed. You can type any other character, or just hit enter to skip syncing this file. This command will work only after the `dfsync password save` is run once, so the personal access token is saved.

* __dfsync pull__

  Use this command to fetch all local file contents into the secret gist defined in the `config.json` file. This command will prompt you before syncing each file. You can type "Y" or "y" for the file contents to be fetched. You can type any other character, or just hit enter to skip syncing this file.

  To be safe and not corrupt your local file contents, the command will initiate a backup of the local files (using a timestamp), and only then overwrites the contents of the file. Use can use these backup files to recover to the previous state.

  This command will work only after the `dfsync password save` is run once, so the personal access token is saved.

* __dfsync password delete__

  This command will delete your personal access token from the OS X keychain that is associated with the username defined in the `config.json` file.
