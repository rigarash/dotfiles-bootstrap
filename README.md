# dotfiles-bootstrap

Minimal macOS bootstrap for the private
[`rigarash/dotfiles`](https://github.com/rigarash/dotfiles) repository.

The script installs Homebrew when needed, installs GitHub CLI and chezmoi,
authenticates to GitHub through the browser, and applies the private dotfiles
repository.

## Usage

Review [`install.sh`](./install.sh), then run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/rigarash/dotfiles-bootstrap/main/install.sh)"
```

GitHub authentication requires confirmation in a browser on a new machine.
No access token or SSH private key is stored in this repository.

To use another private repository:

```bash
DOTFILES_REPOSITORY=owner/repository /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/rigarash/dotfiles-bootstrap/main/install.sh)"
```
