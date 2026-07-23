@echo off
rem ONLYOFFICE x2t standalone converter wrapper
rem Usage: convert.bat <input_file> <output_file>
rem Conversion direction is inferred from file extensions,
rem e.g.: convert.bat a.docx a.pdf
setlocal EnableDelayedExpansion

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

if "%~2"=="" (
    echo usage: %~nx0 ^<input_file^> ^<output_file^> 1>&2
    exit /b 1
)

for %%I in ("%~1") do set "IN=%%~fI"
for %%I in ("%~2") do set "OUT=%%~fI"

rem The font cache is bound to the machine that generated it
rem (AllFonts.js stores absolute paths). Rebuild automatically
rem by scanning this machine's system fonts when missing.
if not exist "%ROOT%\fonts\AllFonts.js" goto buildcache
if not exist "%ROOT%\fonts\font_selection.bin" goto buildcache
goto cacheok
:buildcache
echo fonts cache missing, scanning system fonts... 1>&2
if not exist "%ROOT%\fonts" mkdir "%ROOT%\fonts"
"%ROOT%\converter\x2t.exe" -create-allfonts "%ROOT%\fonts" 1>&2
rem Sync to the fallback <allfonts> path of DoctRenderer.config
copy /y "%ROOT%\fonts\AllFonts.js" "%ROOT%\editors\sdkjs\common\AllFonts.js" >nul
:cacheok

set "TMP=%TEMP%\x2t_%RANDOM%%RANDOM%"
mkdir "%TMP%"

rem Write params.xml as real UTF-8 via PowerShell. cmd echo writes in the
rem console ANSI codepage (GBK on Chinese Windows); if any path contains
rem non-ASCII characters (Chinese filename or Chinese user name in %%TEMP%%),
rem the bytes will not match the declared encoding="utf-8" and x2t fails with
rem "Couldn't recognize conversion direction from an argument".
rem Paths go through env vars + SecurityElement.Escape so Unicode, spaces
rem and & are all safe.
set "X2T_IN=%IN%"
set "X2T_OUT=%OUT%"
set "X2T_ROOT=%ROOT%"
set "X2T_TMP=%TMP%"
powershell -NoProfile -Command "$x='<?xml version=\"1.0\" encoding=\"utf-8\"?><TaskQueueDataConvert><m_sFileFrom>'+[Security.SecurityElement]::Escape($env:X2T_IN)+'</m_sFileFrom><m_sFileTo>'+[Security.SecurityElement]::Escape($env:X2T_OUT)+'</m_sFileTo><m_sAllFontsPath>'+[Security.SecurityElement]::Escape($env:X2T_ROOT+'\fonts\AllFonts.js')+'</m_sAllFontsPath><m_sFontDir>'+[Security.SecurityElement]::Escape($env:X2T_ROOT+'\fonts')+'</m_sFontDir><m_sTempDir>'+[Security.SecurityElement]::Escape($env:X2T_TMP)+'</m_sTempDir></TaskQueueDataConvert>'; [IO.File]::WriteAllText((Join-Path $env:X2T_TMP 'params.xml'), $x)"
if errorlevel 1 (
    echo failed to write params.xml 1>&2
    rmdir /s /q "%TMP%"
    exit /b 1
)

"%ROOT%\converter\x2t.exe" "%TMP%\params.xml"
set "RC=%ERRORLEVEL%"

rmdir /s /q "%TMP%"
exit /b %RC%
