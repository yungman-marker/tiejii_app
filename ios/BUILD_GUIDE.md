# iOS 安装包构建流程（零 macOS、零付费）

## 前置
- 已注册一个 Apple ID（推荐新建一个专门用于开发的免费 ID，避免主账号被风控）。
- iPhone 手机（能插数据线到电脑）。

## 一次性配置（30~60 分钟）

1. **iPhone → 设置 → 通用 → 关于本机 → 反复点"型号名称"** → 切换到 UDID → 长按复制备用。
2. 把项目推到 **Gitee（码云，gitee.com）**（国内可访问，替代 GitHub）：
   ```powershell
   cd D:\test9_1\tiejii_app
   git init
   git add .
   git commit -m "首次提交"
   # 去 gitee.com 创建一个空私有仓库（如 tiejii_app），然后：
   git remote add origin https://gitee.com/<你的gitee用户名>/tiejii_app.git
   git push -u origin master
   ```
3. 注册 [codemagic.io](https://codemagic.io)（用**邮箱注册**，因为 GitHub 登录在国内可能不通）。
   > ⚠️ Codemagic 是国外服务，请先确认你的网络能打开 codemagic.io。若打不开，见文末"备选方案"。
4. 添加应用 → 连接仓库：Codemagic 的 Git 接入里选 **GitLab**（Gitee 兼容 GitLab 的 API），
   把 Self-hosted 地址填 `https://gitee.com` → 授权 → 选中刚推的 `tiejii_app` 仓库 → 工作流选 `ios-free-id`。
5. 在项目 settings → Code signing identities:
   - Apple ID：填你的免费 Apple ID 邮箱
   - Password：**App 专用密码**（appleid.apple.com 重新生成，不是 Apple ID 主密码）
   - Team ID：可留空（Codemagic 自动探测个人 team）
6. 设备管理 (Devices) → 添加 UDID → 粘贴步骤 1 复制的 UDID → Codemagic 自动注册到你账号。

## 每次出包（5~10 分钟）

1. Codemagic → Start new build → workflow=`ios-free-id` → Start。
2. 等构建完成，下载 `tiejii-ios-free.ipa`（约 15~30M）。

## 装机（每次有效期 7 天，2~3 分钟/次）

1. 电脑装 [Sideloadly](https://sideloadly.io)（Windows/Mac 都行）。
2. iPhone 数据线连电脑，解锁信任。
3. Sideloadly 打开 → 选下载的 ipa → 填 Apple ID + 密码 → Start。
4. iPhone 装完首次打开前：**设置 → 通用 → VPN 与设备管理 → 点你的 Apple ID → 信任**。
5. App 图标出现在桌面即完成。

> 进阶：用 [SideStore](https://sidestore.io) + Wi-Fi 续签可免数据线、免每周手动重签。

## 已知免费账号限制
- 每 7 天签名失效，需重新装。
- 每年最多注册 3 台设备。
- 单个 ipa 内嵌 mobileprovision 有效期 7 天。
- 不能上架 App Store（只能企业内 / 设备内 / sideload）。
- 不能跑多人游戏 P2P / iCloud Push 等团队级 capabilities。

## 备选方案（若 codemagic.io 也打不开）
国内 CI（Gitee Go、腾讯 CODING）只有 Linux/Windows 构建机，**没有 macOS**，编不了 iOS；
GitHub 又被墙。如果 Codemagic 也连不上，唯一能在本土网络跑通的路是**租一台云 Mac**：
- 搜"云 Mac / Mac 云机 / MacinCloud 国内"等，按小时或包月租用，SSH/VNC 进去后跑
  `flutter build ipa`（免费 Apple ID 自动签名），把 ipa 下载回本机，再用 Sideloadly 侧载。
- 成本约几十元/天，比 CI 省心且不受墙影响，适合你一次性验证用。
