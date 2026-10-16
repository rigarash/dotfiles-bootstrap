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

The script adds GitHub's SSH host keys to `~/.ssh/known_hosts`, checks that
it can authenticate to GitHub over SSH, installs the chezmoi binary to
`~/.local/bin` without root privileges, and applies the dotfiles repository
over SSH. It needs `curl`, the OpenSSH client, and a key registered on GitHub:

- On a local machine such as WSL, the key is taken from the SSH agent or
  from `~/.ssh`. A key with a passphrase must be loaded into an agent with
  `ssh-add` first.
- On a server, log in with agent forwarding from a machine whose agent
  holds the key, so that no GitHub credentials are stored on the server:

  ```bash
  ssh -A server
  ```

When authentication fails, the script says what to fix for the case at hand.

On first run, chezmoi asks for the email address for git and, except on WSL,
for the machine profile (`workstation` or `server`). The profile defaults to
`server` when logged in over SSH and to `workstation` otherwise.
