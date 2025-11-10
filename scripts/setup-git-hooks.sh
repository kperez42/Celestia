#!/bin/bash

# Setup Git Hooks for Celestia
# This script installs pre-commit hooks for code quality checks

set -e

echo "🔧 Setting up Git hooks for Celestia..."

# Get the git directory
GIT_DIR=$(git rev-parse --git-dir)
HOOKS_DIR="$GIT_DIR/hooks"

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash

# Pre-commit hook for Celestia
# Runs SwiftLint on staged Swift files

echo "🔍 Running SwiftLint..."

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "⚠️  SwiftLint is not installed. Install it with:"
    echo "   brew install swiftlint"
    echo ""
    echo "Skipping SwiftLint check..."
    exit 0
fi

# Get list of staged Swift files
SWIFT_FILES=$(git diff --cached --name-only --diff-filter=d | grep "\.swift$" || true)

if [ -z "$SWIFT_FILES" ]; then
    echo "✅ No Swift files to lint"
    exit 0
fi

# Run SwiftLint on staged files
echo "$SWIFT_FILES" | xargs swiftlint lint --quiet --config .swiftlint.yml

SWIFTLINT_EXIT_CODE=$?

if [ $SWIFTLINT_EXIT_CODE -eq 0 ]; then
    echo "✅ SwiftLint passed"
    exit 0
else
    echo "❌ SwiftLint found issues. Fix them before committing."
    echo ""
    echo "To auto-fix some issues, run:"
    echo "   swiftlint --fix --config .swiftlint.yml"
    echo ""
    echo "To skip this hook (not recommended), use:"
    echo "   git commit --no-verify"
    exit 1
fi
EOF

# Make the hook executable
chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ Git hooks installed successfully!"
echo ""
echo "📝 Pre-commit hook will run SwiftLint on staged Swift files"
echo ""
echo "To bypass the hook (not recommended):"
echo "   git commit --no-verify"
echo ""
echo "To manually run SwiftLint:"
echo "   swiftlint lint --config .swiftlint.yml"
echo ""
echo "To auto-fix SwiftLint issues:"
echo "   swiftlint --fix --config .swiftlint.yml"
