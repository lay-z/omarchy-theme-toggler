#!/usr/bin/env bash
# Example post-toggle hook: refresh tmux after an Omarchy theme switch.
#
# Copy to ~/.config/omarchy/theme-toggler/post-toggle.sh and make it executable.

set -euo pipefail

if command -v tmux >/dev/null 2>&1 && tmux has-session >/dev/null 2>&1; then
  case "$1" in
    light) flavor=latte ;;
    dark) flavor=mocha ;;
    *) exit 0 ;;
  esac

  # Remove `set -g @catppuccin_flavor ...` from tmux.conf; this hook owns it.
  catppuccin_dir=""
  for candidate in \
    "$HOME/.config/tmux/plugins/tmux" \
    "$HOME/.tmux/plugins/tmux"; do
    if [[ -d $candidate ]]; then
      catppuccin_dir=$candidate
      break
    fi
  done

  tmux set -g @catppuccin_flavor "$flavor"
  tmux source-file "$HOME/.config/tmux/tmux.conf"

  if [[ -n $catppuccin_dir ]]; then
    # catppuccin/tmux stores colors with `set -o`; clear the old cache first.
    tmux show-options -g | awk '/^@thm_/ { print $1 }' | while IFS= read -r option; do
      tmux set-option -gu "$option"
    done

    tmux source-file "$catppuccin_dir/themes/catppuccin_${flavor}_tmux.conf"
    tmux source-file "$catppuccin_dir/catppuccin_options_tmux.conf"
    tmux source-file "$catppuccin_dir/catppuccin_tmux.conf"
  fi
fi

if command -v herdr >/dev/null 2>&1; then
  herdr server reload-config 2>/dev/null || true
fi
