cat > install.sh << 'EOF'
#!/usr/bin/env bash

set -e

REPO_URL="https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/git-records.sh"
INSTALL_PATH="/usr/local/bin/git-record"

echo "========================================"
echo "        Git Record Installer"
echo "========================================"
echo ""

echo "🔽 Downloading git-record..."
curl -# -L "$REPO_URL" -o git-record

echo ""
echo "🔐 Making executable..."
chmod +x git-record

echo "📦 Installing to $INSTALL_PATH ..."
sudo mv -f git-record "$INSTALL_PATH"

echo ""
echo "🔄 Refreshing shell..."
hash -r 2>/dev/null || true

echo ""
echo "✅ Installation completed successfully."
echo ""
echo "📌 Try running:"
echo "   git record"
echo ""

if command -v git-record >/dev/null 2>&1; then
    echo "🎉 Verification successful: git-record is available."
else
    echo "⚠️  Warning: git-record not found in PATH."
fi

EOF
