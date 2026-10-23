#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ماه‌افزار هوشمند رسا (Rasa) — راه‌اندازی سریع روی مدل GLM (Z.AI)
#
# استفاده:
#   bash scripts/rasa_glm_setup.sh
#
# این اسکریپت:
#   1) کلید GLM_API_KEY را می‌پرسد (یا از متغیر محیطی می‌خواند)
#   2) آن را در ~/.hermes/.env ذخیره می‌کند
#   3) ~/.hermes/config.yaml را روی ارائه‌دهنده zai + مدل GLM تنظیم می‌کند
#   4) زبان رابط را فارسی می‌کند
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
ENV_FILE="$HERMES_HOME/.env"
CFG_FILE="$HERMES_HOME/config.yaml"

echo "🌙 ماه‌افزار هوشمند رسا — راه‌اندازی مدل GLM (Z.AI)"
echo "─────────────────────────────────────────────────"

if [[ -z "${GLM_API_KEY:-}" ]]; then
  read -r -p "کلید API خود را از z.ai وارد کنید: " GLM_API_KEY
fi
if [[ -z "$GLM_API_KEY" ]]; then
  echo "✗ کلید خالی است." >&2
  exit 1
fi

mkdir -p "$HERMES_HOME"

# 1) ذخیره کلید در .env (بدون تکرار)
touch "$ENV_FILE"
if grep -q "^GLM_API_KEY=" "$ENV_FILE"; then
  sed -i.bak "s|^GLM_API_KEY=.*|GLM_API_KEY=$GLM_API_KEY|" "$ENV_FILE" && rm -f "$ENV_FILE.bak"
  echo "✓ GLM_API_KEY به‌روزرسانی شد → $ENV_FILE"
else
  printf '\nGLM_API_KEY=%s\n' "$GLM_API_KEY" >> "$ENV_FILE"
  echo "✓ GLM_API_KEY ذخیره شد → $ENV_FILE"
fi

# 2) اگر ترجیح می‌دهید ویزارد رسمی اجرا شود
if command -v hermes >/dev/null 2>&1; then
  hermes config set model.provider zai 2>/dev/null || true
  hermes config set model.default "${RASA_GLM_MODEL:-glm-5.2}" 2>/dev/null || true
  hermes config set display.language fa 2>/dev/null || true
  echo "✓ پیکربندی با hermes config اعمال شد."
else
  # 3) نوشتن مستقیم config.yaml (وقتی CLI هنوز نصب نشده)
  if [[ -f "$CFG_FILE" ]] && ! grep -q "rasa-glm-managed" "$CFG_FILE"; then
    cp "$CFG_FILE" "$CFG_FILE.bak.$(date +%s)"
    echo "! config.yaml موجود بود؛ نسخه پشتیبان ساخته شد و بخش model به‌روزرسانی می‌شود."
  fi
  python3 - "$CFG_FILE" "$GLM_API_KEY" <<'PY'
import sys, pathlib, re
cfg = pathlib.Path(sys.argv[1])
key = sys.argv[2]
text = cfg.read_text(encoding="utf-8") if cfg.exists() else ""
block = f"""# rasa-glm-managed
model:
  provider: "zai"
  default: "{__import__('os').environ.get('RASA_GLM_MODEL', 'glm-5.2')}"
  streaming: true

agent:
  reasoning_effort: "medium"

display:
  language: "fa"
"""
if "rasa-glm-managed" in text:
    text = re.sub(r"# rasa-glm-managed.*?(?=\n\S|\Z)", block, text, flags=re.S)
else:
    text = block + "\n" + text
cfg.write_text(text, encoding="utf-8")
print(f"✓ پیکربندی نوشته شد → {cfg}")
PY
fi

echo ""
echo "✅ تمام شد! حالا اجرا کنید:  rasa   (یا: hermes)"
echo "   برای تغییر مدل:            hermes model"
echo "   برای بررسی سلامت:          hermes doctor"
