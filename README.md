# Zabbix login-node per-user memory monitor

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This package monitors the total resident memory (RSS) used by each currently
logged-in user on a Linux login node. A Zabbix warning is raised when a
logged-in user's usage exceeds 4 GiB.

The collector reads the process table once per check and returns one JSON
document. The online-user list comes from `who`; users without a current login
session are not collected, even if they still own background processes. The
template uses dependent discovery and dependent items, so it does not run `ps`
once for every user.

## Install on the monitored node

Keep all project files in the same directory, then run:

```bash
sudo ./install.sh
```

The installer supports Zabbix Agent 2 and the classic Zabbix agent. It installs
the collector at `/etc/zabbix/scripts/zabbix-user-memory`, installs
`user-memory.conf` in the detected agent include directory, tests the custom
key, and restarts the agent service.

The Zabbix service account must be able to see other users' processes. If `/proc`
is mounted with restrictive `hidepid` options, adjust that policy (for example,
with an authorized monitoring group) or the reported totals will be incomplete.

## Test

Run the self-contained test before installation:

```bash
./test.sh
```

The test uses fake login and process data, so it does not require root, active
login sessions, or a running Zabbix agent. Its example contains two online users:

```json
{"users":[{"user":"alice","bytes":307200},{"user":"bob","bytes":51200}]}
```

Alice has two processes using 100 KiB and 200 KiB of RSS. The expected sum is
307200 bytes. The fake process table also includes Charlie, but that user is
offline and is therefore excluded.

## Import and link the template

1. Import `linux-user-memory.yaml` in **Data collection → Templates**.
2. Link **Linux per-user memory by Zabbix agent** to the login-node host.
3. Confirm that `Per-user memory: Raw data` is supported and contains JSON.

The template is exported in Zabbix 7.0 format and can be imported into Zabbix
7.0 and newer releases.

## Configuration

The collector and dependent items update every 30 seconds. The warning threshold
is the template macro `{$USER.MEMORY.MAX}`. Its default is `4294967296` bytes
(4 GiB). Override the macro on a host if that node needs a different policy.

The collector uses usernames reported by `who` and `ps`. It does not call
`getent`, read `/etc/passwd`, or apply a local UID policy. Only usernames with a
current login session are included.

## What the number means

The value is the sum of the RSS column for all processes owned by the user. RSS
includes shared resident pages in each process, so shared memory can be counted
more than once. This is the conventional, inexpensive per-user memory measure;
it is not the same as proportional set size (PSS) or a cgroup-enforced limit.

## Author

Created and maintained by [@PhoenixEmik](https://github.com/PhoenixEmik).

## License

This project is released under the [MIT License](LICENSE).
