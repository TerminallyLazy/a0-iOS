#!/bin/bash
# Prepare a local App Store archive. Never uploads or deletes an existing archive.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${A0_DEVELOPMENT_TEAM:?Set A0_DEVELOPMENT_TEAM to your Apple Developer team ID}"
A0_ARCHIVE_PATH="${A0_ARCHIVE_PATH:-$PWD/build/AgentZero-$(date +%Y%m%d-%H%M%S).xcarchive}"
if [[ -e "$A0_ARCHIVE_PATH" ]]; then
  echo "Archive already exists; choose a new A0_ARCHIVE_PATH." >&2
  exit 1
fi
xcodebuild -project AgentZeroSpike.xcodeproj -scheme AgentZeroSpike \
  -configuration Release -destination 'generic/platform=iOS' \
  -disableAutomaticPackageResolution -allowProvisioningUpdates \
  -archivePath "$A0_ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$A0_DEVELOPMENT_TEAM" archive
python3 scripts/verify-release.py "$A0_ARCHIVE_PATH"
