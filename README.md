# gbl_root_canoe

这是一个针对 `canoe` 平台 ABL 的补丁与重编译工程。

项目的核心流程是：

1. 从用户提供的 `ABL.elf`、`abl.img` 或 `ABL.EFI` 中提取原始 `LinuxLoader.efi`。
2. 使用 `tools/patch_abl` 对提取出的 ABL 进行二进制补丁，生成按 `HWCOUNTRY` 区分的 `ABL_*.efi`。
3. 通过 `xxd -i` 将补丁后的 ABL 转成头文件 `edk2/QcomModulePkg/Include/Library/ABL.h`。
4. 使用仓库内的 `edk2` 工程重新编译，生成带 `superfastboot` 的输出文件。

最终产物默认位于 `dist/` 目录，例如：

- `dist/ABL_original.efi`
- `dist/ABL_CN.efi`
- `dist/ABL_GLOBAL.efi`
- `dist/ABL_with_superfastboot_CN.efi`
- `dist/ABL_with_superfastboot_GLOBAL.efi`
- `dist/ABL_with_superfastboot.efi`

如果未指定 `HWCOUNTRY`，默认会按 `CN GLOBAL EU IN RU ID TW TR` 全部构建一遍。

## 适用机型

当前适用范围为：

- 理论上：所有小米红米骁龙8EliteGen5处理器设备
- 小米17
- 小米17Pro
- 小米17ProMax
- 小米17Ultra
- 红米K90ProMax

## 项目原理

仓库里实际使用到的关键组件如下：

- `tools/extractfv.py`
  - 用来扫描并提取输入 ABL 中的 `LinuxLoader.efi`。
  - 支持直接处理 `ABL.elf` 和 `abl.img`。
- `tools/patch_abl.c`
  - 调用 `patchlib.h` 中的补丁逻辑，直接对提取出的 ABL 二进制做修改。
  - 当前支持按 `HWCOUNTRY` 生成不同版本。
- `Makefile`
  - `prepare_patch` 负责准备原始 ABL 输入。
  - `patch` 负责生成单个补丁后的 `ABL.efi`。
  - `build` 负责把补丁后的 ABL 注入 `edk2` 后重新编译。
- `edk2/`
  - 真正的重编译发生在这里。
  - 现在已经支持通过 `BUILD_THREAD_NUMBER` 开启多线程编译。

简化理解就是：先从你提供的 ABL 中提取原始 `LinuxLoader.efi`，再做补丁，最后把补丁结果塞回编译系统重新生成带 `superfastboot` 的 EFI 文件。

## Ubuntu 编译示例

以下示例以 Ubuntu 为例。

### 1. 安装依赖

```bash
sudo apt update
sudo apt install -y \
  git \
  python3 \
  build-essential \
  clang \
  lld \
  llvm \
  uuid-dev \
  zip \
  xxd \
  gcc-aarch64-linux-gnu \
  binutils-aarch64-linux-gnu
```

说明：

- `gcc` 用于编译 `tools/patch_abl`
- `clang` `lld` `llvm-ar` 用于 `edk2` 编译
- `aarch64-linux-gnu-*` 是交叉工具链
- `xxd` 用于把补丁后的 ABL 转成 `ABL.h`

### 2. 克隆仓库

```bash
git clone https://github.com/user1121114685/gbl_root_canoe.git
cd gbl_root_canoe
```

### 3. 准备输入文件

支持以下三种输入方式，三选一即可：

- `images/ABL.elf`
- `images/abl.img`
- `images/ABL.EFI`

推荐优先使用 `ABL.elf`。

例如：

```bash
mkdir -p images
cp /path/to/ABL.elf images/ABL.elf
```

### 4. 执行编译

编译单个地区版本：

```bash
make build HWCOUNTRY=GLOBAL
```

自动使用当前机器 CPU 线程数并行编译：

```bash
make build HWCOUNTRY=GLOBAL BUILD_THREADS=0
```

手动限制线程数：

```bash
make build HWCOUNTRY=GLOBAL BUILD_THREADS=8
```

如果要一次性编译全部地区：

```bash
make build
```

如果只想生成通用版本：

```bash
make build_generic
```

### 5. 产物位置

编译完成后主要看 `dist/`：

- `dist/ABL_with_superfastboot.efi`
- `dist/ABL_with_superfastboot_<COUNTRY>.efi`
- `dist/patch_log.txt`

## Issue + GitHub Actions 自动编译

仓库已经内置了基于 Issue 的自动编译工作流：

- 工作流文件：`.github/workflows/build-from-issue.yml`
- Issue 模板：`.github/ISSUE_TEMPLATE/build-request.yml`

### 触发方式

以下方式都可以触发 Actions：

1. 新建 Issue，选择 `编译请求 | Build Request` 模板。
2. Issue 标题以 `[Build]` 开头。
3. Issue 带有 `build-request` 标签。
4. 对已有编译 Issue 进行编辑、重新打开，或重新加上标签，也会再次触发。

### 在 Issue 中可用的提交方式

当前支持两种输入方式：

1. 上传压缩包。
   - 压缩包内必须包含且仅包含一个名为 `ABL.elf` 的文件。
   - 文件名匹配时忽略大小写。
2. 提供 `ABL.elf` 直链。
   - 如果模板里填写了可直接下载的 `ABL.elf` 链接，工作流会优先使用直链。

### 自动流程会做什么

Actions 收到 Issue 后会自动执行：

1. 下载或提取 `ABL.elf`
2. 执行 `make build`
3. 将 `dist/` 打包成 zip
4. 上传构建产物
5. 在对应 Issue 中回复下载链接和运行日志链接
6. 自动关闭该 Issue

### 使用建议

- 最稳妥的方式是直接使用 `编译请求 | Build Request` 模板。
- 不要在压缩包里放多个 `ABL.elf`。
- 如果构建失败，编辑原 Issue 后重新保存即可再次触发。

## 常用命令

运行全部测试：

```bash
make test
```

只做补丁，不重编译：

```bash
make patch HWCOUNTRY=GLOBAL
```

清理构建目录：

```bash
make clean
```

## 风险说明

这是 ABL 相关二进制补丁与重编译工程，刷入前请自行评估风险。错误的输入文件、错误机型或不匹配的构建结果，都可能导致设备无法正常启动。
