
*説明

0110_copy_pgw_to_png_v3CRLF_SJIS.bat：複数の画像で同じ線形幾何補正を実施する場合にpgwを各ファイル名にしてコピーするコマンド

0120_結果集計Terra_for04_sen_v01.R

0130_mono_result_zonal2_for04_sen_v02_255.xlsx

0140_集計結果の図化Sen_v02.r

0220_overlay_rgb_res_poly_Sentinel_v01.r

Read_mask_geotiff2ref_resolution_folder_v03 - コピー.r



**GEOTIFFからPNGにするコマンド群


run0_Geotiff2png_pgw_v01.py：Python版ver01ファイル名を指定しておく版

run_tif2png.bat&tif2png.py：Python版その２、バッチでフォルダ内実行版

GeoTIFF_to_PNG_PGW_WSL_v03.zip:Python版とWindows WSL用のバッチファイル、フォルダD&Dで実行版（最新版）


run_geotiff_to_png_batch3.ps1：Q-GISのgdaltranslateをフォルダ内に適用するWindowsのpowershell版、色のストレッチを指定割合(1で最大最小)にするか、固定値にするかを選択可能。

実行にはポリシーの解除が通常必要「PowerShell -ExecutionPolicy Bypass -File .\\run_geotiff_to_png_batch3.ps1」



GUIでの実行方法... Q-GISのgdaltranslateの追加のコマンドラインパラメータに「-co WORLDFILE=YES」を追加。


