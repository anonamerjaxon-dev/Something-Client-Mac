#!/bin/bash
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/Library/Developer/CommandLineTools/usr/bin"
cd "/Users/jackson/Desktop/     /claude/something client mac/cursor trail"
unset SAFE_RM_ALLOWED_PATH
unset SAFE_RM_DENIED_PATH
unset SAFE_RM_PROTECTION_FLAG
unset SAFE_RM_AUTO_ADD_TEMP
echo "Starting build..." > "/Users/jackson/Desktop/     /claude/something client mac/cursor trail/build-output.txt"
/Library/Developer/CommandLineTools/usr/bin/swift build >> "/Users/jackson/Desktop/     /claude/something client mac/cursor trail/build-output.txt" 2>&1
echo "BUILD_EXIT=$?" >> "/Users/jackson/Desktop/     /claude/something client mac/cursor trail/build-output.txt"