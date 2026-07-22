# ONLYOFFICE 文件转换组件剥离操作说明 (Windows / Linux)

> 本文档是写给执行剥离工作的会话的操作手册。
> macOS 版已按此流程完成(产物即本文档所在的 `macos/` 目录,用法见其 `README.md`),
> 现在需要在 **Windows** 和 **Linux** 上复刻同样的工作。
> 读完本文档再动手,文中标注的"坑"都是 macOS 版实际踩过并解决的。

---

## 1. 目标

从 ONLYOFFICE Desktop Editors 桌面应用中,把文档格式转换相关的组件剥离出来,
形成一个**脱离 GUI、可独立运行的命令行转换工具**。

各平台产物以平台名命名、并列放在同一父目录下:

```
<父目录>/
├── macos/      # 已完成
├── linux/      # 本次任务
└── windows/    # 本次任务
```

最终产物必须满足(验收标准):

1. 平台目录(`linux/` 或 `windows/`)可以整体拷贝到同平台另一台干净机器上使用;
2. 提供包装脚本(Windows: `convert.bat`,Linux: `convert.sh`),
   用法为 `./convert.sh input.docx output.pdf`,转换方向由扩展名自动推断;
3. 以下转换全部实测通过:
   - docx → pdf(含中文内容,渲染无乱码)
   - docx → odt
   - xlsx → pdf
   - pptx → pdf
4. 首次运行(字体缓存缺失)时脚本自动重建字体缓存并成功转换;
5. 附带 `README.md`,说明目录结构、用法、迁移/字体缓存重建方法。

## 2. 背景知识(已从 macOS 版摸清,直接可用)

### 2.1 转换核心是什么

桌面版 ONLYOFFICE 的格式转换由一个叫 **`x2t`** 的命令行程序完成
(Windows: `x2t.exe`;Linux/macOS: `x2t`)。
它依赖一组同目录的原生库(Windows 是 DLL,Linux 是 .so,macOS 是 .framework),
以及一份 `DoctRenderer.config` 指向的 JS 排版引擎(sdkjs)。

源码开源,参数解析逻辑见(需要确认细节时直接读):
- https://raw.githubusercontent.com/ONLYOFFICE/core/master/X2tConverter/src/main.cpp
- https://raw.githubusercontent.com/ONLYOFFICE/core/master/X2tConverter/src/cextracttools.h

### 2.2 x2t 的两种调用方式

**方式一:XML 参数文件(推荐,包装脚本用这种方式)**

```
x2t /path/to/params.xml
```

params.xml 内容(元素名区分大小写,与源码中 InputParams 成员名一致):

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

**方式二:位置参数**

```
x2t <输入文件> <输出文件> [字体缓存目录]
```

> ⚠️ 坑 1:第三个位置参数是 **font_selection.bin 所在的字体目录,不是临时目录**。
> 误传临时目录会导致"空文档能转、有文字的文档必崩"。

**辅助命令:生成字体缓存**

```
x2t -create-allfonts <输出目录> [额外字体目录...]
```

扫描系统字体(以及可选的额外字体目录),在输出目录生成
`AllFonts.js`、`font_selection.bin`、`fonts.log` 三个文件。

### 2.3 ⚠️ 坑 2(最重要):AllFonts.js 不在安装包里

`DoctRenderer.config` 里引用了 `<allfonts>../editors/sdkjs/common/AllFonts.js</allfonts>`,
但**安装包内并不存在这个文件**——GUI 版首次运行时才扫描系统字体生成,
存在用户数据目录而不在安装目录。

缺失时的症状:
- 直接报 `TypeError: undefined is not an object (evaluating 'e.length')`
  + `DoctRenderer:<result><error code="open" /></result>`;或
- 空文档转换成功、**任何含文字的文档转换时崩溃**
  (macOS 表现为 `CPdfWriter::GetFontPath` 段错误,其他平台类似)。

**解决办法**:剥离完成后,立即执行一次 `x2t -create-allfonts <standalone>/fonts`,
并把生成的 `AllFonts.js` 同时拷贝一份到 `editors/sdkjs/common/AllFonts.js`
(对应 `DoctRenderer.config` 的兜底路径)。

### 2.4 ⚠️ 坑 3:目录相对布局必须保持镜像

`DoctRenderer.config` 内容是相对路径:

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

所以剥离产物必须保持如下相对结构(`converter` 与 `editors`、`dictionaries` 同级;
顶层目录名按平台取 `macos` / `linux` / `windows`):

```
<平台目录>/
├── converter/            # x2t + 全部原生库 + DoctRenderer.config + empty/ + templates/
├── editors/
│   ├── sdkjs/            # 整个目录
│   └── web-apps/vendor/xregexp/
├── dictionaries/         # 整个目录(hunspell 拼写字典)
└── fonts/                # 自建,x2t -create-allfonts 生成
```

`editors/` 下其余内容(sdkjs-plugins、web-apps 主程序、webext)不需要,不要拷贝。

### 2.5 库依赖自包含

x2t 的原生库全部在 `converter/` 同目录,通过相对 rpath/加载路径解析
(macOS 是 `@executable_path`,Linux 是 `$ORIGIN`,Windows 是 exe 同目录 DLL 搜索)。
整体拷贝 `converter/` 即可,不要用系统的包管理器去装ONLYOFFICE的库混用。
Linux 上拷贝后用 `ldd converter/x2t | grep "not found"` 检查是否缺系统库
(如 libstdc++、libcurl 等,缺什么装什么)。

### 2.6 字体缓存与机器绑定

`AllFonts.js` 里记录的是扫描到的字体文件**绝对路径**,换机器后必须重建
(同 OS 版本直接拷通常也能用,但用户自装字体差异会导致排版 fallback)。
包装脚本里要有"缓存缺失则自动重建"的逻辑(见 4.3 节参考脚本)。

Linux 注意:最小化安装的系统可能没有中文字体,重建缓存前先装字体包
(如 Debian/Ubuntu: `fonts-liberation fonts-noto-cjk`;
CentOS/RHEL: `google-noto-sans-cjk-fonts`),否则中文渲染会变方框。

## 3. 获取安装包

版本与 macOS 版对齐:**Desktop Editors 9.4.0**。
从官方下载页或 GitHub Releases 获取:

- 下载页: https://www.onlyoffice.com/download-desktop.aspx
- Releases: https://github.com/ONLYOFFICE/DesktopEditors/releases

- **Windows**: 下载 64 位安装 exe,安装到默认目录
  (`C:\Program Files\ONLYOFFICE\DesktopEditors\`)。
  也可以用 7-Zip 直接解包 exe 避免安装(NSIS 安装包通常可解)。
- **Linux**: 优先下载对应发行版的 deb/rpm 安装;
  也可以用 `dpkg -x xxx.deb out/` 或 `rpm2cpio xxx.rpm | cpio -idmv` 解包。
  安装后文件在 `/opt/onlyoffice/desktopeditors/`。

## 4. 操作步骤(两个平台相同,路径按平台替换)

### 4.1 定位源文件

安装/解包后,确认以下路径存在(Windows 在 `C:\Program Files\ONLYOFFICE\DesktopEditors\`,
Linux 在 `/opt/onlyoffice/desktopeditors/`):

```
converter/          # 内含 x2t(.exe) 和全部原生库、DoctRenderer.config、empty、templates
editors/sdkjs/
editors/web-apps/vendor/xregexp/
dictionaries/
```

### 4.2 拷贝组件

按 2.4 节的结构拷贝(保持 `converter`、`editors`、`dictionaries` 同级;
Linux 产物目录名为 `linux/`,Windows 为 `windows/`)。
Linux 示例:

```bash
mkdir -p linux/editors/web-apps/vendor
cp -r /opt/onlyoffice/desktopeditors/converter linux/converter
cp -r /opt/onlyoffice/desktopeditors/editors/sdkjs linux/editors/sdkjs
cp -r /opt/onlyoffice/desktopeditors/editors/web-apps/vendor/xregexp \
      linux/editors/web-apps/vendor/xregexp
cp -r /opt/onlyoffice/desktopeditors/dictionaries linux/dictionaries
```

Linux 拷贝后跑 `ldd linux/converter/x2t | grep "not found"` 检查依赖。

### 4.3 生成字体缓存 + 写包装脚本

```bash
mkdir -p linux/fonts
linux/converter/x2t -create-allfonts "$PWD/linux/fonts"
cp linux/fonts/AllFonts.js linux/editors/sdkjs/common/AllFonts.js
```

包装脚本逻辑(macOS 版 `macos/convert.sh` 可作参考模板):

1. 解析脚本自身所在目录为 ROOT;
2. 若 `fonts/AllFonts.js` 或 `fonts/font_selection.bin` 缺失:
   执行 `x2t -create-allfonts "$ROOT/fonts"`,然后
   `cp "$ROOT/fonts/AllFonts.js" "$ROOT/editors/sdkjs/common/AllFonts.js"`;
3. 用 `mktemp -d`(Windows 用 `%TEMP%\` 下随机目录)创建每进程独立临时目录,
   注册退出清理(bash 用 `trap ... EXIT`,bat 在脚本末尾删);
4. 在临时目录生成 params.xml(格式见 2.2),调用 `x2t params.xml`。
   注意 XML 中所有路径用绝对路径。

### 4.4 写 README.md

参照 macOS 版 `macos/README.md`,包含:目录结构、用法、
params.xml 格式、位置参数第三个参数是字体目录的提醒、
迁移到新机器后删 `fonts/` 自动重建的说明、AGPL v3 许可证提醒。

## 5. 验证(必须全部通过才算完成)

### 5.1 制作带中文的测试 docx

各平台通用,用 Python 生成(不装任何第三方库):

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
z = zipfile.ZipFile('test.docx', 'w')
z.writestr('[Content_Types].xml', ct)
z.writestr('_rels/.rels', rels)
z.writestr('word/document.xml', doc)
z.close()
```

> 注意:不要用 macOS 的 textutil 生成测试文件,它不声明 charset 时会把
> UTF-8 中文按 Latin-1 解释,造出源文件本身就是乱码的"假失败"。

xlsx/pptx 测试输入直接用 `converter/empty/default/new.xlsx`、`new.pptx`。

### 5.2 逐项验证

| 测试 | 命令 | 通过标准 |
|---|---|---|
| docx→pdf | `./convert.sh test.docx out.pdf` | 生成有效 PDF;渲染成图片肉眼确认中英文都正确显示 |
| docx→odt | `./convert.sh test.docx out.odt` | 文件头为合法 ODF(zip, mimetype=odt) |
| xlsx→pdf | `./convert.sh new.xlsx x.pdf` | 有效 PDF |
| pptx→pdf | `./convert.sh new.pptx p.pdf` | 有效 PDF |
| 首次运行自动建缓存 | 删掉 `fonts/` 和 `editors/sdkjs/common/AllFonts.js` 后重复 docx→pdf | 自动重建缓存且转换成功,两处 AllFonts.js 内容一致 |

PDF 内容检查方法:Linux 用 `pdftoppm -png out.pdf page` 或 `pdftotext out.pdf -`;
Windows 可用脚本调 Edge/查看器截图,或装 Python 的 pdf2image。
中文显示为方框/乱码时,先怀疑系统缺中文字体(见 2.6),而不是转换器本身。

### 5.3 常见问题速查

| 症状 | 原因 | 解决 |
|---|---|---|
| `TypeError ... e.length` + `error code="open"` | AllFonts.js 缺失 | 跑 `-create-allfonts` 并同步到 sdkjs/common |
| 空文档能转、有文字的崩溃(GetFontPath) | 字体缓存缺失或位置参数第三个参数误传临时目录 | 同上;检查调用方式 |
| 转换 exit=0 但无输出文件、无任何报错 | 输入文件损坏,或格式不受支持 | 换 5.1 的标准测试文件排除 |
| Linux 中文变方框 | 系统无 CJK 字体 | 装 fonts-noto-cjk 后重建字体缓存 |
| ldd 报 not found | 缺系统库 | 按缺的包装对应系统包 |

## 6. 许可证提醒

组件来自 ONLYOFFICE(AGPL v3),分发/商用需注意许可证义务,
README 中保留该提醒。
