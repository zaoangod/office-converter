# ONLYOFFICE 转换组件独立版 (linux)

从 ONLYOFFICE Desktop Editors 9.4.0 (Linux x86-64) 剥离出的文档格式转换组件,
可脱离 GUI 独立运行。核心是 `converter/x2t` 命令行转换器。

## 目录结构

- `converter/` — x2t 二进制 + 全部原生库 (libdoctrenderer, libPdfFile,
  libgraphics, libkernel, libDocxRenderer, libHWPFile, libDjVuFile, libEpubFile,
  libFb2File, libHtmlFile2, libIWorkFile, libOFDFile, libXpsFile,
  libStarMathConverter, libooxmlsignature, libUnicodeConverter,
  libkernel_network, libicu*), `DoctRenderer.config`, 空文档模板
  (`empty/`), 区域模板 (`templates/`)
- `editors/sdkjs/` — 文档排版/渲染 JS 引擎 (doctrenderer 运行时加载)
- `editors/web-apps/vendor/xregexp/` — sdkjs 依赖
- `dictionaries/` — hunspell 拼写字典
- `fonts/` — 由 `x2t -create-allfonts` 扫描本机系统字体生成的
  `AllFonts.js` + `font_selection.bin` (PDF/图片输出必需, 缺了会在
  含文字的文档转换时崩溃)
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

## 系统依赖

原生库全部自带并通过 `$ORIGIN` rpath 解析, 不要用发行版包管理器
安装的 ONLYOFFICE 库混用。拷贝到新机器后检查:

```bash
ldd converter/x2t | grep "not found"
```

缺什么装什么(通常是 libstdc++/glibc 层面的库, 常规桌面/服务器系统一般不缺)。

## 重建字体缓存

系统字体变化后重新生成:

```bash
converter/x2t -create-allfonts /abs/path/linux/fonts
cp fonts/AllFonts.js editors/sdkjs/common/AllFonts.js
```

## 迁移到新机器

`fonts/AllFonts.js` 记录的是生成机器上字体文件的绝对路径,
字体缓存与机器绑定。迁移后有两种做法:

1. **自动(推荐)**: 删掉 `fonts/` 目录再运行 `convert.sh`,
   脚本检测到缓存缺失会自动扫描新机器的系统字体重建。
2. **手动**: 在新机器上执行上面"重建字体缓存"的命令。

⚠️ 最小化安装的系统可能没有中文字体, 重建缓存前先装字体包,
否则 PDF 里中文会变方框:

- Debian/Ubuntu: `apt install fonts-liberation fonts-noto-cjk`
- CentOS/RHEL/Fedora: `dnf install google-noto-sans-cjk-ttc-fonts`

如需跨机器渲染效果完全一致(不依赖各机器装了什么字体),
把 .ttf/.otf 字体文件放进包内一个目录(如 `fonts/custom/`),
迁移后执行:

```bash
EXTRA_FONTS_DIR=/abs/path/linux/fonts/custom ./convert.sh in.docx out.pdf
# 或直接:
converter/x2t -create-allfonts /abs/path/linux/fonts /abs/path/linux/fonts/custom
```

注意开源字体(如 Noto、Liberation)才可随意分发, 商业字体有授权限制。

## 备注

- 仅 x86-64。已在 CentOS Stream 9 实测 docx→pdf(含中文)、docx→odt、
  xlsx→pdf、pptx→pdf 及首次运行自动重建字体缓存, 全部通过。
- 组件来自 ONLYOFFICE (AGPL v3), 商用请注意许可证。
