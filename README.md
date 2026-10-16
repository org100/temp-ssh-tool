# TempSSH

一键生成限时 SSH 密码账号，到期自动销毁回收。支持 Debian 12/13、Ubuntu 22.04/24.04 及 Alpine Linux。

## 一键安装 / 更新

需 `curl`，以 `root` 或具备 `sudo` 权限的账号运行：

```bash
curl -fsSLO [https://raw.githubusercontent.com/org100/temp-ssh-tool/main/bootstrap.sh](https://raw.githubusercontent.com/org100/temp-ssh-tool/main/bootstrap.sh) && sh bootstrap.sh

```

## 快速使用

直接输入 `hssh` 打开交互菜单，或使用以下命令行快捷操作：

```bash
# 1. 密码认证总开关（仅控制密码登录，绝不影响 SSH 密钥登录）
hssh password on                               # 开启服务器 SSH 密码认证
hssh password off                              # 关闭服务器 SSH 密码认证（仅允许密钥登录）

# 2. 创建临时账号（时长支持：分钟 m / 小时 h / 天 d，范围 1m ~ 30d）
hssh create 30m                                # 创建 30 分钟普通账号（无 sudo 权限）
hssh create 2h                                 # 创建 2 小时普通账号
hssh create 90m --role sudo                    # 创建 90 分钟高权限账号（使用 sudo 时需输入该账号密码）
hssh create 2h --host example.com --port 2222  # 针对 NAT/端口转发机器，自定义最终打印的连接地址与端口

# 3. 账号管理与卸载
hssh list                                      # 查看所有临时账号及剩余到期时间
hssh revoke hs_1234abcd                        # 立即强制踢出并删除指定临时账号
hssh uninstall                                 # 撤销所有临时账号、还原 SSH 配置并彻底卸载本工具

```

## 核心机制与安全说明

* **安全与平滑重载**：开关密码认证**仅影响密码登录方式**，原有的 **SSH 密钥（Pubkey）登录始终可用**；修改配置采用平滑重载，**绝不会断开当前已建立的 SSH 连接**，且 `root` 账号始终受系统原有 `PermitRootLogin` 规则保护。


* **到期彻底回收**：账号到期（或手动 `revoke`）时，会自动强制终止该账号的所有运行中进程、断开其 SSH 连接、移除 `sudo` 权限，并彻底删除用户与家目录。随机生成的密码仅在创建时显示一次。


* **连接地址提示（`--host` / `--port`）**：脚本会自动探测公网 IP 以生成登录命令提示。若服务器处于 NAT 环境、内网或映射了非标外部端口，可用 `--host` 和 `--port` 修正终端打印出的 `ssh -p ...` 提示信息（**仅用于修正屏幕显示，不会修改服务器实际的 SSH 监听端口或网络配置**）。
