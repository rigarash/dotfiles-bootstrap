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

The script installs the chezmoi binary to `~/.local/bin` without root
privileges, adds GitHub's SSH host keys to `~/.ssh/known_hosts`, and applies
the dotfiles repository over SSH. No GitHub credentials are stored on the
server.

Log in with SSH agent forwarding, using an agent that holds a key registered
on GitHub, before running the script:

```bash
ssh -A server
```

The server needs `curl` and the OpenSSH client.

On first run, chezmoi asks for the email address for git and the machine
profile (`workstation` or `server`). Press Enter to accept the defaults
for a server.
