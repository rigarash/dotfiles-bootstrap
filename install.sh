#!/bin/bash

set -euo pipefail

readonly DOTFILES_REPOSITORY="${DOTFILES_REPOSITORY:-rigarash/dotfiles}"

# GitHub's SSH host keys, as published in the ssh_keys field of
# https://api.github.com/meta
readonly GITHUB_KNOWN_HOSTS="\
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="

# Logs in to GitHub with GitHub CLI unless it is logged in already, and lets
# git use its token for https://github.com.
login_github_https() {
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        echo "==> GitHub authentication is required to access the private dotfiles repository"
        gh auth login \
            --hostname github.com \
            --git-protocol https \
            --web
    fi

    gh auth setup-git --hostname github.com
}

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

    login_github_https

    echo "==> Applying ${DOTFILES_REPOSITORY}"
    exec chezmoi init --apply "https://github.com/${DOTFILES_REPOSITORY}.git"
}

# Explains a failed ssh -T git@github.com. The advice differs between a local
# machine such as WSL and a server logged in to with ssh -A.
explain_github_ssh_failure() {
    local auth="$1"
    local agent=0

    printf '%s\n' "$auth" >&2

    case "$auth" in
        *"Permission denied"*)
            ;;
        *"Host key verification failed"*)
            echo "github.com presented a host key that does not match ~/.ssh/known_hosts." >&2
            echo "Compare it with https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints before changing anything." >&2
            return
            ;;
        *)
            echo "Cannot connect to github.com over SSH. Check the network and whether outbound SSH is allowed." >&2
            return
            ;;
    esac

    # 0: the agent holds keys, 1: it holds none, 2: there is no agent.
    ssh-add -l >/dev/null 2>&1 || agent=$?

    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        case "$agent" in
            0)
                echo "GitHub accepted none of the keys in the forwarded SSH agent:" >&2
                ssh-add -l >&2
                echo "Register one of them at https://github.com/settings/keys, or log in from a machine whose agent holds a registered key." >&2
                ;;
            1)
                echo "The forwarded SSH agent holds no keys." >&2
                echo "Add a key registered on GitHub with ssh-add on the machine you logged in from, then run this script again." >&2
                ;;
            *)
                echo "No SSH agent is forwarded to this session." >&2
                echo "Log in again with ssh -A from a machine whose agent holds a key registered on GitHub." >&2
                ;;
        esac
    else
        case "$agent" in
            0)
                echo "GitHub accepted none of the keys in the SSH agent:" >&2
                ssh-add -l >&2
                ;;
            1)
                echo "The SSH agent holds no keys." >&2
                ;;
            *)
                echo "No SSH agent is running. Start one with: eval \"\$(ssh-agent -s)\"" >&2
                ;;
        esac
        echo "Add a key registered on GitHub with ssh-add, then run this script again." >&2
        echo "To register a new key, create one with ssh-keygen -t ed25519 and add ~/.ssh/id_ed25519.pub at https://github.com/settings/keys." >&2
    fi
}

# Adds GitHub's host keys to ~/.ssh/known_hosts, then checks that GitHub
# accepts a key over SSH and explains what to fix when it does not.
check_github_ssh() {
    local cmd auth login

    for cmd in ssh ssh-add ssh-keygen; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "$cmd is required to clone over SSH. Install the OpenSSH client." >&2
            return 1
        fi
    done

    if ! ssh-keygen -F github.com >/dev/null 2>&1; then
        echo "==> Adding GitHub's SSH host keys to ~/.ssh/known_hosts"
        mkdir -p -m 700 "$HOME/.ssh"
        printf '%s\n' "$GITHUB_KNOWN_HOSTS" >>"$HOME/.ssh/known_hosts"
    fi

    # BatchMode keeps ssh from asking for a passphrase, so a key that needs
    # one has to be in an agent.
    # ssh -T exits with 1 even when authentication succeeds.
    auth="$(ssh -T -o BatchMode=yes -o ConnectTimeout=15 git@github.com 2>&1 || true)"
    case "$auth" in
        *"successfully authenticated"*)
            login="$(printf '%s\n' "$auth" | sed -n 's/^Hi \([^!]*\)!.*/\1/p')"
            echo "==> Authenticated to GitHub over SSH as ${login}"
            ;;
        *)
            explain_github_ssh_failure "$auth"
            return 1
            ;;
    esac
}

# Asks, after SSH failed, whether to clone over HTTPS instead. HTTPS leaves a
# GitHub token on this machine, so it is not used without asking.
offer_github_https() {
    local answer

    echo >&2
    echo "The repository can be cloned over HTTPS instead. GitHub CLI then logs in through the browser and stores its token on this machine." >&2
    echo "To use HTTPS without trying SSH first, run this script with DOTFILES_GIT_PROTOCOL=https." >&2

    [[ -t 0 ]] || return 1
    read -r -p "Continue over HTTPS? [y/N] " answer
    [[ "$answer" == [Yy]* ]]
}

# Installs GitHub CLI from its latest release to the given directory, after
# checking the download against the release's checksums. The body runs in a
# subshell so that the trap removes the download however it ends.
install_gh_linux() (
    local bin_dir="$1"
    local arch version name tmp

    case "$(uname -m)" in
        x86_64)
            arch=amd64
            ;;
        aarch64 | arm64)
            arch=arm64
            ;;
        armv6l | armv7l)
            arch=armv6
            ;;
        i386 | i686)
            arch=386
            ;;
        *)
            echo "Unsupported architecture: $(uname -m)" >&2
            exit 1
            ;;
    esac

    # github.com redirects releases/latest to the tag of the latest release.
    version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest)"
    version="${version##*/v}"
    if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
        echo "Cannot find the latest release of GitHub CLI." >&2
        exit 1
    fi
    name="gh_${version}_linux_${arch}"

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    curl -fsSL -o "$tmp/${name}.tar.gz" "https://github.com/cli/cli/releases/download/v${version}/${name}.tar.gz"
    curl -fsSL -o "$tmp/checksums.txt" "https://github.com/cli/cli/releases/download/v${version}/gh_${version}_checksums.txt"
    if ! (cd "$tmp" && awk -v f="${name}.tar.gz" '$2 == f' checksums.txt | sha256sum -c - >/dev/null); then
        echo "${name}.tar.gz does not match the checksums of the release." >&2
        exit 1
    fi

    tar -xzf "$tmp/${name}.tar.gz" -C "$tmp"
    mkdir -p "$bin_dir"
    install -m 755 "$tmp/${name}/bin/gh" "$bin_dir/gh"
)

# Linux clones the repository over SSH when it can, and then stores no GitHub
# credentials of its own. On a local machine such as WSL, the key comes from
# the SSH agent or ~/.ssh; on a server, from the agent forwarded with ssh -A.
# Over HTTPS, GitHub CLI logs in through the browser as on macOS and keeps its
# token on this machine. DOTFILES_GIT_PROTOCOL chooses one; when it is unset,
# HTTPS is offered if SSH fails.
bootstrap_linux() {
    local bin_dir="$HOME/.local/bin"
    local protocol="${DOTFILES_GIT_PROTOCOL:-}"
    local repository_url

    case "$protocol" in
        "" | ssh | https)
            ;;
        *)
            echo "DOTFILES_GIT_PROTOCOL must be ssh or https, not ${protocol}" >&2
            exit 1
            ;;
    esac

    if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required." >&2
        exit 1
    fi

    # Checked before installing anything.
    if [[ "$protocol" != https ]]; then
        if check_github_ssh; then
            protocol=ssh
        elif [[ -z "$protocol" ]] && offer_github_https; then
            protocol=https
        else
            exit 1
        fi
    fi

    # Without git, chezmoi clones with its built-in git, which does not get the
    # token from GitHub CLI.
    if [[ "$protocol" == https ]] && ! command -v git >/dev/null 2>&1; then
        echo "git is required to clone over HTTPS." >&2
        exit 1
    fi

    export PATH="$bin_dir:$PATH"

    if [[ "$protocol" == https ]]; then
        if ! command -v gh >/dev/null 2>&1; then
            echo "==> Installing GitHub CLI to $bin_dir"
            install_gh_linux "$bin_dir"
        fi
        login_github_https
        repository_url="https://github.com/${DOTFILES_REPOSITORY}.git"
    else
        repository_url="git@github.com:${DOTFILES_REPOSITORY}.git"
    fi

    if ! command -v chezmoi >/dev/null 2>&1; then
        echo "==> Installing chezmoi to $bin_dir"
        sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$bin_dir"
    fi

    echo "==> Applying ${DOTFILES_REPOSITORY}"
    exec chezmoi init --apply "$repository_url"
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
