# Home Assistant Add-on: Python Development Environment

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
![Supports armhf Architecture][armhf-shield]
![Supports armv7 Architecture][armv7-shield]
![Supports i386 Architecture][i386-shield]

A comprehensive Python 3.13 development environment for Home Assistant with SSH access, modern shell (zsh + oh-my-zsh), Neovim with LazyVim, and essential development tools.

## About

This add-on provides a full-featured development environment including:

- **Python 3.13**: Latest Python version
- **SSH Access**: Secure remote access via configurable port
- **Modern Shell**: zsh with oh-my-zsh configuration  
- **Editor**: Neovim with LazyVim pre-configured
- **Node.js**: Via nvm with latest LTS version
- **Terminal Multiplexer**: Zellij for session management
- **Docker Access**: Docker socket mounted for container operations
- **File Access**: Home Assistant config, addons, and shared directories

## Important Setup Requirements

⚠️ **This addon requires Home Assistant Protection Mode to be disabled** due to its need for Docker API access and system-level permissions.

1. Go to **Settings** → **Add-ons** → **Advanced**
2. Disable **Protection mode**
3. Restart Home Assistant
4. Install and configure this addon

## Configuration

### Option: `ssh_keys`

Add one or more SSH public keys to allow passwordless SSH access.

```yaml
ssh_keys:
  - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEa+wW1Vb5pEJ2qQ..."
```

### Option: `password`

Set a password for the root user (optional if using SSH keys).

```yaml
password: "mypassword"
```

### Option: `ssh_port`

Configure the SSH port (default: 2322).

```yaml
ssh_port: 2322
```

### Option: `username`

Set the development user name (default: "developer").

```yaml
username: "developer"
```

### Option: `user_password`

Set a password for the development user.

```yaml
user_password: "devpassword"
```

## Support

Got questions?

You could [open an issue here][issue] on GitHub.

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[armhf-shield]: https://img.shields.io/badge/armhf-yes-green.svg
[armv7-shield]: https://img.shields.io/badge/armv7-yes-green.svg
[i386-shield]: https://img.shields.io/badge/i386-yes-green.svg
[issue]: https://github.com/yourusername/hass-python-dev-addon/issues