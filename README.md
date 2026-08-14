# microsoft-iso-directlink

从微软官方服务器**直接生成 Windows 10/11 官方 ISO 镜像直链**，绕过媒体创建工具。生成的链接可粘贴到 IDM / 迅雷 / 浏览器满速下载，适合需要纯净官方镜像、或不想跑微软工具的开发者。

> 流程复刻自 [pbatard/Fido](https://github.com/pbatard/Fido)（Rufus 作者的官方镜像直链工具），使用微软官方 API（vlscppe 白名单 + ov-df 验证 + software-download-connector），2026-08 实测可用。

## 功能

- ✅ 直接从微软官方服务器拿 ISO 直链（非第三方渠道）
- ✅ 支持 Win10 22H2（最终版）与 Win11 25H2
- ✅ 支持多语言：简体中文 / 繁体 / 英文 / 日文 / 韩文 / 德文 / 法文
- ✅ 支持 x64 / x86 双架构
- ✅ 内置断点续传、自动重试、微软 Sentinel 风控自动规避
- ✅ 一键 `download` 参数直接下载 x64 ISO

## 快速开始

```bash
# 默认：Win10 22H2 多版本（Home/Pro/Edu）简体中文 x64
bash scripts/get_microsoft_iso_link.sh

# 指定版本 / 语言 / 自动下载
bash scripts/get_microsoft_iso_link.sh 2378 zh-CN            # Win10 Home China 简体中文
bash scripts/get_microsoft_iso_link.sh 3321 en-us            # Win11 多版本 英文
bash scripts/get_microsoft_iso_link.sh 2618 zh-CN download   # 生成后自动下载 x64 到当前目录
```

依赖：`bash` + `curl` + `python3`（Windows 下用 Git Bash / WSL）。

## 版本参数表

| EditionId | 含义 |
|---|---|
| 2618 | Win10 22H2 v1 (Build 19045.2965) Home/Pro/Edu 多版本 |
| 2378 | Win10 22H2 Home China（中国家庭版单语言） |
| 3321 / 3324 | Win11 25H2 Home/Pro/Edu（不同架构 ID） |
| 3322 / 3325 | Win11 25H2 Home China |
| 3323 / 3326 | Win11 25H2 Pro China |

## 工作原理

1. 生成随机 GUID 作为 sessionId，向 `vlscppe.microsoft.com/tags` 注册白名单
2. 通过 `ov-df.microsoft.com` 完成反爬验证（获取 `w` / `rticks` 参数）
3. 调用 `software-download-connector` API 获取目标语言 SKU
4. 携带 `Referer` 头调用 `GetProductDownloadLinksBySku` 拿到 ISO 直链（含签名，**24 小时内有效**）

## 目录结构

```
microsoft-iso-directlink/
├── SKILL.md                              # 技能定义（供 AI 助手使用）
├── scripts/
│   └── get_microsoft_iso_link.sh         # 核心脚本（一键生成直链）
```

## 常见问题

- **链接过期？** 直链带签名 24h 有效，过期后重跑脚本即可重新生成。
- **报 `SentinelReject`？** 微软短时间多次调用会限流，脚本已内置 3 次自动重试；仍失败等 10-30 分钟再跑。
- **下载太慢？** 把直链粘贴到 IDM / 迅雷（多线程）通常比单线程快数倍。

## License

MIT（API 流程参考自 [Fido](https://github.com/pbatard/Fido)，同为 MIT 协议）。
