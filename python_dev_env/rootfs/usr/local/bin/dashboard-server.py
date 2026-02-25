#!/usr/bin/env python3
"""Status dashboard server for HA addon development environment."""

import json
import os
import re
import subprocess
import socketserver
from datetime import datetime
from http.server import SimpleHTTPRequestHandler

PORT = int(os.environ.get("DASHBOARD_PORT", 8099))
DASHBOARD_DIR = "/usr/local/share/dashboard"
USERNAME = os.environ.get("DASHBOARD_USER", "developer")
NVM_SH = "source /opt/nvm/nvm.sh 2>/dev/null"
CARGO_ENV = "source /data/rust_cargo/cargo/env 2>/dev/null"


class DashboardHandler(SimpleHTTPRequestHandler):
    """HTTP handler serving the dashboard and status API."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DASHBOARD_DIR, **kwargs)

    def do_GET(self):
        # Strip query string for routing
        path = self.path.split("?")[0]

        if path == "/api/status":
            self._send_json(collect_all())
        elif path == "/api/tools":
            self._send_json(get_tool_versions())
        elif path == "/api/services":
            self._send_json(get_service_status())
        elif path == "/api/logins":
            self._send_json(get_recent_logins())
        elif path == "/api/tmux":
            self._send_json(get_tmux_sessions())
        else:
            if path == "/":
                self.path = "/index.html"
            super().do_GET()

    def _send_json(self, data):
        body = json.dumps(data, ensure_ascii=False, default=str).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        # Suppress noisy access logs
        pass


# ---------------------------------------------------------------------------
# Data collection helpers
# ---------------------------------------------------------------------------


def _run(cmd, timeout=10):
    """Run a shell command and return stdout, or empty string on failure."""
    try:
        r = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return r.stdout.strip()
    except Exception:
        return ""


def _run_as_user(cmd, timeout=10):
    """Run a command as the configured non-root user."""
    return _run(f"sudo -u {USERNAME} bash -lc '{cmd}'", timeout=timeout)


def collect_all():
    """Aggregate every status section into one response."""
    return {
        "timestamp": datetime.now().isoformat(),
        "hostname": _run("hostname") or "unknown",
        "uptime": (_run("uptime -p") or "").replace("up ", ""),
        "username": USERNAME,
        "tools": get_tool_versions(),
        "services": get_service_status(),
        "recent_logins": get_recent_logins(),
        "tmux_sessions": get_tmux_sessions(),
    }


def get_tool_versions():
    """Detect installed tools and their versions."""
    specs = [
        # (display name, command, icon, category)
        ("Python", "python3 --version 2>&1 | awk '{print $2}'", "python", "lang"),
        ("Node.js", f"{NVM_SH}; node --version 2>/dev/null", "nodejs", "lang"),
        ("npm", f"{NVM_SH}; npm --version 2>/dev/null", "npm", "lang"),
        ("Bun", "bun --version 2>/dev/null", "bun", "lang"),
        (
            "Rust",
            f"{CARGO_ENV}; rustc --version 2>/dev/null | awk '{{print $2}}'",
            "rust",
            "lang",
        ),
        (
            "Go",
            "go version 2>/dev/null | awk '{print $3}' | sed 's/go//'",
            "go",
            "lang",
        ),
        ("uv", "uv --version 2>/dev/null | awk '{print $2}'", "uv", "lang"),
        (
            "Docker",
            "docker --version 2>/dev/null | awk '{print $3}' | tr -d ','",
            "docker",
            "infra",
        ),
        (
            "Neovim",
            "nvim --version 2>/dev/null | head -1 | awk '{print $2}'",
            "neovim",
            "tool",
        ),
        ("Git", "git --version 2>/dev/null | awk '{print $3}'", "git", "tool"),
        (
            "GitHub CLI",
            "gh --version 2>/dev/null | head -1 | awk '{print $3}'",
            "github",
            "tool",
        ),
        (
            "ripgrep",
            "rg --version 2>/dev/null | head -1 | awk '{print $2}'",
            "ripgrep",
            "tool",
        ),
        ("fzf", "fzf --version 2>/dev/null | awk '{print $1}'", "fzf", "tool"),
        ("zellij", "zellij --version 2>/dev/null | awk '{print $2}'", "zellij", "tool"),
        ("tmux", "tmux -V 2>/dev/null | awk '{print $2}'", "tmux", "tool"),
        ("delta", "delta --version 2>/dev/null | awk '{print $2}'", "delta", "tool"),
        ("lsd", "lsd --version 2>/dev/null | awk '{print $2}'", "lsd", "tool"),
        ("mcfly", "mcfly --version 2>/dev/null | awk '{print $2}'", "mcfly", "tool"),
        ("zoxide", "zoxide --version 2>/dev/null | awk '{print $2}'", "zoxide", "tool"),
        ("just", "just --version 2>/dev/null | awk '{print $2}'", "just", "tool"),
        ("duf", "duf --version 2>/dev/null | awk '{print $2}'", "duf", "tool"),
        ("GitUI", "gitui --version 2>/dev/null | awk '{print $2}'", "gitui", "tool"),
        ("act", "act --version 2>/dev/null | awk '{print $3}'", "act", "tool"),
        ("Claude CLI", "claude --version 2>/dev/null | head -1", "claude", "ai"),
        (
            "Codex CLI",
            f"{NVM_SH}; codex --version 2>/dev/null | head -1",
            "codex",
            "ai",
        ),
        ("OpenCode", "opencode version 2>/dev/null | head -1", "opencode", "ai"),
        (
            "OpenClaw",
            f"{NVM_SH}; openclaw --version 2>/dev/null | head -1",
            "openclaw",
            "ai",
        ),
        (
            "Qwen Code",
            f"{NVM_SH}; qwen-code --version 2>/dev/null | head -1",
            "qwen",
            "ai",
        ),
        (
            "git-ai-commit",
            f"{NVM_SH}; git-ai-commit --version 2>/dev/null | head -1",
            "gac",
            "ai",
        ),
    ]

    tools = []
    for name, cmd, icon_id, category in specs:
        # User-space tools (NVM, Cargo, user-installed CLIs) run as user
        if any(k in cmd for k in [NVM_SH, CARGO_ENV, "zoxide", "claude", "opencode"]):
            version = _run_as_user(cmd)
        else:
            version = _run(cmd)

        installed = bool(version) and "not found" not in version.lower()
        tools.append(
            {
                "name": name,
                "version": version if installed else None,
                "icon": icon_id,
                "category": category,
                "installed": installed,
            }
        )

    return tools


def get_service_status():
    """Parse supervisorctl status output."""
    raw = _run("supervisorctl status 2>/dev/null")
    services = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        # Format: NAME   STATE   pid PID, uptime H:MM:SS
        parts = line.split()
        if len(parts) >= 2:
            name = parts[0]
            status = parts[1]
            # Extract pid and uptime from remaining info
            info = " ".join(parts[2:])
            pid = None
            uptime = None
            pid_match = re.search(r"pid\s+(\d+)", info)
            if pid_match:
                pid = int(pid_match.group(1))
            uptime_match = re.search(r"uptime\s+([\d:]+)", info)
            if uptime_match:
                uptime = uptime_match.group(1)
            services.append(
                {
                    "name": name,
                    "status": status,
                    "pid": pid,
                    "uptime": uptime,
                    "info": info,
                }
            )
    return services


def get_recent_logins():
    """Parse last command output for recent SSH logins."""
    raw = _run("last -n 30 -w 2>/dev/null")
    logins = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("wtmp") or line.startswith("reboot"):
            continue
        parts = line.split()
        if len(parts) < 4:
            continue
        user = parts[0]
        terminal = parts[1]
        # IP is present if login is from network
        if re.match(r"\d+\.\d+\.\d+\.\d+", parts[2]):
            ip = parts[2]
            time_parts = parts[3:]
        else:
            ip = "local"
            time_parts = parts[2:]
        logins.append(
            {
                "user": user,
                "terminal": terminal,
                "ip": ip,
                "time": " ".join(time_parts[:4]),
                "status": " ".join(time_parts[4:]) if len(time_parts) > 4 else "",
            }
        )
    return logins[:20]


def get_tmux_sessions():
    """List tmux sessions for the configured user."""
    raw = _run_as_user("tmux list-sessions 2>/dev/null")
    sessions = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        # Format: name: N windows (created ...) (attached)
        match = re.match(
            r"^(.+?):\s+(\d+)\s+windows?\s+\(created\s+(.+?)\)\s*(\(attached\))?",
            line.strip(),
        )
        if match:
            sessions.append(
                {
                    "name": match.group(1),
                    "windows": int(match.group(2)),
                    "created": match.group(3),
                    "attached": bool(match.group(4)),
                }
            )
        else:
            sessions.append(
                {
                    "name": line.split(":")[0] if ":" in line else line,
                    "windows": 0,
                    "created": "",
                    "attached": False,
                    "raw": line.strip(),
                }
            )
    return sessions


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), DashboardHandler) as httpd:
        print(f"Dashboard server listening on port {PORT}")
        httpd.serve_forever()
