#!/bin/bash

fselect() {
  # Function that allows interactive selection of a file using fzf
  # Excludes hidden files/directories and displays file contents in fzf preview
  local path="${1:-.}" # Default to current directory if no directory is specified as parameter
  local file="$(find "$path" -type f ! -path '*/.*' -print0 | sort -z |
    fzf --height=30 --border=rounded --preview-window=wrap --preview='cat {}' --read0)"
  if [[ -z "$file" ]]; then
    echo "No file selected"
    return 1
  fi
  echo "$file"
}

kg() {
  # set default values to empty
  local type namespace name
  
  # interactive input
  type="$(kubectl api-resources -o name | fzf -e --height=30 --border=rounded)"
  [ -n "$type" ] || return 1  # Exit if no resource type selected
  namespace="$(kubectl get namespaces -o name | fzf -e --height=30 --border=rounded --header='NAMESPACE is optional. Hit ESC to skip' | xargs basename 2>/dev/null)"
  if [ -n "$namespace" ]; then # Selecting namespace can be skipped, but preffered to filter resources
    name="$(kubectl get -n "$namespace" "$type" -o name | fzf -e --height=30 --border=rounded | xargs basename 2>/dev/null)"
	[ -n "$name" ] || return 1 # Exit if no resource selected
  else
    name="$(kubectl get -A "$type" -o name | fzf -e --height=30 --border=rounded | xargs basename 2>/dev/null)"
	[ -n "$name" ] || return 1 # Exit if no resource selected
    namespace="$(kubectl get "$type" -A --field-selector metadata.name="$name" -o jsonpath='{.items[0].metadata.namespace}')"
  fi
  kubectl get -n "$namespace" "$type" "$name" "$@"
}

kydiff() {
  # set default values to empty
  local file live_obj

  # parse named parameters
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file=*)
        file="${1#*=}"
        shift
        ;;
      *)
        echo "Unknown option: $1. Usage: $FUNCNAME [--file=FILEPATH]"
        return 1
        ;;
    esac
  done
    
  # interactive selection of live object from the cluster
  echo -e "\033[1mSpecify cluster object\033[0m"
  live_obj="$(kg -o yaml)" || return 1 # exit with code 1 if used function returns with code 1
  
  # interactive input of $file value if not provided as parameter
  if [[ -z "$file" ]]; then
    echo -e "\033[1mSpecify file\033[0m"
    file="$(fselect)" || return 1 # exit with code 1 if used function returns with code 1
  fi
	
  # diff object file vs live
  echo -e "\033[1m$file <<< yaml-diff >>> $(echo "$live_obj" | yq .metadata.name -)\033[0m"
  cat <<< "$live_obj" | yaml-diff -O deep "$file" -
  echo -e "\033[1m$FUNCNAME finished for $file\033[0m"
  
  # validate
  echo -e "\033[1mValidating with yaml-validate\033[0m"
  yaml-validate --verbose "$file"
  echo -e "\033[1mValidating with kubectl diff\033[0m"
  kubectl diff -f "$file"
}

kysync() {
  # set default values to empty
  local file live_obj

  # parse named parameters
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file=*)
        file="${1#*=}"
        shift
        ;;
      *)
        echo "Unknown option: $1. Usage: $FUNCNAME [--file=FILEPATH]"
        return 1
        ;;
    esac
  done
    
  # interactive selection of live object from the cluster
  echo -e "\033[1mSpecify cluster object\033[0m"
  live_obj="$(kg -o yaml)" || return 1 # exit with code 1 if used function returns with code 1
  
  # interactive input of $file value if not provided as parameter
  if [[ -z "$file" ]]; then
    echo -e "\033[1mSpecify file\033[0m"
    file="$(fselect)" || return 1 # exit with code 1 if used function returns with code 1
  fi

  # save live object to file
  echo -e "\033[1mSaving $(echo "$live_obj" | yq .metadata.name) as $file.\033[0m"
  cat <<< "$live_obj" > "$file"
  echo -e "\033[1m$FUNCNAME finished for $file\033[0m"
}

kymerge() {
  # set default values to empty
  local file change mergepath tmppath
  
  #default tmppath
  tmppath=~/yamlpath

  # parse named parameters
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file=*)
        file="${1#*=}"
        shift
        ;;
      --change=*)
        change="${1#*=}"
        shift
        ;;
      --mergepath=*)
        mergepath="${1#*=}"
        shift
        ;;
      *)
        echo "Unknown option: $1. Usage: $FUNCNAME [--file=FILEPATH] [--change=FILEPATH] [--mergepath=YAMLPATH]"
        return 1
        ;;
    esac
  done

  # prompt for interactive input if variables not provided
  if [[ -z "$file" ]]; then
    echo -e "\033[1mSpecify file\033[0m"
    file="$(fselect)" || return 1 # exit with code 1 if used function returns with code 1
  fi

  if [[ -z "$change" ]]; then
    echo -e "\033[1mSpecify file containing required change\033[0m"
    change="$(fselect "$tmppath")" || return 1 # exit with code 1 if used function returns with code 1
  fi

  if [[ -z "$mergepath" ]]; then
    echo -e "\033[1mSpecify YAML path indicating where in source file the change is to be merged\033[0m"
    mergepath="$(export file; export change; cat $tmppath/mergepaths.txt |
	fzf --height=30 --border=rounded --preview-window=wrap \
	--preview='yaml-merge -S -m {} "$file" "$change" | yaml-diff -O deep "$file" -')"
  fi
  [ -n "$mergepath" ] || return 1 # Exit if no mergepath selected

  # perform merging 
  echo -e "\033[1mMerging $change with $file at $mergepath and saved as $file.\033[0m"
  yaml-merge -m "$mergepath" "$file" "$change" -w "$(echo "$file")"
  # perform validation
  echo -e "\033[1mValidating with yaml-validate\033[0m"
  yaml-validate --verbose "$file"
  echo -e "\033[1mValidating with kubectl diff\033[0m"
  kubectl diff -f "$file"
  echo -e "\033[1m$FUNCNAME finished for $file\033[0m"
}

kyclean() {
  # set default values to empty
  local file

  # parse named parameters
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file=*)
        file="${1#*=}"
        shift
        ;;
      *)
        echo "Unknown option: $1. Usage: $FUNCNAME [--file=FILEPATH]"
        return 1
        ;;
    esac
  done
  
  # interactive input of $file value if not provided as parameter
  if [[ -z "$file" ]]; then
    echo -e "\033[1mSpecify file\033[0m"
    file="$(fselect)" || return 1 # exit with code 1 if used function returns with code 1
  fi

  # clean
  echo -e "\033[1mRemoving .status .metadata.uid .metadata.generation .metadata.creationTimestamp\033[0m";
  yq eval 'del(.status,.metadata.uid,.metadata.generation,.metadata.creationTimestamp)' -i "$file"
  # perform validation
  echo -e "\033[1mValidating with yaml-validate\033[0m"
  yaml-validate --verbose "$file"
  echo -e "\033[1mValidating with kubectl diff\033[0m"
  kubectl diff -f "$file"
  echo -e "\033[1m$FUNCNAME finished for $file\033[0m"
}

kyindent()
{
  # set default values to empty
  local file tmppath
  
  #default tmppath
  tmppath=~/yamlpath
  
  # parse named parameters
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file=*)
        file="${1#*=}"
        shift
        ;;
      *)
        echo "Unknown option: $1. Usage: $FUNCNAME [--file=FILEPATH]"
        return 1
        ;;
    esac
  done
  
  # interactive input of $file value if not provided as parameter
  if [[ -z "$file" ]]; then
    echo -e "\033[1mSpecify file\033[0m"
    file="$(fselect)" || return 1 # exit with code 1 if used function returns with code 1
  fi
  
  # create temporary uniqe folder inside tmppath (to avoid rewriting existing files)
  UUIDtmppath=$tmppath/kyident-$(uuidgen)
  mkdir "$UUIDtmppath"
  # create temporary kustomization.yaml and populate with path to $file
  echo "resources: [$(realpath $file)]" > "$UUIDtmppath"/kustomization.yaml
  # perform indentation
  kubectl kustomize --load-restrictor='LoadRestrictionsNone' "$UUIDtmppath" -o "$(realpath $file)"
  # remove temporary folder and files
  rm -r "$UUIDtmppath"
  echo -e "\033[1m$FUNCNAME finished for $file\033[0m"
}

kysyncmerge()
{
  # set default values to empty
  local file
  
  # parse named parameters
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file=*)
        file="${1#*=}"
        shift
        ;;
      *)
        echo "Unknown option: $1. Usage: $FUNCNAME [--file=FILEPATH]"
        return 1
        ;;
    esac
  done
  
  # interactive input of $file value if not provided as parameter
  if [[ -z "$file" ]]; then
    echo -e "\033[1mSpecify file\033[0m"
    file="$(fselect)" || return 1 # exit with code 1 if used function returns with code 1
  fi
  
  kysync --file=$file
  kymerge --file=$file
  kyclean --file=$file
  kyindent --file=$file
}
