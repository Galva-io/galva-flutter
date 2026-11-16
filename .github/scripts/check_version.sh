#!/usr/bin/env bash
# Checks that every place carrying the plugin's version agrees with pubspec.yaml, and, when a
# version is passed (the one a release tag names), that pubspec.yaml carries that version.
#
#   .github/scripts/check_version.sh           # versions agree with each other
#   .github/scripts/check_version.sh 1.5.0     # ... and are 1.5.0
set -euo pipefail

cd "$(dirname "$0")/../.."

version=$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | tr -d '"'"'"' \r')
if [[ -z "$version" ]]; then
  echo "::error file=pubspec.yaml::No version in pubspec.yaml"
  exit 1
fi

failed=0
expect() {
  local file=$1 found=$2
  if [[ "$found" != "$version" ]]; then
    echo "::error file=$file::$file says '${found:-nothing}', pubspec.yaml says $version"
    failed=1
  fi
}

expect lib/src/galva_version.dart \
  "$(sed -n "s/^const String galvaFlutterVersion = '\(.*\)';/\1/p" lib/src/galva_version.dart)"
expect android/build.gradle.kts \
  "$(sed -n 's/^version = "\(.*\)"/\1/p' android/build.gradle.kts)"
expect CHANGELOG.md \
  "$(sed -n 's/^## \([^[:space:]]*\).*/\1/p' CHANGELOG.md | head -n 1)"

if [[ $# -gt 0 && "$1" != "$version" ]]; then
  echo "::error file=pubspec.yaml::The tag names $1 but pubspec.yaml says $version"
  failed=1
fi

if [[ $failed -eq 0 ]]; then
  echo "Version $version"
fi
exit $failed
