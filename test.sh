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

# This function replaces ps only inside collector processes started by this
# test. No real process data is read.
ps() {
    if [[ ${MOCK_EMPTY_PROCESSES:-0} == 1 ]]; then
        return 0
    fi

    [[ $* == '-eo uid=,user:256=,rss=' ]] || {
        printf 'unexpected ps arguments: %s\n' "$*" >&2
        return 64
    }

    printf '%s\n' \
        '0 root 500' \
        '999 chrony 20' \
        '1000 boundary 1' \
        '1001 alice 100' \
        '1001 alice 200' \
        '1002 bob 50' \
        '1003 charlie 999' \
        '1004 polly_hung 10'
}

export -f ps

[[ -x $COLLECTOR ]] || fail "collector is not executable: $COLLECTOR"

expected='{"users":[{"user":"alice","bytes":307200},{"user":"bob","bytes":51200},{"user":"boundary","bytes":1024},{"user":"charlie","bytes":1022976},{"user":"polly_hung","bytes":10240}]}'
actual=$("$COLLECTOR" collect)
assert_equal "$expected" "$actual" 'sums RSS for every process owner'

[[ $actual != *'root'* && $actual != *'chrony'* ]] || fail 'included a UID below 1000'
printf 'PASS: excludes UIDs below 1000\n'

[[ $actual == *'polly_hung'* ]] || fail 'did not preserve a long username'
printf 'PASS: preserves long usernames\n'

expected='{"users":[]}'
actual=$(MOCK_EMPTY_PROCESSES=1 "$COLLECTOR" collect)
assert_equal "$expected" "$actual" 'returns an empty array for an empty process table'

set +o errexit
error_output=$("$COLLECTOR" invalid-command 2>&1)
exit_status=$?
set -o errexit

[[ $exit_status -eq 2 ]] || fail 'invalid command did not return exit status 2'
[[ $error_output == *'Usage:'* ]] || fail 'invalid command did not show usage'
printf 'PASS: rejects an invalid command\n'

printf '\nAll tests passed.\n'
