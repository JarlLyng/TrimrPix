#!/bin/sh
# Xcode Cloud runs this right after cloning the repository.
#
# Sentry.xcconfig is gitignored, so write it from the workflow's SENTRY_DSN (a
# secret environment variable). In an xcconfig "//" starts a comment, so a raw
# https:// DSN would be cut to "https:"; the "//" is written as "/$()/" instead.
# Without SENTRY_DSN the file gets an empty value: builds and tests still run with
# crash reporting off, and an archive is refused by the target's build phase
# "Refuse an archive without a Sentry DSN". See SENTRY.md.

set -e

CONFIG="${CI_PRIMARY_REPOSITORY_PATH:-..}/Sentry.xcconfig"
ESCAPED=$(printf '%s' "${SENTRY_DSN}" | sed 's#//#/$()/#g')
printf 'SENTRY_DSN = %s\n' "${ESCAPED}" > "$CONFIG"

if [ -n "${SENTRY_DSN}" ]; then
  echo "ci_post_clone: wrote Sentry.xcconfig with a DSN"
else
  echo "ci_post_clone: wrote Sentry.xcconfig with an empty DSN (crash reporting off; an archive will be refused)"
fi
