---
name: microsoft-iso-directlink
description: 从微软官方服务器直接生成并下载 Windows 10/11 官方 ISO 镜像直链（绕过媒体创建工具）。当用户需要下载 Windows 系统镜像、Win10 22H2 ISO、Win11 ISO、制作安装 U 盘所需镜像、或需要微软官方直链（如复制到 IDM/迅雷满速下载）时使用。触发词：下载Win10镜像、下载Win11、系统ISO、官方镜像直链、Windows安装镜像。
---

# Microsoft ISO DirectLink（微软官方系统镜像直链生成）

## 概述

复刻 Rufus 作者的 Fido 脚本流程，通过微软官方 API（vlscppe 白名单 + ov-df 验证 + software-download-connector）直接生成 Windows 10/11 ISO 直链，无需运行媒体创建工具，链接可粘贴到 IDM/迅雷/浏览器满速下载。

## 快速开始

```bash
# 默认：Win10 22H2 多版本（Home/Pro/Edu）简体中文 x64
bash scripts/get_microsoft_iso_link.sh

# 指定版本/语言/自动下载
bash scripts/get_microsoft_iso_link.sh 2378 zh-CN        # Win10 Home China 简体中文
bash scripts/get_microsoft_iso_link.sh 3321 en-us        # Win11 多版本 英文
bash scripts/get_microsoft_iso_link.sh 2618 zh-CN download   # 生成后自动下载 x64 到当前目录
```

## 工作流程决策树

1. 用户要下载 Windows 镜像 → 先问/判断：**架构**（现代电脑 x64；老机器才要 x86）、**版本**（Win10 22H2 最终版 / Win11）、**语言**（默认简体中文）
2. 运行 `scripts/get_microsoft_iso_link.sh`（参数见上）
3. 脚本输出直链（含 x64/x86 两个）+ 文件名 + 大小
4. 交付方式：
   - 用户有 IDM/迅雷 → 粘贴直链（多线程最快）
   - 让 AI 直接下载 → 传 `download` 参数
   - 保存直链到 txt 备份（链接 24h 有效，过期重新生成）

## 已验证参数表

| EditionId | 含义 |
|---|---|
| 2618 | Win10 22H2 v1 (Build 19045.2965) Home/Pro/Edu 多版本 |
| 2378 | Win10 22H2 Home China（中国家庭版单语言） |
| 3321 / 3324 | Win11 25H2 Home/Pro/Edu（不同架构 ID） |
| 3322 / 3325 | Win11 25H2 Home China |
| 3323 / 3326 | Win11 25H2 Pro China |

**API 常量（2026-08 验证有效，如失效需从 Fido 脚本更新）**：
- `OrgId=y6jn8c31`、`ProfileId=606624d44113`、`InstanceId=560dc9f3-1aa5-4a2f-b63c-9e18f8d0e175`
- 若微软改版导致 API 失效，从 `https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1` 拉最新常量与 EditionId 表

## 核心流程（脚本已封装，理解即可）

1. 生成随机 GUID 作为 sessionId
2. `GET https://vlscppe.microsoft.com/tags?org_id=<OrgId>&session_id=<sid>` 白名单注册
3. `GET https://ov-df.microsoft.com/mdt.js?instanceId=<InstanceId>&PageId=si&session_id=<sid>` 提取 `w`（大写十六进制）和 `rticks`（数字）
4. `GET https://ov-df.microsoft.com/?session_id=<sid>&CustomerId=<InstanceId>&PageId=si&w=<w>&mdt=<epoch_ms>&rticks=<rticks>` 完成验证
5. `GET https://www.microsoft.com/software-download-connector/api/getskuinformationbyproductedition?profile=<ProfileId>&productEditionId=<EditionId>&SKU=undefined&friendlyFileName=undefined&Locale=<Locale>&sessionID=<sid>` → 返回各语言 SKU（JSON），匹配目标语言的 `Id`
6. `GET https://www.microsoft.com/software-download-connector/api/GetProductDownloadLinksBySku?profile=<ProfileId>&productEditionId=undefined&SKU=<skuId>&friendlyFileName=undefined&Locale=<Locale>&sessionID=<sid>` → 返回 `ProductDownloadOptions[].Uri` 直链

## 已知坑（重要）

- **Referer 必带**：第 6 步必须带 `Referer: https://www.microsoft.com/software-download/windows10ISO` 头，否则被拒
- **链接 24h 过期**：URL 中 `P1` 参数是过期时间戳；过期后重新运行脚本即可
- **沙箱测速坑**：curl 用 `-o /dev/null -w` 测速会显示 0B（数据写入 /dev/null 异常），必须保存到真实文件测速
- **Windows 下下载建议**：curl 加 `-C - --retry 5` 断点续传；或给用户直链用 IDM 多线程
- **Win11 多 ID**：同一版本有多个 EditionId（x64/ARM64 区分），脚本已做逐个尝试，取第一个成功者
- **Sentinel 风控（高频触发）**：短时间连续多次调用会被微软 Sentinel 限流（错误 `SentinelReject` Type=8）。脚本已内置最多 3 次自动重试（间隔递增 5/10/15s）。若 3 次仍失败，说明 IP 被临时冷却，**等待 10-30 分钟**后再跑；日常使用频率（偶尔下一次镜像）不会触发
- **Windows 沙箱路径坑**：Git Bash 的 `/tmp` 与 Windows 原生 Python 的 `/tmp` 不是同一路径，脚本内数据传递已全部走 stdin，勿改回绝对临时路径

## 交付惯例

- ISO 与直链 txt 默认放 `C:\Users\cai\Downloads`
- 附直链 txt（含 x64/x86、有效期说明）方便用户备份
- 链接失效后用户会说"重新生成直链" → 重跑脚本即可

## 资源

- `scripts/get_microsoft_iso_link.sh` — 完整 API 流程脚本（Bash，依赖 curl + python3）
