#!/usr/zsh

#
# Copyright (c) 2026 DeltaRazero
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#

# Fastprompt - Fast, light, minimalistic, and tiny ZSH prompt framework.

# ******************************************************************************

# Safeguard to prevent double loading.
(( $+functions[fastprompt_init] )) && return 0

autoload -Uz add-zsh-hook

# ******************************************************************************

#
# Resets and initializes variables and hooks.
#
fastprompt_init() {
  setopt promptsubst
  setopt PROMPT_SUBST
  PROMPT=""

  typeset -gA _FPROMPT_DYNAMIC_ENTRIES
  typeset -g  _FPROMPT_DYNAMIC_ENTRIES_COUNT=0

  typeset -gA _FPROMPT_GLOBAL
  _FPROMPT_GLOBAL[is_elevated]=""

  # If running under Windows, ZSH doesn't recognize when it's running under
  # elevated privileges. Since the privileges can't time out under the same
  # process, we can permanently set the elevated flag.
  if [[ "$(uname -s)" =~ ^.*_NT-[0-9]+.* ]]; then
    net session >/dev/null 2>&1
    (( $? == 0 )) && _FPROMPT_GLOBAL[is_elevated]="1"
  else
    add-zsh-hook precmd _fastprompt_update_privilege_state
  fi

  add-zsh-hook precmd _fastprompt_dynamic_precmd
}

_fastprompt_update_privilege_state() {
  local current_value="${_FPROMPT_GLOBAL[is_elevated]}"
  # Use the built-in ZSH variable to check if the user is privileged, indicated by '#'.
  [[ $# == \#* ]] \
    && _FPROMPT_GLOBAL[is_elevated]="1" \
    || _FPROMPT_GLOBAL[is_elevated]=""
  # Don't trigger re-evaluation of prompt expansion if privilege state hasn't changed.
  [[ "$current_value" == "${_FPROMPT_GLOBAL[is_elevated]}" ]] && return
  PROMPT="$PROMPT"
}

# ******************************************************************************

#
# Main function to format prompt contents.
#
# @param $1 string : The string value input.
#
# @flag void -allow-empty: Allow printing an empty string value as input.

# @flag void -bold      : Whether the value should be bold.
# @flag void -underline : Whether the value should be underlined.
# @flag void -standout  : Whether the value should be standout.
#
# @flag string -fg : The foreground character highlighting colour code.
# @flag string -bg : The background character highlighting colour code.
# @flag string -fg-keep : Don't terminate the foreground colour (if set).
# @flag string -bg-keep : Don't terminate the background colour (if set).
#
# @flag string -prefix : String printed before the value. Copies formatting of
#   the main value.
# @flag string -suffix : String printed after the value. Copies formatting of
#   the main value.
# @flag string -padding : Amount of spaces to print before/after the main value.
#   When separated by a comma, you can specify the padding left and right.
#
# @flag string -start-separator : String printed before the value. No formatting
#   is copied, except for the background colour (if set).
# @flag string -end-separator : String printed after the value. No formatting is
#   copied, except for the background colour (if set).
#
# @return string : The formatted value. Usually to add to `PROMPT``.
#
_fastprompt_format() {
  local str_value=""
  local is_empty=0
  local is_bold=0 is_underline=0 is_standout=0
  local fg_color="" bg_color=""
  local fg_keep=0 bg_keep=0 sticky=0
  local prefix="" suffix="" padding=0
  local use_start_separator=0 start_separator="" use_end_separator=0 end_separator=""

  # Process arguments.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -empty)         is_empty=1 ;;
      -bold)          is_bold=1 ;;
      -underline)     is_underline=1 ;;
      -standout)      is_standout=1 ;;
      -fg-keep)       fg_keep=1 ;;
      -bg-keep)       bg_keep=1 ;;
      -sticky)        sticky=1 ;;
      -fg)            fg_color="$2"; shift ;;
      -bg)            bg_color="$2"; shift ;;
      -prefix)        prefix="$2"; shift ;;
      -suffix)        suffix="$2"; shift ;;
      -padding)       padding="$2"; shift ;;
      -start-separator) use_start_separator=1; start_separator="$2"; shift ;;
      -end-separator)   use_end_separator=1; end_separator="$2"; shift ;;
      *)
        if [[ ! "$str_value" && $is_empty -eq 0 ]]; then
          str_value="$1"
        fi
        ;;
    esac
    shift
  done

  # Exit early if input value evaluates to empty.
  [[ ! "$str_value" && $is_empty -eq 0 ]] && return

  # Parse `normal^privileged` content split if defined as such.
  if [[ "$str_value" == *\^* ]]; then
    local val_n="${str_value%%^*}"
    local val_p="${str_value#*^}"
    # TODO: Check which is faster.
    # str_value="\${_FPROMPT_GLOBAL[is_elevated]:+\"${val_p}\"}\${_FPROMPT_GLOBAL[is_elevated]:-\"${val_n}\"}"
    str_value="\${\${\${_FPROMPT_GLOBAL[is_elevated]:-"${val_n}"}#1}:-"${val_p}"}"
  fi

  # Apply text style flags.
  [[ $is_bold      -eq 1 ]] && str_value="%B${str_value}%b"
  [[ $is_underline -eq 1 ]] && str_value="%U${str_value}%u"
  [[ $is_standout  -eq 1 ]] && str_value="%S${str_value}%s"

  # Apply foreground colours (%F / %f).
  local parsed_fg
  if [[ -n "$fg_color" ]]; then
    parsed_fg=$(_fastprompt_parse_color "$fg_color")
    str_value="%F{$parsed_fg}${str_value}"
    prefix="%F{$parsed_fg}${prefix}"
    suffix="%F{$parsed_fg}${suffix}"
  fi
  if [[ $fg_keep -eq 0 ]]; then
    str_value="${str_value}%f"
    suffix="${suffix}%f"
  fi

  # Apply background colours (%K / %k).
  local parsed_bg
  if [[ -n "$bg_color" ]]; then
    parsed_bg=$(_fastprompt_parse_color "$bg_color")
    # If a start separator is used, colour will be applied beforehand.
    [[ ! -n "$start_separator" ]] && str_value="%K{$parsed_bg}${str_value}"
  fi
  # Always keep colour if using an end-separator.
  [[ $bg_keep -eq 0 && $use_separator -eq 0 ]] && str_value="${str_value}%k"

  # Add prefix and suffix.
  str_value="${prefix}${str_value}${suffix}"

  # Split by comma.
  local -a pads
  IFS=, read -rA pads <<< "$padding"
  # Extract left padding, default to 0 if empty.
  local pad_left=${pads[1]:-0}
  # Extract right padding. If not provided, fall back to pad_left.
  local pad_right=${pads[2]:-$pad_left}
  # Apply the padding.
  str_value="${(l:$pad_left:)}${str_value}${(l:$pad_right:)}"

  # # Start separator.
  if [[ $use_start_separator -eq 1 && -n "$bg_color" ]]; then
    # Use background colour of main content as foreground and then switch it
    # to background.
    str_value="%F{$parsed_bg}${start_separator}%f%K{$parsed_bg}${str_value}"
  fi

  # # End-separator.
  if [[ $use_end_separator -eq 1 && -n "$bg_color" ]]; then
    # Use background colour of main content as foreground and then switch it
    # to background.
    str_value="${str_value}%f%k%F{$parsed_bg}${end_separator}"
  fi

  # Add trailing space unless -sticky is passed.
  [[ $sticky -eq 0 ]] && str_value="${str_value} "

  # Return final formatted string.
  echo "${str_value}"
}

# Helper function to parse `normal^privileged` colour split if defined as such.
_fastprompt_parse_color() {
  local col="$1"
  if [[ "$col" == *\^* ]]; then
    local col_n="${col%%^*}"
    local col_p="${col#*^}"
    # TODO: Check which is faster.
    # echo "\${_FPROMPT_GLOBAL[is_elevated]:+\"${col_p}\"}\${_FPROMPT_GLOBAL[is_elevated]:-\"${col_n}\"}"
    echo "\${\${\${_FPROMPT_GLOBAL[is_elevated]:-"${col_n}"}#1}:-"${col_p}"}"
  else
    echo "$col"
  fi
}

# ******************************************************************************

#
# Adds content to the prompt.
#
# @flag void -dynamic If the string should be reevaluated dynamically, for when
#   the string contains variables that can change during terminal lifetime.
#
fastprompt_add_raw() {
  local is_dynamic=0

  local filtered_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -dynamic) is_dynamic=1 ;;
      *) filtered_args+=("$1") ;;
    esac
    shift
  done

  if [[ $is_dynamic -eq 0 ]]; then
    PROMPT="${PROMPT}`_fastprompt_format "${filtered_args[@]}"`"
    return
  fi

  local i=1
  _FPROMPT_DYNAMIC_ENTRIES_COUNT=$i

  _FPROMPT_DYNAMIC_ENTRIES[$i.raw_expr]="$filtered_args"
  _FPROMPT_DYNAMIC_ENTRIES[$i.cur_expr]=""
  _FPROMPT_DYNAMIC_ENTRIES[$i.expanded]=""
  _fastprompt_dynamic_entry_update $i

  PROMPT="${PROMPT}\${_FPROMPT_DYNAMIC_ENTRIES[$i.expanded]}"
}

_fastprompt_dynamic_precmd() {
  for ((i = 1; i <= $_FPROMPT_DYNAMIC_ENTRIES_COUNT; i++)); do
    _fastprompt_dynamic_entry_update $i
  done
}

_fastprompt_dynamic_entry_update() {
  local expression="${(e)${_FPROMPT_DYNAMIC_ENTRIES[$1.raw_expr]}}"
  [[ "$_FPROMPT_DYNAMIC_ENTRIES[$1.cur_expr]" == "$expression" ]] && return

  _FPROMPT_DYNAMIC_ENTRIES[$1.cur_expr]="$expression"
  _FPROMPT_DYNAMIC_ENTRIES[$1.expanded]="`eval _fastprompt_format $expression`"
}

# ******************************************************************************

#
# Adds username to prompt.
#
fastprompt_add_user() {
  fastprompt_add_raw "%n" "$@"
}

#
# Adds hostname to prompt.
#
# @flag void -short Show short hostname (%m) instead of full (%M).
#
fastprompt_add_host() {
  local host_fmt="%M"
  local filtered_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -short) host_fmt="%m" ;;
      *) filtered_args+=("$1") ;;
    esac
    shift
  done

  fastprompt_add_raw "$host_fmt" "${filtered_args[@]}"
}

#
# Adds MSYS2 `$MSYSTEM` variable value to prompt.
#
fastprompt_add_msystem() {
  fastprompt_add_raw "$MSYSTEM" "$@"
}

#
# Adds working directory (%~) to prompt.
#
fastprompt_add_dir() {
  fastprompt_add_raw "%~" "$@"
}

# ******************************************************************************

#
# Adds git information to prompt.
#
fastprompt_add_git() {
  # Check that git is installed as its a necessary dependency.
  $(which "git" > /dev/nul) || return

  zmodload zsh/datetime
  zmodload zsh/stat

  # @type map<string, int>
  #  Keeps track when a directory was last processed.
  #  - KEY: A directory retrieved from $PWD.
  #  - VAL: The unix timestamp when last processed.
  typeset -gA _FPROMPT_GIT_DIR_LAST_CHECKED

  # @type map<string, string>
  #  Keeps track of if a directory is within a git tree and its .git directory.
  #  - KEY: A directory retrieved from $PWD.
  #  - VAL: Path to the repo's .git directory or empty if not in a git tree.
  typeset -gA _FPROMPT_DOTGITS

  # @type map<string, int>
  #  Keeps track when a git repo's metadata were last processed.
  #  - KEY: A repo's .git directory.
  #  - VAL: The unix timestamp when last processed.
  typeset -gA _FPROMPT_DOTGIT_LAST_CHECKED

  # @type map<string, int>
  #  Keeps track when a git repo's metadata were last processed.
  #  - KEY: A repo's .git directory.
  #  - VAL: The unix timestamp when last processed.
  typeset -gA _FPROMPT_GIT_INDEX_LAST_CHECKED

  # @type int
  #   The amount of seconds before forcefully checking a directory again.
  typeset -g _FPROMPT_GIT_FORCE_RECHECK_DELAY=360
  # @type int
  #   The amount of seconds before fetching git metadata again.
  typeset -g _FPROMPT_GIT_CACHE_DELAY=2

  local filtered_args=()
  # Process arguments.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -force-recheck-delay) _FPROMPT_GIT_FORCE_RECHECK_DELAY="$2"; shift ;;
      *) filtered_args+=("$1") ;;
    esac
    shift
  done

  # @type string
  #   Path to a git repo's .git directory.
  local dotgit=""

  # Prints current git state.
  _fprompt_git_state() {
    local git_state=""
    if [[ -d "$dotgit/rebase-merge" ]]; then
      if [[ -f "$dotgit/rebase-merge/interactive" ]]; then
        git_state="REBASE-I"
      else
        git_state="REBASE-M"
      fi
    elif [[ -d "$dotgit/rebase-apply" ]]; then
      if [[ -f "$dotgit/rebase-apply/rebasing" ]]; then
        git_state="REBASE"
      elif [[ -f "$dotgit/rebase-apply/applying" ]]; then
        git_state="AN"
      else
        git_state="AM/REBASE"
      fi
    elif [[ -f "$dotgit/MERGE_HEAD" ]]; then
      git_state="MERGING"
    elif [[ -f "$dotgit/CHERRY_PICK_HEAD" ]]; then
      git_state="CHERRY-PICKING"
    elif [[ -f "$dotgit/REVERT_HEAD" ]]; then
      git_state="REVERTING"
    elif [[ -f "$dotgit/BISECT_LOG" ]]; then
      git_state="BISECTING"
    fi
    [[ $git_state ]] && echo "$git_state:"
  }

  # Prints current git branch.
  _fprompt_git_branch() {
    # Read the first line of .git/HEAD directly into a variable.
    local head
    read -r head < $dotgit/HEAD 2>/dev/null || return
    # Check if we're on a branch or in detached HEAD state.
    if [[ $head == "ref: refs/heads/"* ]]; then
      # Strip the prefix using native parameter expansion, and echo the branch.
      echo "${head#ref: refs/heads/}"
    else
      echo "HEAD"
    fi
  }

  # Prints local tracking status.
  local _fprompt_git_local_status_stdout=""
  _fprompt_git_local_status() {
    [[ ! $_FPROMPT_GIT ]] && _fprompt_git_local_status_stdout=""
    # Check for unresolved conflicts via index or MERGE_MSG.
    if [[ -f "$dotgit/MERGE_MSG" ]]; then
      if grep -q "^# Conflicts:" "$dotgit/MERGE_MSG" 2>/dev/null; then
        # Conflicted.
        _fprompt_git_local_status_stdout="="
        return
      fi
    fi
    if [[ -f "$dotgit/index" ]]; then
      local index_mtime objects_mtime
      zstat +mtime -A index_mtime   "$dotgit/index"
      zstat +mtime -A objects_mtime "$dotgit/objects"

      if [[ $index_mtime -gt ${_FPROMPT_GIT_INDEX_LAST_CHECKED[$dotgit]:-0} || $objects_mtime -gt ${_FPROMPT_GIT_INDEX_LAST_CHECKED[$dotgit]:-0} ]]; then
        _FPROMPT_GIT_INDEX_LAST_CHECKED[$dotgit]="$index_mtime"
        local git_status_stdout="$(git status -s)"
        _fprompt_git_local_status_stdout=""

        # Staged changes.
        if [[ ! $_fprompt_git_local_status_stdout && $git_status_stdout =~ "^[MTADRCU]"  ]]; then
          _fprompt_git_local_status_stdout="+"
        else
          # Tracked and modified.
          [[ ! $_fprompt_git_local_status_stdout && $git_status_stdout =~ "^ [MTADRCU]" ]] && _fprompt_git_local_status_stdout="*"
        fi
        return
      fi
    fi
  }

  # Prints remote tracking status.
  _fprompt_git_remote_status() {
    local ahead=0 behind=0
    if [[ -n "$branch" && -f "$dotgit/refs/heads/$branch" ]]; then
      local local_sha upstream_sha=""
      read -r local_sha < "$dotgit/refs/heads/$branch"
      # Try finding upstream ref in FETCH_HEAD or refs/remotes
      if [[ -f "$dotgit/FETCH_HEAD" ]]; then
        read -r upstream_sha _ < "$dotgit/FETCH_HEAD" 2>/dev/null
      fi
      if [[ -n "$upstream_sha" && "$local_sha" != "$upstream_sha" ]]; then
        # If hashes differ, check if local ref exists in commit history log
        if [[ -f "$dotgit/logs/refs/heads/$branch" ]] && grep -q "$upstream_sha" "$dotgit/logs/refs/heads/$branch" 2>/dev/null; then
          ahead=1
        else
          behind=1
        fi
      fi
    fi
    local remote_status=""
    if [[ $ahead -eq 1 && $behind -eq 1 ]]; then
      # Diverged.
      remote_status="⇕"
    elif [[ $ahead -eq 1 ]]; then
      # Ahead.
      remote_status="⇡"
    elif [[ $behind -eq 1 ]]; then
      # Behind.
      remote_status="⇣"
    fi
    [[ $remote_status ]] && echo " $remote_status"
  }

  typeset -g _FPROMPT_GIT_ARGS=("${filtered_args[@]}")
  _fastprompt_git()
  {
    # Whether to check and process metadata to display.
    local recheck=1

    # If the directory has already been scanned before.
    if (( ${+_FPROMPT_DOTGITS[$PWD]} )); then
      # Check if we should force recheck directory for changes after configured delay.
      (( recheck = ($EPOCHSECONDS - ${_FPROMPT_GIT_DIR_LAST_CHECKED[$PWD]:-0}) > $_FPROMPT_GIT_FORCE_RECHECK_DELAY ))

      # If we don't have to recheck and the directory didn't belong to a git tree.
      if [[ $recheck -eq 0 && ! ${(v)_FPROMPT_DOTGITS[$PWD]} ]]; then
        _FPROMPT_GIT=""
        return
      fi
    fi

    # Get the repo's .git directory, if it belongs to a git tree.
    dotgit=${_FPROMPT_DOTGITS[$PWD]}
    if [[ $recheck -eq 1 || ! $dotgit ]]; then
      dotgit="$(_fastprompt_git_get_dotgit)"
      _FPROMPT_DOTGITS[$PWD]="$dotgit"
      _FPROMPT_GIT_DIR_LAST_CHECKED[$PWD]="$EPOCHSECONDS"
    fi

    # Stop when the directory doesn't belong to a git tree or the directory no longer exists.
    if [[ ! $dotgit || ! -d $dotgit ]]; then
      _FPROMPT_DOTGITS[$PWD]=""
      _FPROMPT_GIT=""
      _FPROMPT_GIT_DIR_LAST_CHECKED[$PWD]="$EPOCHSECONDS"
      return
    fi

    # Cache git metadata results for a small amount of time for speed up.
    (( ($EPOCHSECONDS - ${_FPROMPT_DOTGIT_LAST_CHECKED[$dotgit]:-0}) < $_FPROMPT_GIT_CACHE_DELAY )) && return
    _FPROMPT_DOTGIT_LAST_CHECKED[$dotgit]=$EPOCHSECONDS

    _fprompt_git_local_status
    local git_status="$_fprompt_git_local_status_stdout$(_fprompt_git_remote_status)"

    _FPROMPT_GIT="$(_fastprompt_format "$(_fprompt_git_state)$(_fprompt_git_branch)$git_status" "${_FPROMPT_GIT_ARGS[@]}")"
  }
  add-zsh-hook precmd _fastprompt_git

  PROMPT="${PROMPT}\${_FPROMPT_GIT}"
}

# Fast pure ZSH function to retrieve a .git folder if $PWD is within a git tree.
_fastprompt_git_get_dotgit() {
  # Don't run when in the root or with empty paths.
  [[ ! "$PWD" || "$PWD" == "/" ]] && return 1

  local current="$PWD"
  while [[ "$current" != "/" ]]; do
    # Check if .git exists as a directory or file (for git submodules/worktrees).
    if [[ -e "$current/.git" ]]; then
      echo "$current/.git"
      return 0
    fi
    # Move up one directory level using the :h (head) ZSH modifier.
    current="${current:h}"
  done

  return 1
}
