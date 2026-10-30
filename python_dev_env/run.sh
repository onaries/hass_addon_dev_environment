#!/bin/bash
set -euo pipefail
cd /

CONFIG_PATH=/data/options.json
USERNAME=$(jq -r '.username // "developer"' "$CONFIG_PATH")
SSH_PORT=$(jq -r '.ssh_port // 2322' "$CONFIG_PATH")
if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || [ "$USERNAME" = root ]; then
    echo "Invalid username" >&2
    exit 1
fi
if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || (( SSH_PORT < 1 || SSH_PORT > 65535 )); then
    echo "Invalid SSH port" >&2
    exit 1
fi

if ! id "$USERNAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$USERNAME"
    passwd -d "$USERNAME" >/dev/null
fi
usermod -aG sudo "$USERNAME"
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USERNAME" > "/etc/sudoers.d/$USERNAME"
chmod 440 "/etc/sudoers.d/$USERNAME"

if [ -S /var/run/docker.sock ]; then
    socket_gid=$(stat -c %g /var/run/docker.sock)
    socket_group=$(getent group "$socket_gid" | cut -d: -f1 || true)
    if [ -z "$socket_group" ]; then
        groupadd -g "$socket_gid" docker-access
        socket_group=docker-access
    fi
    usermod -aG "$socket_group" "$USERNAME"
else
    echo "Warning: Docker socket is not available"
fi

USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
mkdir -p "$USER_HOME/.ssh" /root/.ssh /data/ssh_host_keys /data/user_ssh_keys /data/workspace
chmod 700 "$USER_HOME/.ssh" /root/.ssh
chown "$USERNAME:$USERNAME" "$USER_HOME/.ssh" /data/user_ssh_keys

for key in /data/ssh_host_keys/ssh_host_*; do
    [ -f "$key" ] || continue
    cp -p "$key" /etc/ssh/
done
ssh-keygen -A
for key in /etc/ssh/ssh_host_*; do
    [ -e "/data/ssh_host_keys/${key##*/}" ] || cp -p "$key" /data/ssh_host_keys/
done

if [ ! -f /data/user_ssh_keys/id_ed25519 ]; then
    sudo -H -u "$USERNAME" ssh-keygen -q -t ed25519 -f /data/user_ssh_keys/id_ed25519 -N ""
fi
for name in id_ed25519 id_ed25519.pub config; do
    if [ -f "/data/user_ssh_keys/$name" ] && [ ! -e "$USER_HOME/.ssh/$name" ]; then
        ln -s "/data/user_ssh_keys/$name" "$USER_HOME/.ssh/$name"
    fi
done
if [ ! -e "$USER_HOME/.ssh/known_hosts" ] && [ -d /data/user_ssh_keys/known_hosts.d ]; then
    for file in /data/user_ssh_keys/known_hosts.d/*; do
        [ -f "$file" ] || continue
        cat "$file" >> "$USER_HOME/.ssh/known_hosts"
    done
fi
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"

git_name=$(jq -r '.git_name // ""' "$CONFIG_PATH")
git_email=$(jq -r '.git_email // ""' "$CONFIG_PATH")
if [ -n "$git_name" ]; then sudo -H -u "$USERNAME" git config --global user.name "$git_name"; fi
if [ -n "$git_email" ]; then sudo -H -u "$USERNAME" git config --global user.email "$git_email"; fi

if jq -e '.ssh_keys | type == "array" and length > 0' "$CONFIG_PATH" >/dev/null; then
    jq -r '.ssh_keys[]' "$CONFIG_PATH" > /root/.ssh/authorized_keys
    cp /root/.ssh/authorized_keys "$USER_HOME/.ssh/authorized_keys"
    chmod 600 /root/.ssh/authorized_keys "$USER_HOME/.ssh/authorized_keys"
    chown "$USERNAME:$USERNAME" "$USER_HOME/.ssh/authorized_keys"
fi
for account in root "$USERNAME"; do
    if [ "$account" = root ]; then field=password; else field=user_password; fi
    password=$(jq -r --arg field "$field" '.[$field] // ""' "$CONFIG_PATH")
    if [ -n "$password" ]; then printf '%s:%s\n' "$account" "$password" | chpasswd; fi
done
unset password

for item in config local; do
    target="/data/user_$item"
    [ -d "$target" ] || continue
    [ -e "$USER_HOME/.$item" ] || ln -s "$target" "$USER_HOME/.$item"
done
if [ ! -e /workspace ] && [ ! -L /workspace ]; then
    if [ -d /mnt/data/docker/volumes/ubuntu_data/_data ]; then
        ln -s /mnt/data/docker/volumes/ubuntu_data/_data /workspace
    elif [ -d /host/mnt/data/docker/volumes/ubuntu_data/_data ]; then
        ln -s /host/mnt/data/docker/volumes/ubuntu_data/_data /workspace
    else
        chown "$USERNAME:$USERNAME" /data/workspace
        ln -s /data/workspace /workspace
    fi
fi

mkdir -p /run/sshd
echo "Starting SSH on port $SSH_PORT"
exec /usr/sbin/sshd -D -e -p "$SSH_PORT" -o PermitRootLogin=yes -o PasswordAuthentication=yes -o PermitEmptyPasswords=no -o UsePAM=no -o "AllowUsers=root $USERNAME"
