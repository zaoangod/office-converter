#!/bin/bash
# ONLYOFFICE x2t standalone converter wrapper
# 用法: ./convert.sh <输入文件> <输出文件>
# 转换方向由扩展名自动推断, 例如: ./convert.sh a.docx a.pdf
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 2 ]; then
    echo "usage: $0 <input_file> <output_file>" >&2
    exit 1
fi

abs() { case "$1" in /*) echo "$1" ;; *) echo "$(pwd)/$1" ;; esac; }
IN="$(abs "$1")"
OUT="$(abs "$2")"

# 字体缓存是跟生成它的机器绑定的(AllFonts.js 内为绝对路径)。
# 迁移到新机器后若缺失, 自动扫描本机系统字体重建一次。
if [ ! -f "$ROOT/fonts/AllFonts.js" ] || [ ! -f "$ROOT/fonts/font_selection.bin" ]; then
    echo "fonts cache missing, scanning system fonts..." >&2
    mkdir -p "$ROOT/fonts"
    "$ROOT/converter/x2t" -create-allfonts "$ROOT/fonts" \
        ${EXTRA_FONTS_DIR:+"$EXTRA_FONTS_DIR"} >&2
    # 同步到 DoctRenderer.config 的 <allfonts> 兜底路径
    cp "$ROOT/fonts/AllFonts.js" "$ROOT/editors/sdkjs/common/AllFonts.js"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/params.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<TaskQueueDataConvert>
<m_sFileFrom>$IN</m_sFileFrom>
<m_sFileTo>$OUT</m_sFileTo>
<m_sAllFontsPath>$ROOT/fonts/AllFonts.js</m_sAllFontsPath>
<m_sFontDir>$ROOT/fonts</m_sFontDir>
<m_sTempDir>$TMP</m_sTempDir>
</TaskQueueDataConvert>
EOF

"$ROOT/converter/x2t" "$TMP/params.xml"
