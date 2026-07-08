@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

REM =============================================
REM copy_pgw_to_png.bat
REM 使い方: コピー元の .pgw をこのBATにD&Dして実行
REM 処理:   BATと同じフォルダの全.pngに同名.pgwをコピー
REM =============================================

REM --- D&D引数チェック ---
if "%~1"=="" (
    echo [ERROR] .pgw ファイルをこのBATにドラッグアンドドロップして実行してください
    echo.
    pause
    exit /b 1
)

REM --- 拡張子チェック ---
if /I NOT "%~x1"==".pgw" (
    echo [ERROR] ドロップされたファイルが .pgw ではありません
    echo         受け取ったファイル: %~nx1
    echo         拡張子: %~x1
    echo.
    pause
    exit /b 1
)

REM --- パス設定 ---
set "INPUT_DIR=%~dp0"
set "SOURCE_PGW=%~1"

echo [INFO] 実行フォルダ: %INPUT_DIR%
echo [INFO] コピー元PGW : %~nx1
echo.

REM --- フォルダ内の全ファイルをデバッグ表示 ---
echo [DEBUG] フォルダ内のファイル一覧:
for %%F in ("%INPUT_DIR%*") do (
    echo   %%~nxF
)
echo.

REM --- .pngファイルのみ抽出（複合拡張子除外）---
echo [DEBUG] 対象PNGファイル一覧（.pngのみ / .aux.xmlなど除外）:
set png_count=0
for %%F in ("%INPUT_DIR%*.png") do (
    REM %%~xF が .png であること（.png.aux.xmlなど複合拡張子を除外）
    if /I "%%~xF"==".png" (
        echo   %%~nxF
        set /a png_count+=1
    ) else (
        echo   [SKIP] %%~nxF  ^(拡張子: %%~xF^)
    )
)
echo.
echo [INFO] 対象PNGファイル数: %png_count% 件
echo.

if %png_count%==0 (
    echo [WARNING] 処理対象のPNGファイルが見つかりませんでした
    pause
    exit /b 0
)

REM --- メイン処理 ---
echo [INFO] コピー開始...
set count=0
set err_count=0

for %%F in ("%INPUT_DIR%*.png") do (
    if /I "%%~xF"==".png" (
        set "dest_pgw=%%~dpnF.pgw"
        copy /Y "%SOURCE_PGW%" "!dest_pgw!" > nul
        if !errorlevel! neq 0 (
            echo   [ERROR] コピー失敗: %%~nxF
            set /a err_count+=1
        ) else (
            echo   [OK] %%~nxF  -^>  %%~nF.pgw
            set /a count+=1
        )
    )
)

echo.
echo [INFO] 完了  成功: %count% 件  失敗: %err_count% 件
echo.
pause
