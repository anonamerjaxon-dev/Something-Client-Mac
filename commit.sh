#!/bin/bash
set -e

cd "/Users/jackson/Desktop/     /claude/something client mac"

echo "=== Git Status ==="
git status --short

echo ""
echo "=== Adding all changes ==="
git add -A

echo ""
echo "=== Commit message ==="
echo "Remove particle effects, fix thread safety, rewrite demo UI, improve README"
echo ""

git commit -m "Remove particle effects, fix thread safety, rewrite demo UI, improve README

- Removed ParticleConfig and all particle-related code (configuration, rendering, builder API)
- Fixed thread safety in CVDisplayLink with proper Unmanaged retain/release
- Rewrote CursorTrailDemo with clean, polished UI (sectioned GroupBox layout)
- Updated README with clearer structure, removed outdated particle references
- Fixed use-after-free potential in display link callback
- Cleaned up test suite to match new configuration"

echo ""
echo "=== Pushing to GitHub ==="
git push origin main

echo ""
echo "=== Done! ==="