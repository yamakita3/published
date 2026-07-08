import rasterio
import numpy as np
from PIL import Image
import os

# =============================================
# GeoTIFF → PNG + ワールドファイル変換
# =============================================

INPUT_TIF   = 'S2_RGB_median_2020_08.tif'
OUTPUT_PNG  = 'output/S2_RGB_median_2020_08.png'
STRETCH_MIN = 0.02   # 表示最小値（反射率）
STRETCH_MAX = 0.25   # 表示最大値（反射率30%相当）

os.makedirs('output', exist_ok=True)

with rasterio.open(INPUT_TIF) as src:
    data      = src.read()           # shape: (3, height, width)
    transform = src.transform
    crs       = src.crs
    width     = src.width
    height    = src.height
    nodata    = src.nodata

# =============================================
# 1. リニアストレッチ → 8bit (0〜255) に変換
# =============================================
def stretch_to_uint8(band, vmin, vmax):
    """リニアストレッチで0〜255の整数に変換"""
    stretched = (band - vmin) / (vmax - vmin)
    stretched = np.clip(stretched, 0, 1)
    return (stretched * 255).astype(np.uint8)

r_8bit = stretch_to_uint8(data[0], STRETCH_MIN, STRETCH_MAX)
g_8bit = stretch_to_uint8(data[1], STRETCH_MIN, STRETCH_MAX)
b_8bit = stretch_to_uint8(data[2], STRETCH_MIN, STRETCH_MAX)

# NoDataをアルファチャンネルで透過処理
if nodata is not None:
    nodata_mask = (data[0] == nodata)
    alpha = np.where(nodata_mask, 0, 255).astype(np.uint8)
    rgb_array = np.stack([r_8bit, g_8bit, b_8bit, alpha], axis=2)
    img = Image.fromarray(rgb_array, mode='RGBA')
else:
    rgb_array = np.stack([r_8bit, g_8bit, b_8bit], axis=2)
    img = Image.fromarray(rgb_array, mode='RGB')

# =============================================
# 2. PNG保存
# =============================================
img.save(OUTPUT_PNG)
print(f"PNG出力完了: {OUTPUT_PNG}")
print(f"  サイズ: {width} × {height} px")

# =============================================
# 3. ワールドファイル（.pgw）生成
# =============================================
# affine transformからワールドファイルの6パラメータを取得
# transform = | a  b  c |   a=X解像度, b=回転, c=左端X
#             | d  e  f |   d=回転,   e=Y解像度(負), f=上端Y
a = transform.a   # X方向ピクセルサイズ
b = transform.b   # 回転（通常0）
c = transform.c   # 左端X座標（ピクセル左上隅）
d = transform.d   # 回転（通常0）
e = transform.e   # Y方向ピクセルサイズ（負値）
f = transform.f   # 上端Y座標（ピクセル左上隅）

# ワールドファイルはピクセル中心座標なのでハーフピクセルオフセット
ulx = c + a * 0.5   # 左上ピクセル中心X
uly = f + e * 0.5   # 左上ピクセル中心Y

wf_lines = [
    f"{a:.10f}",    # X方向ピクセルサイズ
    f"{d:.10f}",    # 回転（0）
    f"{b:.10f}",    # 回転（0）
    f"{e:.10f}",    # Y方向ピクセルサイズ（負）
    f"{ulx:.10f}",  # 左上ピクセル中心X
    f"{uly:.10f}",  # 左上ピクセル中心Y
]

pgw_path = OUTPUT_PNG.replace('.png', '.pgw')
with open(pgw_path, 'w') as f_out:
    f_out.write('\n'.join(wf_lines))
print(f"ワールドファイル出力完了: {pgw_path}")

# =============================================
# 4. .prj（CRS情報）生成
# =============================================
prj_path = OUTPUT_PNG.replace('.png', '.prj')
with open(prj_path, 'w') as f_out:
    f_out.write(crs.to_wkt())
print(f"PRJファイル出力完了: {prj_path}")

# =============================================
# サマリー表示
# =============================================
print(f"\n=== 出力サマリー ===")
print(f"  ファイル:    {OUTPUT_PNG}")
print(f"  サイズ:      {width} × {height} px")
print(f"  CRS:         {crs}")
print(f"  ワールドファイルパラメータ:")
for i, (label, val) in enumerate(zip(
    ['X解像度','回転D','回転B','Y解像度','左上X','左上Y'], wf_lines)):
    print(f"    {label}: {val}")