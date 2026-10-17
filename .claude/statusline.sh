#!/bin/bash
# Claude Code status line mimicking the oh-my-zsh "crocharisma" (agnoster-style) prompt.
input=$(cat)

dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
model=$(jq -r '.model.display_name // empty' <<<"$input")
ctx=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
five=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
five_reset=$(jq -r '.rate_limits.five_hour.resets_at // empty' <<<"$input")
week=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")
week_reset=$(jq -r '.rate_limits.seven_day.resets_at // empty' <<<"$input")
[ -z "$dir" ] && dir=$PWD

SEP=$''      # powerline arrow
BRANCH=$''   # powerline branch glyph
ESC=$'\033'

# ANSI color numbers: black=0 red=1 green=2 yellow=3 blue=4 default=9
CURRENT_BG=NONE
out=""

segment() { # bg fg text
  local bg=$1 fg=$2 text=$3
  if [[ $CURRENT_BG != NONE && $bg != $CURRENT_BG ]]; then
    out+=" ${ESC}[4${bg}m${ESC}[3${CURRENT_BG}m${SEP}${ESC}[3${fg}m "
  else
    out+="${ESC}[4${bg}m${ESC}[3${fg}m "
  fi
  CURRENT_BG=$bg
  out+="$text"
}

end_prompt() {
  if [[ $CURRENT_BG != NONE ]]; then
    out+=" ${ESC}[49m${ESC}[3${CURRENT_BG}m${SEP}"
  fi
  out+="${ESC}[0m"
}

# Virtualenv / AWS (only when set in the environment Claude was launched from)
[[ -n $VIRTUAL_ENV && -n $VIRTUAL_ENV_DISABLE_PROMPT ]] && segment 4 0 "($(basename "$VIRTUAL_ENV"))"
if [[ -n $AWS_PROFILE && $SHOW_AWS_PROMPT != false ]]; then
  case $AWS_PROFILE in
    *-prod|*production*) segment 1 3 "AWS: $AWS_PROFILE" ;;
    *) segment 2 0 "AWS: $AWS_PROFILE" ;;
  esac
fi

# Context: user@host
user=$(id -un)
if [[ $user != "$DEFAULT_USER" || -n $SSH_CLIENT ]]; then
  segment 0 9 "${user}@$(hostname -s 2>/dev/null || hostname)"
fi

# Dir: last path component (like %1/)
segment 4 0 "$(basename "$dir")"

# Git
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
   && [[ "$(git -C "$dir" config --get oh-my-zsh.hide-status 2>/dev/null)" != 1 ]]; then
  g() { git -C "$dir" --no-optional-locks "$@" 2>/dev/null; }
  gitdir=$(g rev-parse --absolute-git-dir)
  if ref=$(g symbolic-ref HEAD); then
    ref="${BRANCH} ${ref#refs/heads/}"
  else
    ref="➦ $(g rev-parse --short HEAD)"
  fi
  porcelain=$(g status --porcelain)
  flags=""
  grep -q '^.[MDT]' <<<"$porcelain" && flags+="±"
  grep -q '^[MADRCT]' <<<"$porcelain" && flags+="✚"
  [[ -n $flags ]] && flags=" $flags"
  mode=""
  if [[ -e $gitdir/BISECT_LOG ]]; then mode=" <B>"
  elif [[ -e $gitdir/MERGE_HEAD ]]; then mode=" >M<"
  elif [[ -e $gitdir/rebase || -e $gitdir/rebase-apply || -e $gitdir/rebase-merge ]]; then mode=" >R>"
  fi
  if [[ -n $porcelain ]]; then segment 3 0; else segment 2 0; fi
  out+="${ref}${flags}${mode}"
fi

end_prompt

# Claude info tail (dim, outside the powerline segments)
tail=""
limits=""
[[ -n $model ]] && tail+="$model"
bar() { # percent, ANSI color number -> 10-cell bar; filled cells bright
  local pct=${1%.*} color=$2 width=10 filled i full="" empty=""
  (( pct > 100 )) && pct=100
  filled=$(( (pct * width + 50) / 100 ))
  for ((i = 0; i < width; i++)); do
    (( i < filled )) && full+="█" || empty+="░"
  done
  # Leave dim for the filled part, then return to the dim tail style
  printf '%s' "${ESC}[22m${ESC}[3${color}m${full}${ESC}[39m${ESC}[2m${empty}"
}

[[ -n $ctx ]] && tail+="${tail:+ · }ctx $(bar "$ctx" 4) $(printf '%.0f' "$ctx")%"
if [[ -n $five ]]; then
  five_i=${five%.*}
  if (( five_i >= 90 )); then five_color=1
  elif (( five_i >= 75 )); then five_color=3
  else five_color=2
  fi
  limits+="5h $(bar "$five" "$five_color") ${five_i}%"
  [[ -n $five_reset ]] && limits+=" (resets $( (date -d "@$five_reset" +%-l:%M%p 2>/dev/null || /bin/date -r "$five_reset" +%-l:%M%p) | tr APM apm))"
fi
if [[ -n $week ]]; then
  week_i=${week%.*}
  if (( week_i >= 90 )); then week_color=1
  elif (( week_i >= 75 )); then week_color=3
  else week_color=2
  fi
  limits+="${limits:+ · }7d $(bar "$week" "$week_color") ${week_i}%"
  [[ -n $week_reset ]] && limits+=" (resets $( (date -d "@$week_reset" "+%a %-l:%M%p" 2>/dev/null || /bin/date -r "$week_reset" "+%a %-l:%M%p") | tr APM apm))"
fi

visible_width() { # strip ANSI, count code points (drop UTF-8 continuation bytes; locale-independent)
  printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g' | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '
}

# Limits share the line when they fit in $COLUMNS, otherwise drop to a second row
[[ -n $tail ]] && out+=" ${ESC}[2m${tail}${ESC}[0m"
if [[ -n $limits ]]; then
  if [[ -z $COLUMNS ]] || (( $(visible_width "$out") + 3 + $(visible_width "$limits") <= COLUMNS )); then
    out+=" ${ESC}[2m${tail:+· }${limits}${ESC}[0m"
  else
    out+=$'\n'"${ESC}[2m${limits}${ESC}[0m"
  fi
fi

printf '%s' "$out"
