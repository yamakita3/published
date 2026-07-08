@echo off
chcp 65001 > nul
setlocal

REM =============================================
REM GeoTIFF → PNG + ワールドファイル 一括変換
REM WSL経由でPythonスクリプトを実行
REM =============================================

REM --- 設定 ---
REM Windowsのフォルダパスを指定（日本語フォルダ名不可）
set INPUT_DIR=C:\Users\%USERNAME%\Downloads\tif_files
set OUTPUT_DIR=C:\Users\%USERNAME%\Downloads\tif_files\png_output

REM ストレッチ範囲（反射率）
set STRETCH_MIN=0.02
set STRETCH_MAX=0.25

REM このbatファイルと同じフォルダにあるPythonスクリプトのパス
set SCRIPT_DIR=%~dp0
set SCRIPT_NAME=tif2png.py

REM --- WindowsパスをWSLパスに変換 ---
for /f "delims=" %%i in ('wsl wslpath -u "%INPUT_DIR%"') do set WSL_INPUT=%%i
for /f "delims=" %%i in ('wsl wslpath -u "%OUTPUT_DIR%"') do set WSL_OUTPUT=%%i
for /f "delims=" %%i in ('wsl wslpath -u "%SCRIPT_DIR%%SCRIPT_NAME%"') do set WSL_SCRIPT=%%i

echo =============================================
echo  GeoTIFF to PNG 一括変換
echo =============================================
echo  入力フォルダ: %INPUT_DIR%
echo  出力フォルダ: %OUTPUT_DIR%
echo  ストレッチ:   %STRETCH_MIN% 〜 %STRETCH_MAX%
echo =============================================

REM --- 依存ライブラリの確認・インストール ---
echo [1/3] 依存ライブラリを確認中...
wsl python3 -c "import rasterio, PIL, numpy" 2>nul
if errorlevel 1 (
    echo     rasterio/Pillow/numpy をインストール中...
    wsl pip install rasterio Pillow numpy -q
)
echo     OK

REM --- 変換実行 ---
echo [2/3] 変換を開始します...
wsl python3 "%WSL_SCRIPT%" "%WSL_INPUT%" "%WSL_OUTPUT%" --min %STRETCH_MIN% --max %STRETCH_MAX%

if errorlevel 1 (
    echo [ERROR] 変換中にエラーが発生しました
    pause
    exit /b 1
)

REM --- 完了 ---
echo [3/3] 完了
echo  出力先: %OUTPUT_DIR%
echo.
pause
