# ONLYOFFICE 文件格式转换工具 (独立版)

从 ONLYOFFICE Desktop Editors 9.4.0 中剥离出的文档格式转换组件, 脱离 GUI 独立运行,核心是各平台安装包内置的 `x2t` 命令行转换器。

## 目录

| 目录       | 平台             | 说明                   |
| ---------- | ---------------- | ---------------------- |
| `macos/`   | macOS (arm64)    | 包装脚本 `convert.sh`  |
| `linux/`   | Linux (x86_64)   | 包装脚本 `convert.sh`  |
| `windows/` | Windows (x86_64) | 包装脚本 `convert.bat` |

每个平台目录都是 **自包含**的:整体拷贝到同平台的干净机器上即可使用。 各目录下的 `README.md` 有对应平台的详细说明。

## 快速上手

```bash
# macOS / Linux
./macos/convert.sh input.docx output.pdf
./linux/convert.sh input.xlsx output.pdf
```

```bat
:: Windows
windows\convert.bat input.docx output.pdf
```

转换方向由文件扩展名自动推断。常见支持:
docx / odt / rtf / txt / html / epub / fb2 / xlsx / ods / csv / pptx / odp / pdf / djvu / xps / hwp 等之间的相互转换。

首次运行时脚本会自动扫描本机系统字体生成缓存 (一次性), 迁移到新机器后删掉 `fonts/` 目录即可触发重建。 详见各平台 README 的"迁移/重建字体缓存"章节。

## 各平台目录结构 (统一约定)

```
<平台>/
├── converter/            # x2t 二进制 + 原生库 + DoctRenderer.config + 模板
├── editors/
│   ├── sdkjs/            # JS 排版渲染引擎(x2t 运行时加载)
│   └── web-apps/vendor/xregexp/
├── dictionaries/         # hunspell 拼写字典
├── fonts/                # 字体缓存(x2t -create-allfonts 生成,与机器绑定)
├── convert.sh / convert.bat
└── README.md
```

## 常见问题速查

- **报 `Couldn't recognize conversion direction from an argument`(Windows)**: params.xml 必须是真实 UTF-8 编码,`convert.bat` 已用 PowerShell 处理; 手工写 params.xml 时注意不要用 cmd `echo`(会写成 GBK)。
- **空文档能转、有文字的文档崩溃**: 字体缓存缺失。 执行 `x2t -create-allfonts <平台>/fonts` 重建, 并同步 `fonts/AllFonts.js` 到 `editors/sdkjs/common/`。
- **Linux 输出中文变方框**: 系统缺 CJK 字体, 安装 `fonts-noto-cjk`(deb)或 `google-noto-sans-cjk-fonts`(rpm)后重建字体缓存。
- **并发调用**: 稳态 (字体缓存已存在)下多进程并发安全, 各进程临时目录相互独立;不要让多个进程写同一个输出文件。

## 相关文档

- `macos/README.md`、`linux/README.md`、`windows/README.md` — 各平台详细用法
- `EXTRACTION-GUIDE.md` — 剥离操作手册 (全平台通用: 新版本/其他平台复刻本工具, 含 x2t 调用方式、参数格式、已踩过的坑)

## 许可证

组件来自 ONLYOFFICE (AGPL v3),分发或商用请注意许可证义务。
