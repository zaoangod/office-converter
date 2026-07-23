# ONLYOFFICE 文件转换组件剥离操作说明 (全平台)

> 本文档是剥离工作的操作手册，适用于 **macOS / Linux / Windows** 三个平台。
> 三个平台的产物已按此流程完成 (`macos/`、`linux/`、`windows/`)，
> 本文档用于：新版本 ONLYOFFICE 发布后重新剥离、或在其他同类平台上复刻。
> 文中标注的"坑"都是实际踩过并解决的，动手前先读完。

---

## 1. 目标

从 ONLYOFFICE Desktop Editors 桌面应用中，把文档格式转换相关的组件剥离出来，形成一个 **脱离 GUI、可独立运行的命令行转换工具**。

各平台产物以平台名命名、并列放在同一父目录下：

```
<父目录>/
├── macos/      # macOS (arm64)
├── linux/      # Linux (x86_64)
└── windows/    # Windows (x86_64)
```

最终产物必须满足 (验收标准)：

1. 平台目录可以整体拷贝到同平台另一台干净机器上使用;
2. 提供包装脚本 (macOS/Linux: `convert.sh`，Windows: `convert.bat`)，用法为 `./convert.sh input.docx output.pdf`，转换方向由扩展名自动推断;
3. 以下转换全部实测通过：
   - docx → pdf (含中文内容，渲染无乱码)
   - docx → odt
   - xlsx → pdf
   - pptx → pdf
4. 首次运行 (字体缓存缺失)时脚本自动重建字体缓存并成功转换;
5. 附带 `README.md`，说明目录结构、用法、迁移/字体缓存重建方法。

## 2. 背景知识 (全平台通用，直接可用)

### 2.1 转换核心是什么

桌面版 ONLYOFFICE 的格式转换由一个叫 **`x2t`** 的命令行程序完成 (Windows: `x2t.exe`;Linux/macOS: `x2t`)。
它依赖一组同目录的原生库 (Windows 是 DLL，Linux 是 .so，macOS 是 .framework)，以及一份 `DoctRenderer.config` 指向的 JS 排版引擎 (sdkjs)。

注意：ONLYOFFICE 的排版/布局逻辑就是用 JavaScript 写的 (sdkjs)，转换器通过内嵌 V8 (doctrenderer 库)在无头环境跑同一套编辑器 JS 代码，所以 `editors/sdkjs` 这些"前端资源"是转换器的必需组件，不是多余物。

源码开源，参数解析逻辑见 (需要确认细节时直接读)：

- https://raw.githubusercontent.com/ONLYOFFICE/core/master/X2tConverter/src/main.cpp
- https://raw.githubusercontent.com/ONLYOFFICE/core/master/X2tConverter/src/cextracttools.h

### 2.2 x2t 的两种调用方式

**方式一：XML 参数文件 (推荐，包装脚本用这种方式)**

```
x2t /path/to/params.xml
```

params.xml 内容 (元素名区分大小写，与源码中 InputParams 成员名一致):

```xml
<?xml version="1.0" encoding="utf-8"?>
<TaskQueueDataConvert>
    <m_sFileFrom>/abs/path/in.docx</m_sFileFrom>
    <m_sFileTo>/abs/path/out.pdf</m_sFileTo>
    <m_sAllFontsPath>/abs/path/fonts/AllFonts.js</m_sAllFontsPath>
    <m_sFontDir>/abs/path/fonts</m_sFontDir>
    <m_sTempDir>/abs/path/to/unique/tempdir</m_sTempDir>
</TaskQueueDataConvert>
```

params.xml 必须保存为 **真实 UTF-8 编码**，且路径中的 `&` `<` `>` 要做 XML 转义。
Windows 上切勿用 cmd `echo` 生成 (会按 ANSI/GBK 代码页写字节，中文路径必挂，见 5.3 速查表)。

**方式二：位置参数**

```
x2t <输入文件> <输出文件> [字体缓存目录]
```

> ⚠️ 坑 1：第三个位置参数是 **font_selection.bin 所在的字体目录，不是临时目录**。
> 误传临时目录会导致"空文档能转、有文字的文档必崩"。

**辅助命令：生成字体缓存**

```
x2t -create-allfonts <输出目录> [额外字体目录...]
```

扫描系统字体 (以及可选的额外字体目录)，在输出目录生成 `AllFonts.js`、`font_selection.bin`、`fonts.log` 三个文件。

### 2.3 ⚠️ 坑 2 (最重要)：AllFonts.js 不在安装包里

`DoctRenderer.config` 里引用了 `<allfonts>../editors/sdkjs/common/AllFonts.js</allfonts>`，但 **安装包内并不存在这个文件**——GUI 版首次运行时才扫描系统字体生成，存在用户数据目录而不在安装目录。

缺失时的症状：

- 直接报 `TypeError: undefined is not an object (evaluating 'e.length')` + `DoctRenderer:<result><error code="open" /></result>`;或
- 空文档转换成功、 **任何含文字的文档转换时崩溃** (macOS 表现为 `CPdfWriter::GetFontPath` 段错误，其他平台类似)。

**解决办法**：剥离完成后，立即执行一次 `x2t -create-allfonts <平台目录>/fonts`，并把生成的 `AllFonts.js` 同时拷贝一份到 `editors/sdkjs/common/AllFonts.js` (对应 `DoctRenderer.config` 的兜底路径)。

### 2.4 ⚠️ 坑 3：目录相对布局必须保持镜像

`DoctRenderer.config` 内容是相对路径：

```xml

<Settings>
    <file>../editors/sdkjs/common/Native/native.js</file>
    <file>../editors/sdkjs/common/Native/jquery_native.js</file>
    <allfonts>../editors/sdkjs/common/AllFonts.js</allfonts>
    <file>../editors/web-apps/vendor/xregexp/xregexp-all-min.js</file>
    <sdkjs>../editors/sdkjs</sdkjs>
    <dictionaries>../dictionaries</dictionaries>
</Settings>
```

所以剥离产物必须保持如下相对结构 (`converter` 与 `editors`、`dictionaries` 同级；顶层目录名按平台取 `macos` / `linux` / `windows`)：

```
<平台目录>/
├── converter/            # x2t + 全部原生库 + DoctRenderer.config + empty/ + templates/
├── editors/
│   ├── sdkjs/            # 整个目录
│   └── web-apps/vendor/xregexp/
├── dictionaries/         # 整个目录(hunspell 拼写字典)
└── fonts/                # 自建，x2t -create-allfonts 生成
```

`editors/` 下其余内容 (sdkjs-plugins、web-apps 主程序、webext)不需要，不要拷贝。

### 2.5 库依赖自包含

x2t 的原生库全部在 `converter/` 同目录，通过相对 rpath/加载路径解析 (macOS 是 `@executable_path`，Linux 是 `$ORIGIN`，Windows 是 exe 同目录 DLL 搜索)。
整体拷贝 `converter/` 即可，不要用系统的包管理器去装ONLYOFFICE的库混用。

各平台依赖检查：

- Linux：`ldd converter/x2t | grep "not found"`，缺什么系统库装什么 (如 libstdc++、libcurl 等)；
- macOS：`otool -L converter/x2t` 及各 .framework，确认无 @rpath 之外的非系统依赖；
- Windows：用 `dumpbin /dependents converter\x2t.exe` 或 Dependencies 工具，缺 DLL 一般是 VC++ 运行库，装对应的 Visual C++ Redistributable。

### 2.6 字体缓存与机器绑定

`AllFonts.js` 里记录的是扫描到的字体文件 **绝对路径**，换机器后必须重建 (同 OS 版本直接拷通常也能用，但用户自装字体差异会导致排版 fallback)。
包装脚本里要有"缓存缺失则自动重建"的逻辑 (见 4.3 节)。

各平台字体注意：

- Linux：最小化安装的系统可能没有中文字体，重建缓存前先装字体包 (Debian/Ubuntu: `fonts-liberation fonts-noto-cjk`；CentOS/RHEL：`google-noto-sans-cjk-fonts`)，否则中文渲染会变方框；
- macOS：系统字体齐全，一般无需处理;首次运行如被 Gatekeeper 拦截，在"系统设置 > 隐私与安全性"中放行;
- Windows：系统字体齐全;如机器装有中文 Windows，字体目录 `C:\Windows\Fonts` 已含中文字体。

## 3. 获取安装包

各平台使用同一版本号 (当前为 **Desktop Editors 9.4.0**)。
从官方下载页或 GitHub Releases 获取：

- 下载页：https://www.onlyoffice.com/download-desktop.aspx
- Releases：https://github.com/ONLYOFFICE/DesktopEditors/releases

各平台安装/解包方式与源文件位置：

| 平台    | 获取方式                                                                            | 源文件位置                                    |
| ------- | ----------------------------------------------------------------------------------- | --------------------------------------------- |
| macOS   | 下载 dmg，把 ONLYOFFICE.app 拷出即可(无需安装)                                      | `ONLYOFFICE.app/Contents/Resources/`          |
| Windows | 下载 64 位 exe 安装;或用 7-Zip 直接解包(NSIS 通常可解)                              | `C:\Program Files\ONLYOFFICE\DesktopEditors\` |
| Linux   | 按发行版装 deb/rpm;或 `dpkg -x xxx.deb out/`、`rpm2cpio xxx.rpm \| cpio -idmv` 解包 | `/opt/onlyoffice/desktopeditors/`             |

deb 与 rpm 内容基本一致，按目标机器发行版选择即可 (见 2.5 依赖检查)。

## 4. 操作步骤 (各平台流程相同，路径按平台替换)

### 4.1 定位源文件

安装/解包后，在上表的源文件位置确认以下路径存在：

```
converter/          # 内含 x2t(.exe) 和全部原生库、DoctRenderer.config、empty、templates
editors/sdkjs/
editors/web-apps/vendor/xregexp/
dictionaries/
```

### 4.2 拷贝组件

按 2.4 节的结构拷贝 (保持 `converter`、`editors`、`dictionaries` 同级)。

macOS 示例：

```bash
mkdir -p macos/editors/web-apps/vendor
cp -R ONLYOFFICE.app/Contents/Resources/converter macos/converter
cp -R ONLYOFFICE.app/Contents/Resources/editors/sdkjs macos/editors/sdkjs
cp -R ONLYOFFICE.app/Contents/Resources/editors/web-apps/vendor/xregexp \
      macos/editors/web-apps/vendor/xregexp
cp -R ONLYOFFICE.app/Contents/Resources/dictionaries macos/dictionaries
```

Linux 示例：

```bash
mkdir -p linux/editors/web-apps/vendor
cp -r /opt/onlyoffice/desktopeditors/converter linux/converter
cp -r /opt/onlyoffice/desktopeditors/editors/sdkjs linux/editors/sdkjs
cp -r /opt/onlyoffice/desktopeditors/editors/web-apps/vendor/xregexp \
      linux/editors/web-apps/vendor/xregexp
cp -r /opt/onlyoffice/desktopeditors/dictionaries linux/dictionaries
```

Windows 示例 (PowerShell)：

```powershell
$src = 'C:\Program Files\ONLYOFFICE\DesktopEditors'
New-Item -ItemType Directory -Force windows\editors\web-apps\vendor
Copy-Item -Recurse "$src\converter" windows\converter
Copy-Item -Recurse "$src\editors\sdkjs" windows\editors\sdkjs
Copy-Item -Recurse "$src\editors\web-apps\vendor\xregexp" windows\editors\web-apps\vendor\xregexp
Copy-Item -Recurse "$src\dictionaries" windows\dictionaries
```

拷贝后按 2.5 做各平台的依赖检查。

### 4.3 生成字体缓存 + 写包装脚本

以 `<平台>` 代表 `macos` / `linux` / `windows`：

```bash
# macOS / Linux
mkdir -p <平台>/fonts
<平台>/converter/x2t -create-allfonts "$PWD/<平台>/fonts"
cp <平台>/fonts/AllFonts.js <平台>/editors/sdkjs/common/AllFonts.js
```

```bat
:: Windows
mkdir windows\fonts
windows\converter\x2t.exe -create-allfonts "%CD%\windows\fonts"
copy /y windows\fonts\AllFonts.js windows\editors\sdkjs\common\AllFonts.js
```

包装脚本逻辑 (参考模板：`macos/convert.sh`、`linux/convert.sh`、`windows/convert.bat`)：

1. 解析脚本自身所在目录为 ROOT;
2. 若 `fonts/AllFonts.js` 或 `fonts/font_selection.bin` 缺失：执行 `x2t -create-allfonts "$ROOT/fonts"`，然后把 `fonts/AllFonts.js` 同步到 `editors/sdkjs/common/AllFonts.js`;
3. 创建每进程独立临时目录 (macOS/Linux 用 `mktemp -d`，Windows 用 `%TEMP%\` 下随机目录)，注册退出清理 (bash 用 `trap ... EXIT`，bat 在脚本末尾删);
4. 在临时目录生成 params.xml (格式见 2.2)，调用 `x2t params.xml`。
   注意：XML 中所有路径用绝对路径;文件必须是 **真实 UTF-8**；路径做 XML 转义。Windows 的 bat 里用 PowerShell `[IO.File]::WriteAllText` + `[Security.SecurityElement]::Escape` 实现 (cmd `echo` 是 ANSI/GBK，中文路径必挂)。

### 4.4 写 README.md

参照现有各平台的 `README.md`，包含：目录结构、用法、params.xml 格式、位置参数第三个参数是字体目录的提醒、迁移到新机器后删 `fonts/` 自动重建的说明、AGPL v3 许可证提醒。

## 5. 验证 (必须全部通过才算完成)

### 5.1 制作带中文的测试 docx

各平台通用，用 Python 生成 (不装任何第三方库)：

```python
import zipfile
doc = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>转换测试 Conversion Test</w:t></w:r></w:p>
<w:p><w:r><w:t>Hello ONLYOFFICE x2t standalone. 中文内容测试。</w:t></w:r></w:p>
</w:body></w:document>'''
ct = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'''
rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'''
z = zipfile.ZipFile('test.docx'， 'w')
z.writestr('[Content_Types].xml'， ct)
z.writestr('_rels/.rels'， rels)
z.writestr('word/document.xml'， doc)
z.close()
```

> 注意：不要用 macOS 的 textutil 生成测试文件，它不声明 charset 时会把
> UTF-8 中文按 Latin-1 解释，造出源文件本身就是乱码的"假失败"。

xlsx/pptx 测试输入直接用 `converter/empty/default/new.xlsx`、`new.pptx`。

### 5.2 逐项验证

| 测试               | 命令(Windows 换成 convert.bat)                                      | 通过标准                                          |
| ------------------ | ------------------------------------------------------------------- | ------------------------------------------------- |
| docx→pdf           | `./convert.sh test.docx out.pdf`                                    | 生成有效 PDF;渲染成图片肉眼确认中英文都正确显示   |
| docx→odt           | `./convert.sh test.docx out.odt`                                    | 文件头为合法 ODF(zip， mimetype=odt)              |
| xlsx→pdf           | `./convert.sh new.xlsx x.pdf`                                       | 有效 PDF                                          |
| pptx→pdf           | `./convert.sh new.pptx p.pdf`                                       | 有效 PDF                                          |
| 首次运行自动建缓存 | 删掉 `fonts/` 和 `editors/sdkjs/common/AllFonts.js` 后重复 docx→pdf | 自动重建缓存且转换成功，两处 AllFonts.js 内容一致 |

PDF 内容检查方法：macOS 用 `sips -s format png out.pdf --out out.png`;
Linux 用 `pdftoppm -png out.pdf page` 或 `pdftotext out.pdf -`;
Windows 可用脚本调 Edge/查看器截图，或装 Python 的 pdf2image。
中文显示为方框/乱码时，先怀疑系统缺中文字体 (见 2.6)，而不是转换器本身。

### 5.3 常见问题速查

| 症状                                                                  | 原因                                                                                         | 解决                                                                                                |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `TypeError ... e.length` + `error code="open"`                        | AllFonts.js 缺失                                                                             | 跑 `-create-allfonts` 并同步到 sdkjs/common                                                         |
| 空文档能转、有文字的崩溃(GetFontPath)                                 | 字体缓存缺失或位置参数第三个参数误传临时目录                                                 | 同上;检查调用方式                                                                                   |
| 转换 exit=0 但无输出文件、无任何报错                                  | 输入文件损坏，或格式不受支持                                                                 | 换 5.1 的标准测试文件排除                                                                           |
| Linux 中文变方框                                                      | 系统无 CJK 字体                                                                              | 装 fonts-noto-cjk 后重建字体缓存                                                                    |
| ldd 报 not found                                                      | 缺系统库                                                                                     | 按缺的包装对应系统包                                                                                |
| Windows 报 `Couldn't recognize conversion direction from an argument` | params.xml 声明 utf-8 但实际是 ANSI/GBK 字节(cmd `echo` 按控制台代码页写文件， 中文路径必现) | 用 PowerShell `[IO.File]::WriteAllText` 写 UTF-8， 路径用 `[Security.SecurityElement]::Escape` 转义 |
| macOS 无法运行/报已损坏                                               | Gatekeeper 拦截或 quarantine 属性                                                            | 系统设置放行，或 `xattr -dr com.apple.quarantine <平台目录>`                                        |

## 6. 许可证提醒

组件来自 ONLYOFFICE (AGPL v3)，分发/商用需注意许可证义务，README 中保留该提醒。
