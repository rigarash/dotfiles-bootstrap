#!/bin/bash

set -euo pipefail

readonly DOTFILES_REPOSITORY="${DOTFILES_REPOSITORY:-rigarash/dotfiles}"

# GitHub's SSH host keys, as published in the ssh_keys field of
# https://api.github.com/meta
readonly GITHUB_KNOWN_HOSTS="\
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="

bootstrap_darwin() {
    local brew_bin

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
}

# Servers keep no GitHub credentials: the repository is cloned over SSH with
# the agent forwarded from the machine the user logged in from.
bootstrap_linux() {
    local bin_dir="$HOME/.local/bin"
    local auth

    export PATH="$bin_dir:$PATH"

    if ! command -v chezmoi >/dev/null 2>&1; then
        echo "==> Installing chezmoi to $bin_dir"
        sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$bin_dir"
    fi

    if ! ssh-keygen -F github.com >/dev/null 2>&1; then
        echo "==> Adding GitHub's SSH host keys to ~/.ssh/known_hosts"
        mkdir -p -m 700 "$HOME/.ssh"
        printf '%s\n' "$GITHUB_KNOWN_HOSTS" >>"$HOME/.ssh/known_hosts"
    fi

    # ssh -T exits with 1 even when authentication succeeds.
    auth="$(ssh -T -o BatchMode=yes git@github.com 2>&1 || true)"
    case "$auth" in
        *"successfully authenticated"*)
            ;;
        *)
            echo "$auth" >&2
            echo "Cannot authenticate to GitHub over SSH." >&2
            echo "Log in again with agent forwarding (ssh -A) using a key registered on GitHub." >&2
            exit 1
            ;;
    esac

    echo "==> Applying ${DOTFILES_REPOSITORY}"
    exec chezmoi init --apply "git@github.com:${DOTFILES_REPOSITORY}.git"
}

case "$(uname -s)" in
    Darwin)
        bootstrap_darwin
        ;;
    Linux)
        bootstrap_linux
        ;;
    *)
        echo "Unsupported operating system: $(uname -s)" >&2
        exit 1
        ;;
esac
