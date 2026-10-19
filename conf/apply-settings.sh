#!/usr/bin/env bash
# JSON serialization, merge and atomic replacement are handled by Python.
set -euo pipefail
export OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-/root/.config/opencode}"
export OPENCODE_AUTH_DIR="${OPENCODE_AUTH_DIR:-/root/.local/share/opencode}"
exec python3 - <<'PYTHON'
import copy
import json
import os
from pathlib import Path
import re
import tempfile
from urllib.parse import urlsplit

def value(name, default=""):
    return os.environ.get(name, default)

def require(name):
    v = value(name)
    if not v or any(ord(c) < 32 for c in v):
        raise ValueError("Missing or invalid " + name)
    return v

def identifier(name):
    v = require(name)
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", v):
        raise ValueError("Invalid provider identifier: " + name)
    return v

def endpoint(name):
    v = require(name)
    u = urlsplit(v)
    if u.scheme not in ("http", "https") or not u.hostname or u.username or u.password:
        raise ValueError("Invalid endpoint: " + name)
    return v

def load(path):
    if not path.exists():
        return {}
    obj = json.loads(path.read_text())
    if not isinstance(obj, dict):
        raise ValueError("Expected JSON object")
    return obj

def atomic(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".darkmoon-")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(obj, f, ensure_ascii=False, indent=2)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

def merge(dst, src):
    for k, v in src.items():
        if isinstance(v, dict) and isinstance(dst.get(k), dict):
            merge(dst[k], v)
        else:
            dst[k] = copy.deepcopy(v)
    return dst

AGENTS = json.loads(r'''{
  "pentest": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "primary": true,
    "prompt_file": "/root/.opencode/agents/pentest.md"
  },
  "aws": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/aws.md"
  },
  "azure": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/azure.md"
  },
  "entra-id": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/entra-id.md"
  },
  "gcp": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/gcp.md"
  },
  "github": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/github.md"
  },
  "gitlab": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/gitlab.md"
  },
  "jenkins": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/jenkins.md"
  },
  "terraform": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/terraform.md"
  },
  "ansible": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/ansible.md"
  },
  "docker": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/docker.md"
  },
  "container-registry": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/container-registry.md"
  },
  "hashicorp-vault": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/hashicorp-vault.md"
  },
  "sql-databases": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/sql-databases.md"
  },
  "messaging-cache": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/messaging-cache.md"
  },
  "firmware": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/firmware.md"
  },
  "sso-idp": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/sso-idp.md"
  },
  "gitops": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/gitops.md"
  },
  "observability": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/observability.md"
  },
  "storage": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/storage.md"
  },
  "edge-proxy": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/edge-proxy.md"
  },
  "vpn-remote-access": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/vpn-remote-access.md"
  },
  "firewall-network": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/firewall-network.md"
  },
  "email-infrastructure": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/email-infrastructure.md"
  },
  "backup": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/backup.md"
  },
  "pki-adcs": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/pki-adcs.md"
  },
  "nosql-databases": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/nosql-databases.md"
  },
  "container-platform": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/container-platform.md"
  },
  "hypervisor": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/hypervisor.md"
  },
  "business-platforms": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/business-platforms.md"
  },
  "mobile": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/mobile.md"
  },
  "mdm": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/mdm.md"
  },
  "active-directory": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/ad.md"
  },
  "aspnet": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/aspnet.md"
  },
  "python-flask": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/flask.md"
  },
  "graphql": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/graphql.md"
  },
  "llm": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/llm.md"
  },
  "golang": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/golang.md"
  },
  "headless-browser": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/headless-browser.md"
  },
  "kubernetes": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/kubernetes.md"
  },
  "nest": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/nest.md"
  },
  "php": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/php.md"
  },
  "ruby-on-rails": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/ruby.md"
  },
  "springboot": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/springboot.md"
  },
  "nodejs": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/nodejs-express-angular.md"
  },
  "wordpress": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/wordpress.md"
  },
  "prestashop": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/prestashop.md"
  },
  "moodle": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/moodle.md"
  },
  "magento": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/magento.md"
  },
  "joomla": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/joomla.md"
  },
  "drupal": {
    "model": "__MODEL__",
    "mcp": [
      "darkmoon"
    ],
    "secondary": true,
    "prompt_file": "/root/.opencode/agents/drupal.md"
  }
}''')

def configure():
    mode = value("OPENCODE_AUTH_MODE", "managed")
    if mode not in ("existing", "managed"):
        raise ValueError("OPENCODE_AUTH_MODE must be existing or managed")
    local = value("OPENCODE_LOCAL_MODE", "false")
    if local not in ("true", "false"):
        raise ValueError("OPENCODE_LOCAL_MODE must be true or false")
    provider = {}
    auth_update = None
    if mode == "existing":
        model = require("OPENCODE_MODEL")
        if "/" not in model or not all(model.split("/", 1)):
            raise ValueError("Existing mode requires provider/model")
    elif local == "true":
        pid = identifier("OPENCODE_LOCAL_PROVIDER_ID")
        name = require("OPENCODE_LOCAL_MODEL")
        model = pid + "/" + name
        # Never carry a previous endpoint's key over to a newly selected URL.
        options = {"baseURL": endpoint("OPENCODE_LOCAL_BASE_URL"),
                   "apiKey": value("OPENCODE_LOCAL_API_KEY")}
        provider[pid] = {"npm": "@ai-sdk/openai-compatible",
                         "name": value("OPENCODE_LOCAL_PROVIDER_NAME", "Local model"),
                         "options": options, "models": {name: {"name": name}}}
    elif value("ANTHROPIC_BASE_URL") or value("ANTHROPIC_MODEL"):
        endpoint("ANTHROPIC_BASE_URL")
        name = require("ANTHROPIC_MODEL")
        model = "anthropic/" + name
        provider["anthropic"] = {"models": {name: {"name": name}}}
    elif value("OPENROUTER_PROVIDER") or value("OPENROUTER_API_KEY"):
        pid = identifier("OPENROUTER_PROVIDER")
        name = require("OPENCODE_MODEL")
        key = require("OPENROUTER_API_KEY")
        model = pid + "/" + name
        auth_update = (pid, {"type": "api", "key": key})
    else:
        model = "opencode/big-pickle"
    transport = value("DARKMOON_MCP_TRANSPORT", "http")
    if transport == "stdio":
        mcp = {"type": "local", "command": ["/usr/local/bin/darkmoon-mcp"],
               "timeout": 36000000, "enabled": True}
    elif transport == "http":
        port = int(value("DARKMOON_MCP_PORT", "8181"))
        if not 1 <= port <= 65535:
            raise ValueError("Invalid MCP port")
        host = value("DARKMOON_MCP_HOST", "127.0.0.1")
        path = value("DARKMOON_MCP_PATH", "/mcp")
        if not re.fullmatch(r"[A-Za-z0-9_.-]+", host) or not path.startswith("/"):
            raise ValueError("Invalid MCP address")
        mcp = {"type": "remote", "url": f"http://{host}:{port}{path}", "enabled": True}
    else:
        raise ValueError("Invalid MCP transport")
    config_path = Path(value("OPENCODE_CONFIG_DIR")) / "opencode.json"
    auth_path = Path(value("OPENCODE_AUTH_DIR")) / "auth.json"
    config = load(config_path)
    # Validate all inputs before writing either file. Existing mode never reads auth.
    auth = load(auth_path) if auth_update else None
    for k in ("provider", "mcp", "agent"):
        if k in config and not isinstance(config[k], dict):
            raise ValueError("Invalid configuration field: " + k)
    plugins = config.get("plugin", [])
    if not isinstance(plugins, list):
        raise ValueError("plugin must be an array")
    config.setdefault("$schema", "https://opencode.ai/config.json")
    config.update(model=model, small_model=model)
    merge(config.setdefault("provider", {}), provider)
    # Security fields are user-owned. Never replace permission policies, including
    # nested agent policies. Darkmoon owns model, MCP wiring and default prompts.
    config.setdefault("permission", {"*": "ask"})
    for name, defaults in AGENTS.items():
        agent = config.setdefault("agent", {}).setdefault(name, {})
        if not isinstance(agent, dict):
            raise ValueError("Invalid agent configuration")
        # Current OpenCode uses mode/prompt; retain legacy fields for older builds.
        agent.setdefault("mode", "primary" if defaults.get("primary") else "subagent")
        agent.setdefault("prompt", "{file:" + defaults["prompt_file"] + "}")
        for k, v in defaults.items():
            agent.setdefault(k, copy.deepcopy(v))
        agent["model"] = model
    previous_mcp = config.setdefault("mcp", {}).get("darkmoon", {})
    if isinstance(previous_mcp, dict) and "enabled" in previous_mcp:
        mcp["enabled"] = previous_mcp["enabled"]
    config["mcp"]["darkmoon"] = mcp
    config["plugin"] = []
    for plugin in plugins + [
        "file:///opt/darkmoon/plugins/darkmoon-privacy.ts",
        "file:///opt/darkmoon/plugins/darkmoon-growth-cta.ts"]:
        if plugin not in config["plugin"]:
            config["plugin"].append(copy.deepcopy(plugin))
    if auth_update:
        auth[auth_update[0]] = auth_update[1]
        atomic(auth_path, auth)
    atomic(config_path, config)
    print("[INIT] Configuration applied; existing credentials retained")

try:
    configure()
except (ValueError, OSError, TypeError):
    # Never echo invalid input or parser diagnostics: they can contain secrets.
    raise SystemExit("[INIT] Invalid configuration or inaccessible file; no credential values logged")
PYTHON
