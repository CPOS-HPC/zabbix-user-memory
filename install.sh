#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR=/etc/zabbix/scripts
readonly SCRIPT_PATH=$SCRIPT_DIR/zabbix-user-memory

die() {
    printf 'install.sh: %s\n' "$*" >&2
    exit 1
}

[[ ${EUID:-$(id -u)} -eq 0 ]] || die 'run this installer as root'

for source_file in zabbix-user-memory user-memory.conf linux-user-memory.yaml; do
    [[ -f "$SOURCE_DIR/$source_file" ]] || die "missing project file: $source_file"
done

if [[ -d /etc/zabbix/zabbix_agent2.d ]] && command -v zabbix_agent2 >/dev/null 2>&1; then
    agent_binary=zabbix_agent2
    agent_service=zabbix-agent2
    agent_include_dir=/etc/zabbix/zabbix_agent2.d
elif [[ -d /etc/zabbix/zabbix_agentd.d ]] && command -v zabbix_agentd >/dev/null 2>&1; then
    agent_binary=zabbix_agentd
    agent_service=zabbix-agent
    agent_include_dir=/etc/zabbix/zabbix_agentd.d
else
    die 'could not find a supported Zabbix agent and include directory'
fi

install -d -o root -g root -m 0755 "$SCRIPT_DIR"
install -o root -g root -m 0755 "$SOURCE_DIR/zabbix-user-memory" "$SCRIPT_PATH"
install -o root -g root -m 0644 "$SOURCE_DIR/user-memory.conf" \
    "$agent_include_dir/user-memory.conf"

printf 'Installed collector: %s\n' "$SCRIPT_PATH"
printf 'Installed agent config: %s/user-memory.conf\n' "$agent_include_dir"

"$SCRIPT_PATH" collect >/dev/null
"$agent_binary" -t user.memory.get

if command -v systemctl >/dev/null 2>&1; then
    systemctl restart "$agent_service"
    printf 'Restarted service: %s\n' "$agent_service"
else
    printf 'systemctl was not found; restart %s manually.\n' "$agent_service"
fi

printf '\nImport %s/linux-user-memory.yaml into Zabbix and link the template to the host.\n' \
    "$SOURCE_DIR"
