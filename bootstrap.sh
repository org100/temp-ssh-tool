#!/bin/sh
# Download first; keep stdin attached to the terminal for the interactive menu.
set -eu
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || { printf '需要 root 权限；本机尚未安装 sudo，请切换 root 后运行。\n' >&2; exit 1; }
    exec sudo sh "$0" "$@"
fi
# shellcheck source=/dev/null
. /etc/os-release
case "${ID:-}" in
    debian|ubuntu)
        [ -d /run/systemd/system ] || { printf '需要正在运行的 systemd；普通 Docker 容器不支持到期自动回收。\n' >&2; exit 1; }
        packages=""
        command -v curl >/dev/null 2>&1 || packages="curl"
        if [ "$(dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null || true)" != 'install ok installed' ]; then
            packages="$packages ca-certificates"
        fi
        if [ -n "$packages" ]; then
            printf '首次使用，正在安装下载工具：%s\n' "$packages"
            if ! apt-get -o DPkg::Lock::Timeout=120 -o Acquire::Retries=3 -o APT::Update::Error-Mode=any update || \
               ! DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 install -y --no-install-recommends $packages; then
                printf '下载工具安装失败；请检查网络和 apt 软件源后重试。\n' >&2
                exit 1
            fi
        fi
        ;;
    alpine)
        if ! command -v curl >/dev/null 2>&1 || [ ! -f /etc/ssl/certs/ca-certificates.crt ]; then
            printf '首次使用，正在安装下载工具：curl ca-certificates\n'
            apk add --no-cache curl ca-certificates || { printf '下载工具安装失败；请检查 apk 软件源后重试。\n' >&2; exit 1; }
        fi
        ;;
    *) printf '自动安装依赖仅支持 Debian / Ubuntu / Alpine。\n' >&2; exit 1 ;;
esac

tmp="$(mktemp -d /tmp/harness-ssh-install.XXXXXXXX)"
trap 'rm -rf -- "$tmp"' EXIT INT TERM
base='https://raw.githubusercontent.com/org100/temp-ssh-tool/main'
ts="$(date +%s)"
for file in start.sh harness-ssh.py; do
    curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
        --connect-timeout 15 --max-time 120 --retry 2 "$base/$file?t=$ts" -o "$tmp/$file"
done
sh -n "$tmp/start.sh"
sh "$tmp/start.sh" "$@"
