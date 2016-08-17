#!/bin/bash

select_tab() {
  local session="$1"
  local tab="$2"
  tmux select-window -t "${session}:${tab}"
}

setup_tab_zero() {
  local session="$1"
  tmux send-keys -t "${session}:0.0" C-c "clear" C-m || return 1
  tmux send-keys -t "${session}:0.0" "tmux kill-session -t ${session}" || return 1
}

setup_tab_vim() {
  local session="$1"
  tmux new-window -t "${session}:1" -n "editor" || return 1 
  tmux send-keys -t "${session}:1.0" "vim" C-m || return 1
}

setup_tab_project() {
  local session="$1"
  tmux new-window -t "${session}:2" -n "project" || return 1 
}

has_session() {
  local session="$1"
  tmux has-session -t "$session" 2> /dev/null
}

attach_session() {
  local session="$1"
  tmux attach -t "$session" 
}

create_session() {
  local session="$1"
  tmux new-session -d -s "$session" -n √ø 
}

fatal() {
  local message="$1"
  echo "Error: $message"
  exit 1
}

script_directory(){
  local source="${BASH_SOURCE[0]}"
  local dir=""

  while [ -h "$source" ]; do # resolve $source until the file is no longer a symlink
    dir="$( cd -P "$( dirname "$source" )" && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$dir/$source" # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done

  dir="$( cd -P "$( dirname "$source" )" && pwd )"

  echo "$dir"
}

usage(){
  echo 'USAGE: vimux </path/to/project-dir>'
  echo ''
  echo 'Arguments:'
  echo '  -h, --help         print this help text'
  echo '  -v, --version      print the version'
  echo ''
}

version(){
  local directory="$(script_directory)"
  local version=$(cat "$directory/VERSION")

  echo "$version"
}

main() {
  local project_dir="$1";
  while [ "$1" != "" ]; do
    local param="$1"
    local value="$2"
    case "$param" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      *)
        if [ "${param::1}" == '-' ]; then
          echo "ERROR: unknown parameter \"$param\""
          usage
          exit 1
        fi
        if [ ! -z "$param" ]; then
          project_dir="$param"
        fi
        ;;
    esac
    shift
  done

  if [ -z "$project_dir" ]; then
    project_dir="$PWD"
  fi

  if [ ! -d "$project_dir" ]; then 
    fatal "$project_dir is not a directory"
  fi

  cd "$project_dir"
  
  local project_name="$(basename "$project_dir")"
  local project_id=""
  if [ -z "$(which node)" ]; then
    local uuid="$(uuidgen)"
    project_id="${uuid:0:4}"
  else
    local string_js="'${project_name}'.split('-').map(function(s){return s[0] + s[s.length -1]}).join('')"
    project_id="$(node -e "console.log(${string_js})")"
  fi
  local session="vimux-${project_id}"

  has_session "$session"
  if [ "$?" != "0" ]; then
    create_session "$session" || fatal 'unable to create session'
    setup_tab_zero "$session" || fatal 'unable to setup tab zero'
    setup_tab_vim "$session" || fatal 'unable to setup tab vim'
    setup_tab_project "$session" || fatal 'unable to setup tab project'
  fi

  select_tab "$session" "1" 2> /dev/null 
  attach_session "$session"
}

main "$@"
