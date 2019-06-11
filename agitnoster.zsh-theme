# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://gist.github.com/1595572).
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  # NOTE: This segment separator character is correct.  In 2012, Powerline changed
  # the code points they use for their special characters. This is the new code point.
  # If this is not working for you, you probably have an old version of the
  # Powerline-patched fonts installed. Download and install the new version.
  # Do not submit PRs to change this unless you have reviewed the Powerline code point
  # history and have new information.
  # This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
  # what font the user is viewing this source code in. Do not replace the
  # escape sequence with a single literal character.
  # Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
  SEGMENT_SEPARATOR=$'\uE0B0'
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "\n> %{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: use random emoji
prompt_context() {
  # Custom (Random emoji)
  emojis=("🍻" "🦄" "🎉" "🤖" "🦖" "🌎" "🌶" "🎮")
  RAND_EMOJI_N=$(( $RANDOM % ${#emojis[@]} + 1))
  prompt_segment black default "${emojis[$RAND_EMOJI_N]} "
}

# Git
all_lines() {
  echo "$1" | grep -v "^$" | wc -l ;
}

count_lines() {
  echo "$1" | egrep -c "^$2" ;
}

git_details() {
  gitstatus=`git diff --name-status 2>&1`
  staged_files=`git diff --staged --name-status`

  changed=$(( `all_lines "$gitstatus"` - `count_lines "$gitstatus" U` - `count_lines "$gitstatus" D`))
  conflict=`count_lines "$staged_files" U`
  deleted=$(( `all_lines "$gitstatus"` - `count_lines "$gitstatus" U` - `count_lines "$gitstatus" M` ))
  staged=$(( `all_lines "$staged_files"` - num_conflicts ))
  stashed=`git stash list | wc -l | sed -e 's/^[ \t]*//'`
  untracked=`git status -s -uall | grep -c "^??"`

  if [[ $staged -ne "0" ]]; then
      prompt_segment green white
      echo -n "🚀 ${staged}"
  fi

  if [[ $untracked -ne "0" ]]; then
      prompt_segment blue white
      echo -n "💡 ${untracked}"
  fi

  if [[ $deleted -ne "0" ]]; then
      prompt_segment red white
      echo -n "🔥 ${deleted}"
  fi

  if [[ $changed -ne "0" ]]; then
      prompt_segment magenta white
      echo -n "🔧 ${changed}"
  fi

  if [[ $stashed -ne "0" ]]; then
      prompt_segment cyan white
      echo -n "📌 ${stashed}"
  fi

  if [[ $conflict -ne "0" ]]; then
      prompt_segment red white
      echo -n "🌋 ${conflict}"
  fi
}

git_branch_diff() {
  branch=`git symbolic-ref HEAD | sed -e 's/refs\/heads\///g'`
  remote_name=`git config branch.${branch}.remote`

  if [[ -n "$remote_name" ]]; then
    merge_name=`git config branch.${branch}.merge`
  else
    remote_name='origin'
    merge_name="refs/heads/${branch}"
  fi

  if [[ "$remote_name" == '.' ]]; then
    remote_ref="$merge_name"
  else
    remote_ref="refs/remotes/$remote_name/${branch}"
  fi

  if [[ `git remote 2>/dev/null | wc -l` -ne "0" ]]; then
    revgit=`git rev-list --left-right ${remote_ref}...HEAD`
    revs=`all_lines "$revgit"`
    ahead=`count_lines "$revgit" "^>"`
    behind=$(( revs - ahead ))

    if [[ $ahead -ne "0" ]]; then
        echo -n "·\u2B06 ${ahead}"
    fi

    if [[ $behind -ne "0" ]]; then
        echo -n "·\u2B07 ${behind}"
    fi
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  local ref dirty
  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    ZSH_THEME_GIT_PROMPT_DIRTY='±'
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git show-ref --head -s --abbrev |head -n1 2> /dev/null)"

    if [[ -n $dirty ]]; then
      prompt_segment yellow black
    else
      prompt_segment green black
    fi

    echo -n "${ref/refs\/heads\//\uE0A0 }"

    git_branch_diff
    git_details
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment blue white '%~'
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue black "(`basename $virtualenv_path`)"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}\u2718" || symbols+="%{%F{green}%}\u2714"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}\u26A1"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}\u2699"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_virtualenv
  prompt_status
  prompt_context
  prompt_dir
  prompt_git
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '
