# PixelOS 17 for diting（Xiaomi 12T Pro / Redmi K50 至尊版）

基于 [PixelOS](https://github.com/PixelOS-AOSP) `seventeen`（Android 17）的非官方构建，设备树源自 LineageOS `lineage-24.0`。本仓库是构建入口：manifest、固定版本清单、构建与发版脚本，以及所有改动所在仓库的索引。

## 主要改动

- **eSIM**：通过 OpenEUICC 支持机身内置 eUICC。
  - 国际版（`ditingp`）默认关闭，可在 设置 > 网络和互联网 中开启。
  - 中国版可在 Jcao特性 中强制开启，需要自备可读写的外置 eSIM 芯片。
  - 开启后卡槽二切换到 eSIM（通过小米 OEM hook 切换 GPIO）。
  - 下载的配置文件直接显示在 设置 > SIM 卡 中，可原生启用、停用。
  - 修复了配置文件写入时芯片回 6A80 的问题（ES10x MSS 255）。
  - 修复了切换后基带不刷新的问题（自动给 SIM 断电重连）。
- **杜比全景声**：使用 PixelOS DolbyAtmos 界面（crDroid hardware_dolby），去掉桌面图标。
- **MIUI 相机**：替换 Aperture（crDroid）。
- **Jcao特性**：设置 > 系统 > 高级 中的入口，包含系统更新和强制开启 eSIM。
- **OTA**：更新器指向自建服务器，修复了更新日志不显示的问题。
- **Play Integrity**：认证属性改为本 ROM 签名的 overlay，可通过更新器在线更新。
- **其他**：
  - 隐藏解锁状态（crDroid custom_rom_hide）。
  - 手势导航隐藏小白条开关。
  - 自动亮度调校。
  - 状态栏与挖孔对齐。
  - NTP 默认 time.apple.com。
  - 多地址网络连通性检测，避免国内出现"!"和"x"。
  - 指纹录入界面不再重叠。

## 源码

所有改动都在以下仓库的 `pixelos-17` 分支（JcaoParts 为 `main`）。具体提交见各仓库历史。

| 路径 | 仓库 | 上游 |
|---|---|---|
| device/xiaomi/diting | [android_device_xiaomi_diting](https://github.com/CaoBill0522/android_device_xiaomi_diting) | LineageOS lineage-24.0 |
| device/xiaomi/sm8450-common | [android_device_xiaomi_sm8450-common](https://github.com/CaoBill0522/android_device_xiaomi_sm8450-common) | LineageOS lineage-24.0 |
| kernel/xiaomi/sm8450 | [android_kernel_xiaomi_sm8450](https://github.com/CaoBill0522/android_kernel_xiaomi_sm8450) | LineageOS lineage-24.0（未修改） |
| kernel/xiaomi/sm8450-devicetrees | [android_kernel_xiaomi_sm8450-devicetrees](https://github.com/CaoBill0522/android_kernel_xiaomi_sm8450-devicetrees) | LineageOS lineage-24.0（未修改） |
| kernel/xiaomi/sm8450-modules | [android_kernel_xiaomi_sm8450-modules](https://github.com/CaoBill0522/android_kernel_xiaomi_sm8450-modules) | LineageOS lineage-24.0（未修改） |
| bionic | [android_bionic](https://github.com/CaoBill0522/android_bionic) | PixelOS seventeen |
| frameworks/base | [android_frameworks_base](https://github.com/CaoBill0522/android_frameworks_base) | PixelOS seventeen |
| packages/apps/Settings | [android_packages_apps_Settings](https://github.com/CaoBill0522/android_packages_apps_Settings) | PixelOS seventeen |
| packages/apps/Updater | [android_packages_apps_Updater](https://github.com/CaoBill0522/android_packages_apps_Updater) | PixelOS seventeen |
| packages/apps/DolbyAtmos | [android_packages_apps_DolbyAtmos](https://github.com/CaoBill0522/android_packages_apps_DolbyAtmos) | PixelOS seventeen |
| packages/apps/OpenEUICC | [android_packages_apps_OpenEUICC](https://github.com/CaoBill0522/android_packages_apps_OpenEUICC) | [PeterCxy/OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC) |
| packages/apps/JcaoParts | [android_packages_apps_JcaoParts](https://github.com/CaoBill0522/android_packages_apps_JcaoParts) | 原创 |
| hardware/dolby | [android_hardware_dolby](https://github.com/CaoBill0522/android_hardware_dolby) | crDroid |

其余项目使用 PixelOS、LineageOS、crDroid 等上游的公开仓库，见 `local_manifests/diting.xml`。

## 构建

推荐配置：64 核、128G 内存、1T 磁盘、Ubuntu 24.04 或更新版本。在全新服务器上可以先用 root 运行 `scripts/setup-build-server.sh`。

```bash
mkdir ~/pixelos && cd ~/pixelos
repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b seventeen --git-lfs --depth=1
mkdir -p .repo/local_manifests
curl -o .repo/local_manifests/diting.xml https://raw.githubusercontent.com/CaoBill0522/PixelOS_diting/main/local_manifests/diting.xml
repo sync -c -j16 --force-sync --no-tags --no-clone-bundle
(cd packages/apps/OpenEUICC && git submodule update --init --recursive)

. build/envsetup.sh
breakfast diting userdebug
m pixelos -j$(nproc)
```

产物：`out/target/product/diting/PixelOS_diting-17.0-<日期>.zip`

### 复现指定版本

`pinned/pixelos-17-diting.xml` 是 `repo manifest -r` 的输出，每个项目都固定到构建时的提交（当前对应 `PixelOS_diting-17.0-20261021-1921`），用它可以得到与发布版本完全一致的源码：

```bash
cp pinned/pixelos-17-diting.xml ~/pixelos/.repo/manifests/pinned.xml
cd ~/pixelos && repo init -m pinned.xml && rm -rf .repo/local_manifests
repo sync -c -j16 --force-sync
```

## OTA 服务器

更新器从 `https://update.jcao.dev/diting` 获取版本信息。这个地址必须直接返回 200 和 JSON，更新器不跟随重定向。同目录下还需要：
- `changelog.md`：更新日志。
- `certified_build_props.apk`：Play Integrity 认证属性包。
- `builds/<zip>`：完整的 OTA 包。

- `scripts/gen_ota_json.py`：从 OTA zip 生成 JSON（datetime、sha256、ota_property_files 等）。
- `scripts/release.sh`：一键发布。JSON 在编译服务器上生成，OTA 服务器直接从编译服务器拉取 zip，校验通过后才替换 JSON。

只有 `datetime` 大于手机当前 `ro.build.date.utc` 的包才会显示为更新。

## 许可证与开源说明

- 本仓库中的脚本和文档采用 [Apache License 2.0](LICENSE)。
- 各子项目沿用其上游许可证：
  - AOSP、PixelOS、LineageOS 的大部分代码、设备树、JcaoParts：Apache-2.0。
  - Linux 内核：GPL-2.0。
  - OpenEUICC：GPL-3.0。
  - lpac（ROM 只用到其 `euicc` 库）：LGPL-2.1。
  - 以上以各仓库内的 LICENSE 文件为准。
- 发布的 ROM 中所有 GPL 组件的完整源码，都可以按上表和 `pinned/pixelos-17-diting.xml` 在本账号下获取。其中内核仓库已经 fork 并固定到构建所用的提交。修改记录见各仓库的提交历史。
- 设备专有文件来自 [TheMuppets](https://github.com/TheMuppets)，Google 应用来自 PixelOS GMS。这些归各自权利人所有，不属于本仓库的开源范围。

本项目与小米、Google、PixelOS 官方均无关联。刷机有风险，请自行承担。
