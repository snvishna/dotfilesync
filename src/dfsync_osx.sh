#!/bin/bash

################################
# Sync dotfiles to Github Gist #
################################

DOTFILESYNC_CONFIG=~/.dotfilesync/config.json
HOME_DIR=~

backup() {
  cp -n $1{,.bak."$(date +%Y%m%d-%H%M%S)"}
}

getGistFileName() {
  echo $1 | sed -e "s:~:.:g; s:/:.:g" | awk '{gsub(/[.]+/,".")}1'
}

addKeychainPassword() {
  security add-generic-password -a $1 -s $2 -w
}

getKeychainPassword() {
  security find-generic-password -wga $1 -s $2
}

deleteKeychainPassword() {
  security delete-generic-password -a $1 -s $2
}

gist() {
  if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" || -z "$5" ]];
  then
      echo 'usage: gist put|get|delete gistid gistfile githubuser githubpassword';
  else
    if [ $1 = "put" ]; then
      jq -R -s 'split("
") | join("
") | {files: {"'"$3"'": {content: .}}}' | \
      curl -s -u $4:$5 -XPATCH "https://api.github.com/gists/$2" -d @- | \
      jq -r -e  'if .description then "updated: " + .description else . end'
    elif [ $1 = "get" ]; then
      curl -s -u $4:$5 "https://api.github.com/gists/$2" | jq -r -e '.files."'"$3"'".content'
    elif [ $1 = "delete" ]; then
      jq -n '{files: {"'"$4"'": {content: ""}}}' | \
      curl -s -u $4:$5 -XPATCH "https://api.github.com/gists/$2" -d @- |\
      jq -r -e  'if .description then "updated: " + .description else . end'
    fi
  fi
}

pull() {
  eval homedir=$HOME_DIR
  local config=$(cat $DOTFILESYNC_CONFIG)
  local dotfiles_gistid=$(echo $config | jq -r ".gistId")
  local github_user=$(echo $config | jq -r ".githubUser")
  local github_password=$(getKeychainPassword $github_user dotfiles_sync)

  for row in $(echo $config | jq -r '.dotFilePaths | .[]'); do
    # getDotFile $row $github_password
    local fileName=$(getGistFileName $row)
    read -r -p "Updating $row from $fileName?" get_confirm_response
    if [[ "$get_confirm_response" =~ ^([yY][eE][sS]|[yY])$ ]];
    then
      local absolutePath=$(echo $row | sed -e "s:~/:$homedir/:g")

      # Create backup before replacing
      echo "Creating a local back of $absolutePath..."
      backup $absolutePath

      # Fetch the contents
      gist get $dotfiles_gistid $fileName $github_user $github_password > $absolutePath
    fi
  done
}

push() {
  eval homedir=$HOME_DIR
  local config=$(cat "$DOTFILESYNC_CONFIG")
  local dotfiles_gistid=$(echo $config | jq -r ".gistId")
  local github_user=$(echo $config | jq -r ".githubUser")
  local github_password=$(getKeychainPassword $github_user dotfiles_sync)

  # echo $config | jq -r ".dotFilePaths | .[]" | xargs -L1 -I {} bash -i -c "putDotFile {}"
  for row in $(echo $config | jq -r '.dotFilePaths | .[]'); do
    local fileName=$(getGistFileName $row)
    read -r -p "Pushing $row to $fileName?" put_confirm_response
    if [[ "$put_confirm_response" =~ ^([yY][eE][sS]|[yY])$ ]];
    then
    # Workaround for "No such file or directory" error when using ~ in the path: https://stackoverflow.com/a/3963747/640607
    local absolutePath=$(echo $row | sed -e "s:~/:$homedir/:g")
    cat $absolutePath | gist put $dotfiles_gistid $fileName $github_user $github_password
    fi
  done
}

saveCredentialsInKeychain() {
  local config=$(cat "$DOTFILESYNC_CONFIG")
  local github_user=$(echo $config | jq -r ".githubUser")
  echo "Securely saving GitHub credentials for $github_user."

  addKeychainPassword $github_user "dotfiles_sync"
}

deleteCredentialsInKeychain() {
  local config=$(cat "$DOTFILESYNC_CONFIG")
  local github_user=$(echo $config | jq -r ".githubUser")
  echo "Deleting saved GitHub credentials for $github_user."

  deleteKeychainPassword $github_user "dotfiles_sync"
}

if [[ ! -f "$DOTFILESYNC_CONFIG" ]];
then
    echo "Config file missing. Please follow the setup instructions from here: https://github.com/snvishna/dotfilesync"
    exit 1
fi

case "$1" in

  [pP][aA][sS][sS][wW][oO][rR][dD])
    if [[ "$2" =~ ^([sS][aA][vV][eE])$ ]];
    then
      saveCredentialsInKeychain
    elif [[ "$2" =~ ^([dD][eE][lL][eE][tT][eE])$ ]];
    then
      deleteCredentialsInKeychain
    else
      echo 'usage: dfsync password save|delete';
    fi
    ;;

  [pP][uU][sS][hH])
    push
    ;;

  [pP][uU][lL][lL])
    pull
    ;;

  *)
    echo 'usage: dfsync push|pull|password';
    ;;
esac
