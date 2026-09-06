#!/bin/bash

set -euo pipefail

readonly DOTFILES_REPOSITORY="${DOTFILES_REPOSITORY:-rigarash/dotfiles}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This bootstrap script supports macOS only." >&2
    exit 1
fi

case "$(uname -m)" in
    arm64)
        brew_bin="/opt/homebrew/bin/brew"
        ;;
    x86_64)
        brew_bin="/usr/local/bin/brew"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

if [[ ! -x "$brew_bin" ]]; then
    echo "==> Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ ! -x "$brew_bin" ]]; then
    echo "Homebrew installation did not produce $brew_bin" >&2
    exit 1
fi

eval "$("$brew_bin" shellenv)"

echo "==> Installing GitHub CLI and chezmoi"
"$brew_bin" install gh chezmoi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    echo "==> GitHub authentication is required to access the private dotfiles repository"
    gh auth login \
        --hostname github.com \
        --git-protocol https \
        --web
fi

gh auth setup-git --hostname github.com

echo "==> Applying ${DOTFILES_REPOSITORY}"
exec chezmoi init --apply "https://github.com/${DOTFILES_REPOSITORY}.git"
