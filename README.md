# dotfiles-bootstrap

Minimal macOS and Linux bootstrap for the private
[`rigarash/dotfiles`](https://github.com/rigarash/dotfiles) repository.

## Usage

Review [`install.sh`](./install.sh), then run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/rigarash/dotfiles-bootstrap/main/install.sh)"
```

No access token or SSH private key is stored in this repository.

To use another private repository:

```bash
DOTFILES_REPOSITORY=owner/repository /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/rigarash/dotfiles-bootstrap/main/install.sh)"
```

### macOS

The script installs Homebrew when needed, installs GitHub CLI and chezmoi,
authenticates to GitHub through the browser, and applies the dotfiles
repository over HTTPS.

GitHub authentication requires confirmation in a browser on a new machine.

### Linux

The script applies the dotfiles repository over SSH when it can, and offers
HTTPS when SSH fails. Either way, it installs the chezmoi binary to
`~/.local/bin` without root privileges and needs `curl`.

#### SSH

The script adds GitHub's SSH host keys to `~/.ssh/known_hosts`, checks that
it can authenticate to GitHub over SSH, and applies the dotfiles repository
over SSH. It needs the OpenSSH client and a key registered on GitHub:

- On a local machine such as WSL, the key is taken from the SSH agent or
  from `~/.ssh`. A key with a passphrase must be loaded into an agent with
  `ssh-add` first.
- On a server, log in with agent forwarding from a machine whose agent
  holds the key, so that no GitHub credentials are stored on the server:

  ```bash
  ssh -A server
  ```

When authentication fails, the script says what to fix for the case at hand,
then asks whether to continue over HTTPS instead.

#### HTTPS

As on macOS, the script authenticates to GitHub with GitHub CLI through the
browser and applies the dotfiles repository over HTTPS. GitHub CLI is
installed to `~/.local/bin` from its latest release, and `git` is needed. On a
machine without a browser, such as a server, open
<https://github.com/login/device> on another machine and enter the one-time
code that GitHub CLI shows.

Unlike SSH, this stores a GitHub token on the machine: in the system keyring
when there is one, and otherwise in plain text in `~/.config/gh/hosts.yml`.
The token can read and write every repository the account can access.
`gh auth logout` removes it, after which chezmoi can no longer pull the
repository.

To use HTTPS without trying SSH first, which also avoids waiting for SSH to
time out where it is blocked:

```bash
DOTFILES_GIT_PROTOCOL=https /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/rigarash/dotfiles-bootstrap/main/install.sh)"
```

With `DOTFILES_GIT_PROTOCOL=ssh`, the script uses SSH only and does not offer
HTTPS.

#### First run

On first run, chezmoi asks for the email address for git and, except on WSL,
for the machine profile (`workstation` or `server`). The profile defaults to
`server` when logged in over SSH and to `workstation` otherwise.
