# ONLYOFFICE 转换组件独立版 (windows)

从 ONLYOFFICE Desktop Editors 9.4.0 (Windows x64) 剥离出的文档格式转换组件,
可脱离 GUI 独立运行。核心是 `converter\x2t.exe` 命令行转换器。

## 目录结构

- `converter\` — x2t.exe + 全部原生 DLL (doctrenderer, PdfFile, graphics,
  kernel, DocxRenderer, HWPFile, DjVuFile, EpubFile, Fb2File, HtmlFile2,
  IWorkFile, OFDFile, XpsFile, StarMathConverter, ooxmlsignature,
  UnicodeConverter, kernel_network, icu*), `DoctRenderer.config`,
  空文档模板 (`empty\`), 区域模板 (`templates\`)
- `editors\sdkjs\` — 文档排版/渲染 JS 引擎 (doctrenderer 运行时加载)
- `editors\web-apps\vendor\xregexp\` — sdkjs 依赖
- `dictionaries\` — hunspell 拼写字典
- `fonts\` — 首次运行时由 `x2t.exe -create-allfonts` 扫描本机系统字体生成
  (`AllFonts.js` + `font_selection.bin`; PDF/图片输出必需, 缺了含文字的
  文档转换会崩溃)。`convert.bat` 检测到缺失会自动重建
- `convert.bat` — 转换包装脚本

## 用法

```bat
convert.bat input.docx output.pdf
convert.bat input.docx output.odt
convert.bat input.xlsx output.pdf
convert.bat input.pptx output.pdf
```

转换方向由文件扩展名自动推断。支持的输入: docx/doc/odt/rtf/txt/html/
epub/fb2/xlsx/xls/ods/csv/pptx/ppt/odp/vsdx/pdf/djvu/xps/hwp 等;
输出: docx/odt/rtf/txt/pdf/html/xlsx/ods/csv/pptx/odp 等。

首次运行会自动扫描系统字体生成 `fonts\` 缓存(一次性, 约几秒)。

## 直接调用 x2t (XML 参数方式)

```bat
converter\x2t.exe params.xml
```

params.xml 格式(所有路径用绝对路径):

```xml
<?xml version="1.0" encoding="utf-8"?>
<TaskQueueDataConvert>
<m_sFileFrom>C:\abs\path\in.docx</m_sFileFrom>
<m_sFileTo>C:\abs\path\out.pdf</m_sFileTo>
<m_sAllFontsPath>C:\abs\path\fonts\AllFonts.js</m_sAllFontsPath>
<m_sFontDir>C:\abs\path\fonts</m_sFontDir>
<m_sTempDir>C:\abs\path\temp</m_sTempDir>
</TaskQueueDataConvert>
```

也支持位置参数: `x2t.exe <输入> <输出> [font_selection.bin 所在目录]`,
注意第三个参数是**字体目录**, 不是临时目录。

> 注意: params.xml 必须保存为**真实 UTF-8 编码**。不要用 cmd 的
> `echo >>` 生成——它按控制台 ANSI 代码页(中文系统是 GBK)写字节,
> 路径里只要有中文(文件名或用户名)就会报
> "Couldn't recognize conversion direction from an argument"。
> `convert.bat` 内部已改用 PowerShell 写 UTF-8 并对路径做 XML 转义。

## 重建字体缓存

系统字体变化后重新生成:

```bat
converter\x2t.exe -create-allfonts C:\abs\path\windows\fonts
copy /y fonts\AllFonts.js editors\sdkjs\common\AllFonts.js
```

## 迁移到新机器

`fonts\AllFonts.js` 记录的是生成机器上字体文件的绝对路径,
字体缓存与机器绑定。迁移后有两种做法:

1. **自动(推荐)**: 删掉 `fonts\` 目录再运行 `convert.bat`,
   脚本检测到缓存缺失会自动扫描新机器的系统字体重建。
   (本包发布时就不含 `fonts\`, 首次运行即走这条路径。)
2. **手动**: 在新机器上执行上面"重建字体缓存"的命令。

如需跨机器渲染效果完全一致(不依赖各机器装了什么字体),
把 .ttf/.otf 字体文件放进包内一个目录(如 `fonts\custom\`),
把该目录作为额外参数传给 `-create-allfonts`:

```bat
converter\x2t.exe -create-allfonts C:\abs\path\windows\fonts C:\abs\path\windows\fonts\custom
copy /y fonts\AllFonts.js editors\sdkjs\common\AllFonts.js
```

注意开源字体(如 Noto、Liberation)才可随意分发, 商业字体有授权限制。

中文显示为方框/乱码时, 先确认系统装有中文字体
(Windows 自带微软雅黑/宋体即可, 精简版系统可能被裁掉), 再重建缓存。

## 备注

- 仅 64 位 Windows。DLL 全部由 `converter\` 同目录加载, 整体拷贝即用,
  不要与本机安装的 ONLYOFFICE 目录混用。
- 已在 Wine 8.0 (CentOS Stream 9) 下实测 docx→pdf(含中文)、docx→odt、
  xlsx→pdf、pptx→pdf 及首次运行自动重建字体缓存, 全部通过。
- 组件来自 ONLYOFFICE (AGPL v3), 商用请注意许可证。
