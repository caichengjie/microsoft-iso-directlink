---
name: microsoft-iso-directlink
description: 从微软官方服务器直接生成并下载 Windows 10/11 官方 ISO 镜像直链（绕过媒体创建工具）。支持全部 Windows 版本（Win10 22H2 / Win11 25H2）、全部语言（37 种）、全部架构（x64/x86）。当用户需要下载 Windows 系统镜像、Win10 22H2 ISO、Win11 ISO、制作安装 U 盘所需镜像、或需要微软官方直链（如复制到 IDM/迅雷满速下载）时使用。触发词：下载Win10镜像、下载Win11、系统ISO、官方镜像直链、Windows安装镜像、重装系统镜像。
---

# Microsoft ISO DirectLink（微软官方系统镜像直链生成）

## 概述

复刻 Rufus 作者的 Fido 脚本流程，通过微软官方 API（vlscppe 白名单 + ov-df 验证 + software-download-connector）直接生成 Windows 10/11 ISO 直链。**支持微软暴露的全部 Windows 镜像**：Win10 22H2 + Win11 25H2，全部语言（37 种），全部架构（x64/x86/ARM64）。

## 快速开始

```bash
# 默认：Win10 22H2 多版本（Home/Pro/Edu）简体中文
bash scripts/get_microsoft_iso_link.sh

# 查看支持的版本
bash scripts/get_microsoft_iso_link.sh list

# 查看某版本的全部语言
bash scripts/get_microsoft_iso_link.sh langs 2618

# 指定版本/语言（模糊匹配）/自动下载
bash scripts/get_microsoft_iso_link.sh 3321 en-us          # Win11 多版本 英文
bash scripts/get_microsoft_iso_link.sh 2378 简体            # Win10 Home China 简体中文
bash scripts/get_microsoft_iso_link.sh 2618 chinese download  # 生成后自动下载 x64 到当前目录

# AI 全自动模式（推荐给 AI 调用）
bash scripts/get_microsoft_iso_link.sh auto                 # 自动下载 Win10 22H2 中文 x64 + 校验
bash scripts/get_microsoft_iso_link.sh auto 3321 en-us      # 自动下载 Win11 多版本英文 x64 + 校验
```

## 支持矩阵（微软官方全部镜像）

| 版本 | EditionId | 说明 |
|---|---|---|
| Win10 22H2 v1 (19045.2965) | 2618 | Home/Pro/Edu 多版本 |
| Win10 22H2 v1 (19045.2965) | 2378 | Home China 中国家庭版 |
| Win11 25H2 v2 (26200.8037) | 3321,3324 | Home/Pro/Edu 多版本 |
| Win11 25H2 v2 (26200.8037) | 3322,3325 | Home China 中国家庭版 |
| Win11 25H2 v2 (26200.8037) | 3323,3326 | Pro China 中国专业版 |

- **语言**：全部 37 种（`langs <EditionId>` 查看完整列表），支持模糊匹配（zh-CN/chinese/简体/英文/en/ja…）
- **架构**：每种语言自动返回全部架构直链（x64/x86/ARM64），脚本输出 x64 优先

**API 常量（2026-08 验证有效，如失效需从 Fido 脚本更新）**：
- `OrgId=y6jn8c31`、`ProfileId=606624d44113`、`InstanceId=560dc9f3-1aa5-4a2f-b63c-9e18f8d0e175`
- 若微软改版导致 API 失效，从 `https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1` 拉最新常量与 EditionId 表

## AI 自动执行建议（重要）

**当用户提出下载 Windows 镜像的需求时，AI 应直接自动执行，不要反复追问**：

1. **判断参数**（用户没明说时按以下默认）：
   - 版本：默认 Win10 22H2（2618）；用户提 Win11 → 3321；用户提"中国版"→ 2378/3322/3323
   - 语言：默认简体中文；用户明确说其他语言才换
   - 架构：默认 x64（现代电脑），只有用户说"老电脑/32位"才选 x86
2. **直接运行**（自动下载 + 校验）：
   ```bash
   bash scripts/get_microsoft_iso_link.sh auto [EditionId] [语言]
   ```
3. **交付**：
   - 下载完成后校验"✅ 校验通过"信息（文件大小与服务器一致）才算完成
   - 同时生成 `官方直链.txt` 存到 `C:\Users\cai\Downloads` 供备份/IDM 下载
   - 汇报：版本/语言/大小/路径/直链有效期（24h）
4. **风控处理**：若报 SentinelReject，脚本自动重试 3 次；仍失败 → 告知用户"微软临时限流，等 10-30 分钟再试"，不要反复重跑
5. **链接过期**：直链 24h 有效，用户说"重新生成"→ 直接重跑脚本

## 核心流程（脚本已封装，理解即可）

1. 生成随机 GUID 作为 sessionId
2. `GET https://vlscppe.microsoft.com/tags?org_id=<OrgId>&session_id=<sid>` 白名单注册
3. `GET https://ov-df.microsoft.com/mdt.js?instanceId=<InstanceId>&PageId=si&session_id=<sid>` 提取 `w`（大写十六进制）和 `rticks`（数字）
4. `GET https://ov-df.microsoft.com/?session_id=<sid>&CustomerId=<InstanceId>&PageId=si&w=<w>&mdt=<epoch_ms>&rticks=<rticks>` 完成验证
5. `GET .../api/getskuinformationbyproductedition?...&productEditionId=<EditionId>&Locale=zh-CN&sessionID=<sid>` → 返回全部语言 SKU（JSON），模糊匹配目标语言
6. `GET .../api/GetProductDownloadLinksBySku?...&SKU=<skuId>&sessionID=<sid>` → 返回 `ProductDownloadOptions[].Uri` 全部架构直链

## 已知坑（重要）

- **Referer 必带**：第 6 步必须带 `Referer: https://www.microsoft.com/software-download/windows10ISO` 头，否则被拒
- **链接 24h 过期**：URL 中 `P1` 参数是过期时间戳；过期后重新运行脚本即可
- **Sentinel 风控（高频触发）**：短时间连续多次调用会被微软 Sentinel 限流（`SentinelReject` Type=8）。脚本已内置最多 3 次自动重试（间隔 5/10/15s）。若 3 次仍失败，说明 IP 被临时冷却，**等待 10-30 分钟**再跑。AI 不要连续重跑，一次任务最多跑 1-2 轮
- **沙箱测速坑**：curl 用 `-o /dev/null -w` 测速会显示 0B（数据写入 /dev/null 异常），必须保存到真实文件测速
- **Windows 下下载建议**：curl 加 `-C - --retry 5` 断点续传；或给用户直链用 IDM 多线程
- **Win11 多 ID**：同一版本有多个 EditionId（x64/ARM64 区分），脚本已做逐个尝试，取第一个匹配成功者
- **Windows 沙箱路径坑**：Git Bash 的 `/tmp` 与 Windows 原生 Python 的 `/tmp` 不是同一路径，脚本内数据传递已全部走 stdin，勿改回绝对临时路径

## 交付惯例

- ISO 与直链 txt 默认放 `C:\Users\cai\Downloads`
- 附直链 txt（含全部架构、有效期说明）方便用户备份
- 链接失效后用户会说"重新生成直链" → 重跑脚本即可

## 资源

- `scripts/get_microsoft_iso_link.sh` — 完整 API 流程脚本（Bash，依赖 curl + python3）
