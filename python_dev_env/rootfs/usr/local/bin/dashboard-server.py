#!/usr/bin/env python3
"""Status dashboard server for HA addon development environment."""

import json
import os
import re
import subprocess
import socketserver
from datetime import datetime
from http.server import SimpleHTTPRequestHandler
from pathlib import Path

import threading

PORT = int(os.environ.get("DASHBOARD_PORT", 8099))
EXT_PORT = int(os.environ.get("DASHBOARD_EXT_PORT", 0))
DASHBOARD_DIR = "/usr/local/share/dashboard"
USERNAME = os.environ.get("DASHBOARD_USER", "developer")
PROJECTS_DIR = "/workspace/projects"
ENV_SH = "source /etc/shell/env.sh 2>/dev/null"


class DashboardHandler(SimpleHTTPRequestHandler):
    """HTTP handler serving the dashboard and status API."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DASHBOARD_DIR, **kwargs)

    def do_GET(self):
        # Strip query string for routing
        parts = self.path.split("?", 1)
        path = parts[0]
        qs = dict(p.split("=", 1) for p in parts[1].split("&") if "=" in p) if len(parts) > 1 else {}

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
        elif path == "/api/projects":
            self._send_json(get_projects())
        elif path == "/api/logs":
            service = qs.get("service", "")
            lines = min(int(qs.get("lines", "300")), 1000)
            self._send_json(get_service_logs(service, lines))
        else:
            if path == "/":
                self.path = "/index.html"
            super().do_GET()

    def end_headers(self):
        # Prevent browser/ingress caching for all responses
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        super().end_headers()

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
    """Run a command as the configured non-root user with full env.sh PATH."""
    # Write command to a temp script to avoid shell quoting/escaping issues
    wrapped = f'{ENV_SH}\n{cmd}'
    try:
        r = subprocess.run(
            ["sudo", "-H", "-u", USERNAME, "bash"],
            input=wrapped,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd="/tmp",
        )
        return r.stdout.strip()
    except Exception:
        return ""


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
        "projects": get_projects(),
    }


_TOOL_SEPARATOR = ":::TOOL_SEP:::"

# (display name, command, icon, category)
TOOL_SPECS = [
    ("Python", "python3 --version 2>&1 | awk '{print $2}'", "python", "lang"),
    ("Node.js", "node --version 2>/dev/null", "nodejs", "lang"),
    ("npm", "npm --version 2>/dev/null", "npm", "lang"),
    ("Bun", "bun --version 2>/dev/null", "bun", "lang"),
    ("Rust", "rustc --version 2>/dev/null | awk '{print $2}'", "rust", "lang"),
    ("Go", "go version 2>/dev/null | awk '{print $3}' | sed 's/go//'", "go", "lang"),
    ("uv", "uv --version 2>/dev/null | awk '{print $2}'", "uv", "lang"),
    ("Docker", "docker --version 2>/dev/null | awk '{print $3}' | tr -d ','", "docker", "infra"),
    ("Neovim", "nvim --version 2>/dev/null | head -1 | awk '{print $2}'", "neovim", "tool"),
    ("Git", "git --version 2>/dev/null | awk '{print $3}'", "git", "tool"),
    ("GitHub CLI", "gh --version 2>/dev/null | head -1 | awk '{print $3}'", "github", "tool"),
    ("ripgrep", "rg --version 2>/dev/null | head -1 | awk '{print $2}'", "ripgrep", "tool"),
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
    ("Codex CLI", "codex --version 2>/dev/null | head -1", "codex", "ai"),
    ("OpenCode", "opencode version 2>/dev/null | head -1", "opencode", "ai"),
    ("OpenClaw", "openclaw --version 2>/dev/null | head -1", "openclaw", "ai"),
    ("Qwen Code", "qwen-code --version 2>/dev/null | head -1", "qwen", "ai"),
    ("git-ai-commit", "git-ai-commit --version 2>/dev/null | head -1", "gac", "ai"),
]


def get_tool_versions():
    """Detect installed tools and their versions in a single bash session."""
    # Build a single script that runs all version checks separated by markers
    sep = _TOOL_SEPARATOR
    script_lines = [ENV_SH]
    for _, cmd, _, _ in TOOL_SPECS:
        script_lines.append(f'echo "{sep}"')
        script_lines.append(cmd)
    script = "\n".join(script_lines)

    try:
        r = subprocess.run(
            ["sudo", "-H", "-u", USERNAME, "bash"],
            input=script,
            capture_output=True,
            text=True,
            timeout=30,
            cwd="/tmp",
        )
        raw = r.stdout
    except Exception:
        raw = ""

    # Parse output: split by separator, skip the first empty chunk
    chunks = raw.split(sep)
    # First chunk is any output before the first separator (bash login banner etc.)
    versions = [c.strip() for c in chunks[1:]] if len(chunks) > 1 else []

    tools = []
    for i, (name, _, icon_id, category) in enumerate(TOOL_SPECS):
        version = versions[i] if i < len(versions) else ""
        installed = bool(version) and "not found" not in version.lower()
        tools.append({
            "name": name,
            "version": version if installed else None,
            "icon": icon_id,
            "category": category,
            "installed": installed,
        })

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


def get_projects():
    """List project directories under PROJECTS_DIR with git info and modification time."""
    projects_path = Path(PROJECTS_DIR)
    if not projects_path.is_dir():
        return []

    projects = []
    for entry in projects_path.iterdir():
        if not entry.is_dir() or entry.name.startswith("."):
            continue

        # Get most recent modification time (latest commit or file change)
        git_dir = entry / ".git"
        last_modified = None
        branch = None

        if git_dir.exists():
            # Use git log for accurate last-activity time
            ts = _run(
                f"git -C {entry} log -1 --format=%ct 2>/dev/null"
            )
            if ts and ts.isdigit():
                last_modified = datetime.fromtimestamp(int(ts)).isoformat()
            # Current branch
            branch = _run(
                f"git -C {entry} rev-parse --abbrev-ref HEAD 2>/dev/null"
            )

        if not last_modified:
            # Fallback: directory mtime
            try:
                mtime = entry.stat().st_mtime
                last_modified = datetime.fromtimestamp(mtime).isoformat()
            except OSError:
                last_modified = None

        projects.append({
            "name": entry.name,
            "path": str(entry),
            "git": git_dir.exists(),
            "branch": branch or None,
            "last_modified": last_modified,
        })

    # Sort by last_modified descending (most recent first)
    projects.sort(key=lambda p: p["last_modified"] or "", reverse=True)
    return projects


LOG_DIR = Path("/var/log/supervisor")


def get_service_logs(service, lines=300):
    """Read the last N lines from a service's supervisor log files."""
    if not service or not re.match(r"^[a-zA-Z0-9_-]+$", service):
        # Return available log services when no service specified
        return {"services": _list_log_services(), "lines": []}

    stdout_log = LOG_DIR / f"{service}.log"
    stderr_log = LOG_DIR / f"{service}_err.log"

    result = []

    # Read stdout log
    if stdout_log.is_file():
        result.extend(_tail_file(stdout_log, lines))

    # Append stderr lines tagged with [ERR]
    if stderr_log.is_file():
        for line in _tail_file(stderr_log, lines):
            if line and not line.startswith("[ERR]"):
                line = "[ERR] " + line
            result.append(line)

    # Sort by timestamp if lines start with common timestamp patterns
    # Otherwise keep stdout first, stderr appended
    result = result[-(lines):]

    return {
        "service": service,
        "services": _list_log_services(),
        "lines": result,
        "total": len(result),
    }


def _tail_file(filepath, lines=300):
    """Read the last N lines from a file."""
    try:
        raw = _run(f"tail -n {lines} {filepath} 2>/dev/null")
        return raw.splitlines() if raw else []
    except Exception:
        return []


def _list_log_services():
    """List available service names from supervisor log directory."""
    if not LOG_DIR.is_dir():
        return []
    services = set()
    for f in LOG_DIR.iterdir():
        if f.suffix == ".log" and f.is_file():
            # sshd.log → sshd, sshd_err.log → skip (covered by sshd.log)
            name = f.stem
            if name.endswith("_err"):
                name = name[:-4]
            if name != "supervisord":
                services.add(name)
    return sorted(services)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True

    # Ingress server (HA internal)
    httpd = socketserver.TCPServer(("", PORT), DashboardHandler)
    print(f"Dashboard server listening on port {PORT} (ingress)")

    # External server on a separate port if configured
    if EXT_PORT and EXT_PORT != PORT:
        httpd_ext = socketserver.TCPServer(("", EXT_PORT), DashboardHandler)
        print(f"Dashboard server listening on port {EXT_PORT} (external)")
        threading.Thread(target=httpd_ext.serve_forever, daemon=True).start()

    httpd.serve_forever()
