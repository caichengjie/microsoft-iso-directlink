# microsoft-iso-directlink

从微软官方服务器**直接生成 Windows 10/11 官方 ISO 镜像直链**，绕过媒体创建工具。生成的链接可粘贴到 IDM / 迅雷 / 浏览器满速下载，适合需要纯净官方镜像、或不想跑微软工具的开发者。

> 流程复刻自 [pbatard/Fido](https://github.com/pbatard/Fido)（Rufus 作者的官方镜像直链工具），使用微软官方 API（vlscppe 白名单 + ov-df 验证 + software-download-connector），2026-08 实测可用。

## 功能

- ✅ 直接从微软官方服务器拿 ISO 直链（非第三方渠道）
- ✅ **支持全部 Windows 镜像**：Win10 22H2 + Win11 25H2，全部 37 种语言，全架构（x64/x86/ARM64）
- ✅ 语言模糊匹配：`zh-CN` / `chinese` / `简体` / `en` / `ja` 都能识别
- ✅ `list` 查看所有版本，`langs` 查看某版本全部语言
- ✅ **`auto` 全自动模式**：生成直链 + 下载 x64 + 自动校验文件大小（供 AI 或脚本调用）
- ✅ 内置断点续传、自动重试、微软 Sentinel 风控自动规避

## 快速开始

```bash
# 默认：Win10 22H2 多版本（Home/Pro/Edu）简体中文
bash scripts/get_microsoft_iso_link.sh

# 查看支持的版本
bash scripts/get_microsoft_iso_link.sh list

# 查看某版本的全部语言
bash scripts/get_microsoft_iso_link.sh langs 2618

# 指定版本 / 语言 / 自动下载
bash scripts/get_microsoft_iso_link.sh 3321 en-us            # Win11 多版本 英文
bash scripts/get_microsoft_iso_link.sh 2378 简体              # Win10 Home China 简体中文
bash scripts/get_microsoft_iso_link.sh 2618 chinese download  # 生成后自动下载 x64 到当前目录

# AI 全自动模式（推荐给 AI / 脚本调用）
bash scripts/get_microsoft_iso_link.sh auto                   # 自动下载 Win10 22H2 中文 x64 + 校验
bash scripts/get_microsoft_iso_link.sh auto 3321 en-us        # 自动下载 Win11 多版本英文 x64 + 校验
```

依赖：`bash` + `curl` + `python3`（Windows 下用 Git Bash / WSL）。

## 支持矩阵（微软官方全部镜像）

| 版本 | EditionId | 说明 |
|---|---|---|
| Win10 22H2 v1 (19045.2965) | 2618 | Home/Pro/Edu 多版本 |
| Win10 22H2 v1 (19045.2965) | 2378 | Home China 中国家庭版 |
| Win11 25H2 v2 (26200.8037) | 3321,3324 | Home/Pro/Edu 多版本 |
| Win11 25H2 v2 (26200.8037) | 3322,3325 | Home China 中国家庭版 |
| Win11 25H2 v2 (26200.8037) | 3323,3326 | Pro China 中国专业版 |

- **语言**：全部 37 种（`langs <EditionId>` 查看完整列表）
- **架构**：每种语言自动返回全部架构直链（x64 优先展示）

## AI 自动执行建议

当 AI 收到"下载 Windows 镜像"需求时，可直接自动执行：

1. **判断参数**（用户未明说时）：版本默认 Win10 22H2（2618），语言默认简体中文，架构默认 x64
2. **直接运行**：`bash scripts/get_microsoft_iso_link.sh auto [EditionId] [语言]`
3. **交付**：校验输出含 `✅ 校验通过` 才算完成；同时生成直链 txt 备份；汇报版本/语言/大小/路径
4. **风控**：报 `SentinelReject` 时脚本自动重试 3 次；仍失败等 10-30 分钟再跑，勿反复重试

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
│   └── get_microsoft_iso_link.sh         # 核心脚本（一键生成直链/全自动下载）
```

## 常见问题

- **链接过期？** 直链带签名 24h 有效，过期后重跑脚本即可重新生成。
- **报 `SentinelReject`？** 微软短时间多次调用会限流，脚本已内置 3 次自动重试；仍失败等 10-30 分钟再跑。
- **下载太慢？** 把直链粘贴到 IDM / 迅雷（多线程）通常比单线程快数倍。

## License

MIT（API 流程参考自 [Fido](https://github.com/pbatard/Fido)，同为 MIT 协议）。
