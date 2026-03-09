#!/bin/bash
set -e

# ============================================================
#  OpenClaw LightX2V Skill — Installer
#  Installs the LightX2V cloud API skill for OpenClaw.
# ============================================================

SKILL_NAME="lightx2v"
# Prefer OPENCLAW_WORKSPACE; default to ~/.openclaw/workspace
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
SKILL_DIR="$WORKSPACE/skills/$SKILL_NAME"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail()  { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

echo ""
echo "========================================"
echo "  OpenClaw LightX2V Skill Installer"
echo "  LightX2V 云端 API 技能安装程序"
echo "========================================"
echo ""

# ----------------------------------------------------------
# 1. Check prerequisites
# ----------------------------------------------------------
info "Checking prerequisites..."

if ! command -v openclaw &>/dev/null; then
    warn "openclaw not found in PATH. Install: npm install -g openclaw"
else
    ok "openclaw found"
fi

# ----------------------------------------------------------
# 2. Create target directory and copy files
# ----------------------------------------------------------
info "Installing skill to $SKILL_DIR ..."

if [[ -d "$SKILL_DIR" ]]; then
    warn "Existing installation found. Backing up to ${SKILL_DIR}.bak"
    rm -rf "${SKILL_DIR}.bak"
    mv "$SKILL_DIR" "${SKILL_DIR}.bak"
fi

mkdir -p "$SKILL_DIR/scripts"

cp "$REPO_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
if [[ -d "$REPO_DIR/scripts" ]]; then
    cp -r "$REPO_DIR/scripts/"* "$SKILL_DIR/scripts/"
fi
# Optional files
[[ -f "$REPO_DIR/README.md" ]] && cp "$REPO_DIR/README.md" "$SKILL_DIR/README.md" || true

ok "Files copied"

# ----------------------------------------------------------
# 3. Prompt for token (optional)
# ----------------------------------------------------------
OPENCLAW_CONFIG="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
echo ""
read -p "Enter your LightX2V cloud token (or press Enter to skip and set later in openclaw.json): " CLOUD_TOKEN

if [[ -n "$CLOUD_TOKEN" ]] && [[ -f "$OPENCLAW_CONFIG" ]]; then
    info "Adding lightx2v env to openclaw.json ..."
    if command -v python3 &>/dev/null; then
        python3 - "$OPENCLAW_CONFIG" "$CLOUD_TOKEN" << 'PY'
import json, sys
path = sys.argv[1]
token = sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
except Exception as e:
    print("Could not read openclaw.json:", e, file=sys.stderr)
    sys.exit(1)
cfg.setdefault("skills", {})
skills = cfg["skills"]
entries = skills.get("entries") or {}
if "lightx2v" not in entries:
    entries["lightx2v"] = { "enabled": True, "env": {} }
entries["lightx2v"].setdefault("env", {})["LIGHTX2V_CLOUD_TOKEN"] = token
entries["lightx2v"]["env"]["LIGHTX2V_CLOUD_URL"] = "https://x2v.light-ai.top"
skills["entries"] = entries
allow = skills.get("allow")
if isinstance(allow, list) and "lightx2v" not in allow:
    allow.append("lightx2v")
    skills["allow"] = allow
with open(path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("Updated openclaw.json")
PY
        ok "openclaw.json updated with LIGHTX2V_CLOUD_TOKEN"
    else
        warn "python3 not found; add LIGHTX2V_CLOUD_TOKEN to skills.entries.lightx2v.env manually"
    fi
elif [[ -z "$CLOUD_TOKEN" ]]; then
    warn "No token set. Add LIGHTX2V_CLOUD_TOKEN to ~/.openclaw/openclaw.json before using the skill."
elif [[ ! -f "$OPENCLAW_CONFIG" ]]; then
    warn "openclaw.json not found at $OPENCLAW_CONFIG. Add skills.entries.lightx2v.env with LIGHTX2V_CLOUD_TOKEN and LIGHTX2V_CLOUD_URL."
fi

# ----------------------------------------------------------
# 4. Done
# ----------------------------------------------------------
echo ""
echo "========================================"
echo -e "  ${GREEN}Installation complete!${NC}"
echo "========================================"
echo ""
echo "Skill location: $SKILL_DIR"
echo ""
echo "Next steps:"
echo "  1. If you skipped the token, set in openclaw.json:"
echo "     skills.entries.lightx2v.env.LIGHTX2V_CLOUD_TOKEN"
echo "  2. Ensure lightx2v is in skills.allow (if you use an allowlist)"
echo "  3. Restart OpenClaw / gateway if needed: openclaw gateway --force"
echo ""
