#!/usr/bin/env bash
set -e

# ===============================
#  Git-Record Installer Script
# ===============================
echo ""
echo "========================================"
echo "        Git Record Installer"
echo "========================================"
echo ""

REPO_SCRIPT="https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/git-records.sh"
INSTALL_PATH="/usr/local/bin/git-record"

echo "🔽 Downloading git-record from repository..."
curl -fsSL "$REPO_SCRIPT" -o git-record

if [[ ! -f git-record ]]; then
    echo "❌ Download failed. Exiting."
    exit 1
fi

echo ""
echo "🔐 Setting executable permissions..."
chmod +x git-record

echo "📦 Installing git-record to $INSTALL_PATH..."
sudo mv -f git-record "$INSTALL_PATH"

echo ""
echo "🔄 Refreshing shell cache..."
hash -r 2>/dev/null || true

echo ""
echo "✅ Installation completed successfully!"
echo ""
echo "📌 You can now run:"
echo "   git record"
echo ""

if command -v git-record >/dev/null 2>&1; then
    echo "🎉 git-record is available in PATH."
else
    echo "⚠️ git-record is not in PATH. You may need to add /usr/local/bin to your PATH."
fi

echo ""
echo "========================================"
echo "        Installation Finished"
echo "========================================"
echo ""
