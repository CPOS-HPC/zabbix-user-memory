#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly COLLECTOR=$PROJECT_DIR/zabbix-user-memory

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_equal() {
    local expected=$1
    local actual=$2
    local test_name=$3

    if [[ $actual != "$expected" ]]; then
        printf 'FAIL: %s\nExpected: %s\nActual:   %s\n' \
            "$test_name" "$expected" "$actual" >&2
        exit 1
    fi
    printf 'PASS: %s\n' "$test_name"
}

# These functions replace the system commands only inside collector processes
# started by this test. No real login or process data is read.
who() {
    if [[ ${MOCK_EMPTY_LOGINS:-0} == 1 ]]; then
        return 0
    fi

    printf '%s\n' \
        'alice   pts/1  2026-07-16 09:00 (192.0.2.10)' \
        'bob     pts/2  2026-07-16 09:05 (192.0.2.11)' \
        'alice   pts/3  2026-07-16 09:10 (192.0.2.12)'
}

ps() {
    printf '%s\n' \
        'alice 100' \
        'alice 200' \
        'bob 50' \
        'charlie 999'
}

export -f who ps

[[ -x $COLLECTOR ]] || fail "collector is not executable: $COLLECTOR"

expected='{"users":[{"user":"alice","bytes":307200},{"user":"bob","bytes":51200}]}'
actual=$("$COLLECTOR" collect)
assert_equal "$expected" "$actual" 'sums RSS for unique online users'

# Charlie owns 999 KiB in the fake process table, but has no login session
# and therefore must never appear in the result.
[[ $actual != *'charlie'* ]] || fail 'included an offline process owner'
printf 'PASS: excludes users without a login session\n'

expected='{"users":[]}'
actual=$(MOCK_EMPTY_LOGINS=1 "$COLLECTOR" collect)
assert_equal "$expected" "$actual" 'returns an empty array when nobody is online'

set +o errexit
error_output=$("$COLLECTOR" invalid-command 2>&1)
exit_status=$?
set -o errexit

[[ $exit_status -eq 2 ]] || fail 'invalid command did not return exit status 2'
[[ $error_output == *'Usage:'* ]] || fail 'invalid command did not show usage'
printf 'PASS: rejects an invalid command\n'

printf '\nAll tests passed.\n'
