# ONLYOFFICE 转换组件独立版 (macos)

从 ONLYOFFICE Desktop Editors 9.4.0 (macOS arm64) 剥离出的文档格式转换组件,
可脱离 GUI 独立运行。核心是 `converter/x2t` 命令行转换器。

## 目录结构

- `converter/` — x2t 二进制 + 全部原生框架 (doctrenderer, PdfFile, graphics,
  kernel, DocxRenderer, HWPFile, DjVuFile, EpubFile, Fb2File, HtmlFile2,
  IWorkFile, OFDFile, XpsFile, StarMathConverter, ooxmlsignature,
  UnicodeConverter, kernel_network), `DoctRenderer.config`, 空文档模板
  (`empty/`), 区域模板 (`templates/`)
- `editors/sdkjs/` — 文档排版/渲染 JS 引擎 (doctrenderer 运行时加载)
- `editors/web-apps/vendor/xregexp/` — sdkjs 依赖
- `dictionaries/` — hunspell 拼写字典
- `fonts/` — 由 `x2t -create-allfonts` 扫描本机系统字体生成的
  `AllFonts.js` + `font_selection.bin` (PDF/图片输出必需, 缺了会在
  `CPdfWriter::GetFontPath` 段错误)
- `convert.sh` — 转换包装脚本

## 用法

```bash
./convert.sh input.docx output.pdf
./convert.sh input.docx output.odt
./convert.sh input.xlsx output.pdf
./convert.sh input.pptx output.pdf
```

转换方向由文件扩展名自动推断。支持的输入: docx/doc/odt/rtf/txt/html/
epub/fb2/xlsx/xls/ods/csv/pptx/ppt/odp/vsdx/pdf/djvu/xps/hwp 等;
输出: docx/odt/rtf/txt/pdf/html/xlsx/ods/csv/pptx/odp 等。

## 直接调用 x2t (XML 参数方式)

```bash
converter/x2t params.xml
```

params.xml 格式:

```xml
<?xml version="1.0" encoding="utf-8"?>
<TaskQueueDataConvert>
<m_sFileFrom>/abs/path/in.docx</m_sFileFrom>
<m_sFileTo>/abs/path/out.pdf</m_sFileTo>
<m_sAllFontsPath>/abs/path/fonts/AllFonts.js</m_sAllFontsPath>
<m_sFontDir>/abs/path/fonts</m_sFontDir>
<m_sTempDir>/tmp/xxx</m_sTempDir>
</TaskQueueDataConvert>
```

也支持位置参数: `x2t <输入> <输出> [font_selection.bin 所在目录]`,
注意第三个参数是**字体目录**, 不是临时目录。

## 重建字体缓存

系统字体变化后重新生成:

```bash
converter/x2t -create-allfonts /abs/path/macos/fonts
```

## 迁移到新 Mac

`fonts/AllFonts.js` 记录的是生成机器上字体文件的绝对路径,
字体缓存与机器绑定。迁移后有两种做法:

1. **自动(推荐)**: 删掉 `fonts/` 目录再运行 `convert.sh`,
   脚本检测到缓存缺失会自动扫描新机器的系统字体重建。
   同版本 macOS 的系统字体基本一致, 不删直接跑通常也没问题,
   但用户自装字体有差异时排版会 fallback。
2. **手动**: 在新机器上执行上面"重建字体缓存"的命令。

如需跨机器渲染效果完全一致(不依赖各机器装了什么字体),
把 .ttf/.otf 字体文件放进包内一个目录(如 `fonts/custom/`),
迁移后执行:

```bash
EXTRA_FONTS_DIR=/abs/path/macos/fonts/custom \
    converter/x2t -create-allfonts /abs/path/macos/fonts
```

注意开源字体(如 Noto、Liberation)才可随意分发, 商业字体有授权限制。

## 备注

- 仅 arm64; 二进制带 ONLYOFFICE 官方签名, 首次运行如被 Gatekeeper
  拦截, 在"系统设置 > 隐私与安全性"中放行。
- 组件来自 ONLYOFFICE (AGPL v3), 商用请注意许可证。
