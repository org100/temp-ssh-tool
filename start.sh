#!/bin/sh
set -eu
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || { printf '需要 root 权限；本机尚未安装 sudo，请切换 root 后运行。\n' >&2; exit 1; }
    exec sudo sh "$SCRIPT_DIR/start.sh" "$@"
fi

# shellcheck source=/dev/null
. /etc/os-release
new_ssh=0
command -v sshd >/dev/null 2>&1 || new_ssh=1

case "${ID:-}" in
    debian|ubuntu)
        [ -d /run/systemd/system ] || { printf '需要正在运行的 systemd。\n' >&2; exit 1; }
        command -v apt-get >/dev/null 2>&1 || { printf '缺少 apt-get，无法自动安装依赖。\n' >&2; exit 1; }
        packages=""
        for entry in python3:python3 curl:curl systemctl:systemd sshd:openssh-server \
            useradd:passwd usermod:passwd userdel:passwd groupadd:passwd chpasswd:passwd \
            pkill:procps ip:iproute2 sudo:sudo visudo:sudo; do
            tool="${entry%%:*}"
            pkg="${entry#*:}"
            if ! command -v "$tool" >/dev/null 2>&1; then
                case " $packages " in *" $pkg "*) ;; *) packages="$packages $pkg" ;; esac
            fi
        done
        if [ "$(dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null || true)" != 'install ok installed' ]; then
            packages="$packages ca-certificates"
        fi
        if [ -n "$packages" ]; then
            printf '首次使用，正在安装缺失依赖：%s\n' "$packages"
            apt-get -o DPkg::Lock::Timeout=120 -o Acquire::Retries=3 -o APT::Update::Error-Mode=any update || exit 1
            DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 install -y --no-install-recommends $packages || exit 1
        fi
        if [ "$new_ssh" -eq 1 ]; then
            install -d -m 0755 /run/sshd
            sshd -t
            systemctl enable --now ssh.service
        fi
        ;;
    alpine)
        command -v apk >/dev/null 2>&1 || { printf '缺少 apk，无法自动安装依赖。\n' >&2; exit 1; }
        packages=""
        for entry in python3:python3 curl:curl sshd:openssh-server \
            useradd:shadow usermod:shadow userdel:shadow groupadd:shadow chpasswd:shadow \
            pkill:procps ip:iproute2 sudo:sudo visudo:sudo; do
            tool="${entry%%:*}"
            pkg="${entry#*:}"
            if ! command -v "$tool" >/dev/null 2>&1; then
                case " $packages " in *" $pkg "*) ;; *) packages="$packages $pkg" ;; esac
            fi
        done
        [ -f /etc/ssl/certs/ca-certificates.crt ] || packages="$packages ca-certificates"
        if [ -n "$packages" ]; then
            printf '首次使用，正在安装缺失依赖：%s\n' "$packages"
            apk add --no-cache $packages || { printf '安装依赖失败，请检查 apk 软件源。\n' >&2; exit 1; }
        fi
        mkdir -p /etc/sudoers.d
        if ! grep -qE '^[#@]includedir[[:space:]]+/etc/sudoers\.d' /etc/sudoers 2>/dev/null; then
            printf '\n#includedir /etc/sudoers.d\n' >> /etc/sudoers
        fi
        ssh-keygen -A
        mkdir -p /run/sshd
        /usr/sbin/sshd -t
        if ! pgrep -x sshd >/dev/null 2>&1; then
            if command -v rc-service >/dev/null 2>&1 && [ -d /run/openrc ]; then
                rc-update add sshd default >/dev/null 2>&1 || true
                rc-service sshd start
            else
                /usr/sbin/sshd
            fi
        fi
        ;;
    *) printf '自动安装依赖仅支持 Debian / Ubuntu / Alpine。\n' >&2; exit 1 ;;
esac

for tool in python3 curl sshd useradd usermod userdel groupadd chpasswd pkill ip sudo visudo; do
    command -v "$tool" >/dev/null 2>&1 || { printf '依赖安装后仍缺少：%s\n' "$tool" >&2; exit 1; }
done
python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$SCRIPT_DIR/harness-ssh.py"

cd -- "$SCRIPT_DIR"
if [ ! -x /usr/local/sbin/harness-ssh ] || ! cmp -s ./harness-ssh.py /usr/local/sbin/harness-ssh; then
    python3 ./harness-ssh.py install
fi
exec /usr/local/sbin/harness-ssh "$@"
