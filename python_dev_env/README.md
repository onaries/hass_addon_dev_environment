# SSH and Docker

This add-on provides SSH, Docker CLI and Docker Compose. It does not start OpenClaw, CLIProxyAPI, Syncthing, the dashboard, or other previous services. The default SSH port is 2322; `ssh_port` changes the listening port. Since the add-on uses host networking, ensure the chosen port is available.

Configure `username`, `ssh_keys`, `user_password` and, if needed, the root `password` in the app configuration. Git identity options remain supported. Existing options for removed services are accepted for compatibility but are ignored.

The existing `/data/ssh_host_keys`, `/data/user_ssh_keys`, `/data/user_config`, `/data/user_local`, and `/data/workspace` data are retained. Other existing `/data` directories are not deleted. `/workspace` uses an existing accessible `ubuntu_data` volume when present, otherwise `/data/workspace`.

Docker commands use the Home Assistant Docker socket exposed through the add-on's `docker_api` permission. A missing socket is reported at startup. The add-on requires protection mode disabled for Docker access. The configured user has passwordless sudo, as in the previous version.

The default shell is Bash for newly created users. SSH host keys, user keys, password and authorized keys must be backed up through the normal Home Assistant backup before upgrading.
