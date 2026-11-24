#!/bin/sh
# Xcode Cloud runs this after every xcodebuild action.
#
# After an archive, upload its dSYMs to Sentry so crash reports arrive
# symbolicated. Needs SENTRY_AUTH_TOKEN (a secret on the workflow); the token never
# goes in the repo. Without it, or if the upload fails, the build still goes on
# with a warning: the release is fine, only its stack traces are unreadable.

set -e

[ "${CI_XCODEBUILD_ACTION}" = "archive" ] || exit 0

if [ -z "${SENTRY_AUTH_TOKEN}" ]; then
  echo "warning: SENTRY_AUTH_TOKEN is not set, so the dSYMs were not uploaded to Sentry. See SENTRY.md."
  exit 0
fi

# sentry-cli, pinned and checked against the release's published SHA-256.
CLI_VERSION="3.8.2"
CLI_SHA256="2d1b118fa46960ba5e8e0cca9a6e197366905776a0ddc5a89c7d05a3908b77db"
CLI="${CI_DERIVED_DATA_PATH:-/tmp}/sentry-cli"

if ! curl -sSfL -o "$CLI" "https://github.com/getsentry/sentry-cli/releases/download/${CLI_VERSION}/sentry-cli-Darwin-universal"; then
  echo "warning: could not download sentry-cli ${CLI_VERSION}; dSYMs not uploaded."
  exit 0
fi
if ! echo "${CLI_SHA256}  ${CLI}" | shasum -a 256 -c - >/dev/null; then
  echo "warning: sentry-cli checksum mismatch; dSYMs not uploaded."
  rm -f "$CLI"
  exit 0
fi
chmod +x "$CLI"

if "$CLI" debug-files upload \
    --org "${SENTRY_ORG:-iamjarl}" \
    --project "${SENTRY_PROJECT:-trimrpix-macos}" \
    "${CI_ARCHIVE_PATH}/dSYMs"; then
  echo "ci_post_xcodebuild: dSYMs uploaded to Sentry"
else
  echo "warning: the dSYM upload to Sentry failed; crash reports from this build will be unsymbolicated."
fi
