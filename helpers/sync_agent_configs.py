#!/usr/bin/env python3
"""Synchronize shared AI agent skills, rules, subagents, and MCP servers from ~/.agents."""

import json
import os
import re
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
AGENTS_DIR = os.path.join(HOME, ".agents")
CLAUDE_DIR = os.path.join(HOME, ".claude")
GEMINI_DIR = os.path.join(HOME, ".gemini")
GEMINI_CONFIG_DIR = os.path.join(GEMINI_DIR, "config")
SCRIPT_PATH = os.path.abspath(__file__)


def write_if_changed(path: str, content: str) -> bool:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.isfile(path) and not os.path.islink(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                if f.read() == content:
                    return False
        except OSError:
            pass
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return True


def ensure_relative_symlink(link_path: str, target_abs: str) -> bool:
    parent_dir = os.path.dirname(link_path)
    os.makedirs(parent_dir, exist_ok=True)
    rel_target = os.path.relpath(target_abs, parent_dir)
    if os.path.islink(link_path) and os.readlink(link_path) == rel_target:
        return False
    if os.path.lexists(link_path):
        if os.path.isdir(link_path) and not os.path.islink(link_path):
            shutil.rmtree(link_path)
        else:
            os.unlink(link_path)
    os.symlink(rel_target, link_path)
    return True


def clean_sync_conflicts() -> None:
    for root_dir in (AGENTS_DIR, CLAUDE_DIR, GEMINI_DIR):
        if not os.path.exists(root_dir):
            continue
        for dirpath, _, filenames in os.walk(root_dir):
            for fn in filenames:
                if ".sync-conflict-" in fn:
                    try:
                        os.unlink(os.path.join(dirpath, fn))
                    except OSError:
                        pass


def patch_unslop_frontmatter(canonical_skills: str) -> None:
    unslop_md = os.path.join(canonical_skills, "unslop", "SKILL.md")
    if not os.path.isfile(unslop_md):
        return
    with open(unslop_md, "r", encoding="utf-8") as f:
        content = f.read()
    updated = re.sub(
        r"^---\nname:\s*unslop\ndescription:.*?\n(?:disable-model-invocation:.*?\n)?---",
        "---\nname: unslop\ndescription: Cut AI tells from any writing. Must always apply.\n---",
        content,
        count=1,
        flags=re.DOTALL,
    )
    if updated != content:
        with open(unslop_md, "w", encoding="utf-8") as f:
            f.write(updated)


def sync_skills() -> None:
    canonical = os.path.join(AGENTS_DIR, "skills")
    os.makedirs(canonical, exist_ok=True)
    target_dirs = [
        os.path.join(GEMINI_CONFIG_DIR, "skills"),
        os.path.join(GEMINI_DIR, "skills"),
        os.path.join(GEMINI_DIR, "antigravity", "skills"),
        os.path.join(CLAUDE_DIR, "skills"),
    ]

    for src_root in target_dirs:
        if not os.path.isdir(src_root) or os.path.islink(src_root):
            continue
        for name in sorted(os.listdir(src_root)):
            if name.startswith(".") or name == "synced":
                continue
            src_path = os.path.join(src_root, name)
            if os.path.islink(src_path) or not os.path.isdir(src_path):
                continue
            dst_path = os.path.join(canonical, name)
            src_md = os.path.join(src_path, "SKILL.md")
            dst_md = os.path.join(dst_path, "SKILL.md")
            if not os.path.exists(dst_path):
                shutil.copytree(src_path, dst_path, symlinks=True)
            elif name != "unslop" and os.path.exists(src_md) and os.path.exists(dst_md):
                if os.path.getmtime(src_md) > os.path.getmtime(dst_md):
                    shutil.rmtree(dst_path)
                    shutil.copytree(src_path, dst_path, symlinks=True)

    patch_unslop_frontmatter(canonical)

    skills = [
        s
        for s in sorted(os.listdir(canonical))
        if not s.startswith(".") and os.path.isdir(os.path.join(canonical, s))
    ]
    for tdir in target_dirs:
        os.makedirs(tdir, exist_ok=True)
        for s in skills:
            dst = os.path.join(tdir, s)
            src = os.path.join(canonical, s)
            ensure_relative_symlink(dst, src)


def sync_rules_and_agents() -> None:
    rules_dir = os.path.join(AGENTS_DIR, "rules")
    agents_sub_dir = os.path.join(AGENTS_DIR, "agents")
    agents_md = os.path.join(AGENTS_DIR, "AGENTS.md")
    os.makedirs(rules_dir, exist_ok=True)
    os.makedirs(agents_sub_dir, exist_ok=True)

    scripts_link = os.path.join(agents_sub_dir, "scripts")
    scripts_target = os.path.join(HOME, "Documents", "cases", ".gemini", "agents", "scripts")
    if os.path.lexists(scripts_link) and os.path.islink(scripts_link):
        ensure_relative_symlink(scripts_link, scripts_target)

    if os.path.isfile(agents_md):
        ensure_relative_symlink(os.path.join(GEMINI_DIR, "GEMINI.md"), agents_md)
        ensure_relative_symlink(os.path.join(GEMINI_CONFIG_DIR, "AGENTS.md"), agents_md)
        ensure_relative_symlink(os.path.join(CLAUDE_DIR, "AGENTS.md"), agents_md)

    ensure_relative_symlink(os.path.join(GEMINI_CONFIG_DIR, "rules"), rules_dir)
    ensure_relative_symlink(os.path.join(CLAUDE_DIR, "rules"), rules_dir)
    ensure_relative_symlink(os.path.join(GEMINI_CONFIG_DIR, "agents"), agents_sub_dir)
    ensure_relative_symlink(os.path.join(CLAUDE_DIR, "agents"), agents_sub_dir)

    claude_md = os.path.join(CLAUDE_DIR, "CLAUDE.md")
    desired_imports = (
        "@AGENTS.md\n"
        "@rules/homelab_topology_and_power_safety.md\n"
        "@rules/typesafe_efficiency.md\n"
    )
    write_if_changed(claude_md, desired_imports)


def sync_mcp() -> None:
    agents_mcp_path = os.path.join(AGENTS_DIR, "mcp_config.json")
    gemini_mcp_path = os.path.join(GEMINI_CONFIG_DIR, "mcp_config.json")
    if not os.path.isfile(agents_mcp_path):
        return
    ensure_relative_symlink(gemini_mcp_path, agents_mcp_path)

    try:
        with open(agents_mcp_path, "r", encoding="utf-8") as f:
            agents_data = json.load(f)
    except Exception:
        return
    merged_mcp = agents_data.setdefault("mcpServers", {})

    claude_json_path = os.path.join(HOME, ".claude.json")
    if not os.path.isfile(claude_json_path):
        return
    try:
        with open(claude_json_path, "r", encoding="utf-8") as f:
            cdata = json.load(f)
    except Exception:
        return

    cservers = cdata.setdefault("mcpServers", {})
    agents_changed = False
    claude_changed = False

    # 1. Reverse sync: import newly added stdio or Streamable HTTP servers from ~/.claude.json -> ~/.agents/mcp_config.json
    for name, ccfg in cservers.items():
        if name in merged_mcp:
            continue
        ctype = ccfg.get("type", "")
        if "command" in ccfg:
            entry = {"command": ccfg["command"], "args": ccfg.get("args", [])}
            if ccfg.get("env"):
                entry["env"] = ccfg["env"]
            merged_mcp[name] = entry
            agents_changed = True
        elif ctype == "http" and "url" in ccfg and not ccfg["url"].endswith("/sse"):
            entry = {"serverUrl": ccfg["url"]}
            if ccfg.get("headers"):
                entry["headers"] = ccfg["headers"]
            merged_mcp[name] = entry
            agents_changed = True

    # 2. Forward sync: propagate active servers from ~/.agents/mcp_config.json -> ~/.claude.json
    for name, cfg in merged_mcp.items():
        if cfg.get("disabled"):
            continue
        if "command" in cfg:
            entry = {"type": "stdio", "command": cfg["command"], "args": cfg.get("args", [])}
            if "env" in cfg:
                entry["env"] = cfg["env"]
            elif name in cservers and "env" in cservers[name]:
                entry["env"] = cservers[name]["env"]
            if cservers.get(name) != entry:
                cservers[name] = entry
                claude_changed = True
        elif "serverUrl" in cfg or "url" in cfg:
            remote_url = cfg.get("serverUrl") or cfg.get("url")
            existing_url = cservers.get(name, {}).get("url")
            entry = {"type": "http", "url": existing_url or remote_url}
            if "headers" in cfg:
                entry["headers"] = cfg["headers"]
            if cservers.get(name) != entry:
                cservers[name] = entry
                claude_changed = True

    if agents_changed:
        write_if_changed(agents_mcp_path, json.dumps(agents_data, indent=2) + "\n")
    if claude_changed:
        write_if_changed(claude_json_path, json.dumps(cdata, indent=2) + "\n")


def install_systemd_watcher() -> None:
    systemd_user_dir = os.path.join(HOME, ".config", "systemd", "user")
    os.makedirs(systemd_user_dir, exist_ok=True)

    service_path = os.path.join(systemd_user_dir, "agent-config-sync.service")
    path_unit_path = os.path.join(systemd_user_dir, "agent-config-sync.path")

    service_content = f"""[Unit]
Description=Synchronize AI Agent Skills, Rules, Subagents, and MCP Configs
StartLimitIntervalSec=10
StartLimitBurst=5

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 {SCRIPT_PATH}
"""

    path_content = """[Unit]
Description=Watch AI Agent Configurations for New Skills and MCPs

[Path]
PathChanged=%h/.agents/skills
PathChanged=%h/.gemini/config/skills
PathChanged=%h/.claude/skills
PathChanged=%h/.agents/mcp_config.json
PathChanged=%h/.claude.json

[Install]
WantedBy=default.target
"""

    s_changed = write_if_changed(service_path, service_content)
    p_changed = write_if_changed(path_unit_path, path_content)

    try:
        if s_changed or p_changed:
            subprocess.run(["systemctl", "--user", "daemon-reload"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["systemctl", "--user", "enable", "--now", "agent-config-sync.path"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def main() -> None:
    clean_sync_conflicts()
    sync_skills()
    sync_rules_and_agents()
    sync_mcp()
    if "--install-watcher" in sys.argv:
        install_systemd_watcher()


if __name__ == "__main__":
    main()
