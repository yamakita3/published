import rasterio
import numpy as np
from PIL import Image
import os
import sys
import argparse

# =============================================
# 設定（必要に応じて変更）
# =============================================
STRETCH_MIN = 0.02   # 表示最小値（反射率）
STRETCH_MAX = 0.25   # 表示最大値（反射率）

def stretch_to_uint8(band, vmin, vmax):
    """リニアストレッチで0〜255の整数に変換"""
    stretched = (band - vmin) / (vmax - vmin)
    stretched = np.clip(stretched, 0, 1)
    return (stretched * 255).astype(np.uint8)

def tif_to_png(input_tif, output_dir,
               stretch_min=STRETCH_MIN, stretch_max=STRETCH_MAX):
    """
    GeoTIFF → PNG + ワールドファイル(.pgw) + PRJ(.prj) に変換
    """
    basename  = os.path.splitext(os.path.basename(input_tif))[0]
    out_png   = os.path.join(output_dir, basename + '.png')
    out_pgw   = os.path.join(output_dir, basename + '.pgw')
    out_prj   = os.path.join(output_dir, basename + '.prj')

    with rasterio.open(input_tif) as src:
        data      = src.read()
        transform = src.transform
        crs       = src.crs
        width     = src.width
        height    = src.height
        nodata    = src.nodata
        n_bands   = src.count

    # バンド数チェック（RGB = 3バンド必須）
    if n_bands < 3:
        print(f'  [SKIP] {basename}: バンド数が{n_bands}つのためスキップ（RGB=3バンド必要）')
        return False

    r_8bit = stretch_to_uint8(data[0], stretch_min, stretch_max)
    g_8bit = stretch_to_uint8(data[1], stretch_min, stretch_max)
    b_8bit = stretch_to_uint8(data[2], stretch_min, stretch_max)

    # NoDataをアルファ透過処理
    if nodata is not None:
        nodata_mask = (data[0] == nodata)
        alpha = np.where(nodata_mask, 0, 255).astype(np.uint8)
        rgb_array = np.stack([r_8bit, g_8bit, b_8bit, alpha], axis=2)
        img = Image.fromarray(rgb_array, mode='RGBA')
    else:
        rgb_array = np.stack([r_8bit, g_8bit, b_8bit], axis=2)
        img = Image.fromarray(rgb_array, mode='RGB')

    # PNG保存
    img.save(out_png)

    # ワールドファイル（.pgw）生成
    a = transform.a   # X解像度
    b = transform.b   # 回転
    c = transform.c   # 左端X
    d = transform.d   # 回転
    e = transform.e   # Y解像度（負）
    f = transform.f   # 上端Y
    ulx = c + a * 0.5
    uly = f + e * 0.5

    with open(out_pgw, 'w') as fw:
        fw.write('\n'.join([
            f'{a:.10f}',
            f'{d:.10f}',
            f'{b:.10f}',
            f'{e:.10f}',
            f'{ulx:.10f}',
            f'{uly:.10f}',
        ]))

    # PRJファイル（CRS情報）生成
    with open(out_prj, 'w') as fp:
        fp.write(crs.to_wkt())

    print(f'  [OK] {basename}.png  ({width}×{height}px, CRS:{crs.to_epsg()})')
    return True


def main():
    parser = argparse.ArgumentParser(
        description='フォルダ内の全GeoTIFF(RGB)をPNG+ワールドファイルに変換'
    )
    parser.add_argument('input_dir',
                        help='入力フォルダ（.tifファイルを含むフォルダ）')
    parser.add_argument('output_dir', nargs='?', default=None,
                        help='出力フォルダ（省略時は input_dir/png_output）')
    parser.add_argument('--min', type=float, default=STRETCH_MIN,
                        help=f'ストレッチ最小値（デフォルト: {STRETCH_MIN}）')
    parser.add_argument('--max', type=float, default=STRETCH_MAX,
                        help=f'ストレッチ最大値（デフォルト: {STRETCH_MAX}）')
    args = parser.parse_args()

    input_dir  = os.path.abspath(args.input_dir)
    output_dir = os.path.abspath(args.output_dir) if args.output_dir \
                 else os.path.join(input_dir, 'png_output')

    os.makedirs(output_dir, exist_ok=True)

    # フォルダ内の全.tifを取得
    tif_files = sorted([
        f for f in os.listdir(input_dir)
        if f.lower().endswith('.tif') or f.lower().endswith('.tiff')
    ])

    if not tif_files:
        print(f'[ERROR] {input_dir} にTIFファイルが見つかりません')
        sys.exit(1)

    print(f'=== GeoTIFF → PNG 変換 ===')
    print(f'入力フォルダ:  {input_dir}')
    print(f'出力フォルダ:  {output_dir}')
    print(f'ストレッチ:    {args.min} 〜 {args.max}')
    print(f'対象ファイル:  {len(tif_files)} 件')
    print('-' * 40)

    success = 0
    for tif in tif_files:
        tif_path = os.path.join(input_dir, tif)
        result = tif_to_png(tif_path, output_dir, args.min, args.max)
        if result:
            success += 1

    print('-' * 40)
    print(f'完了: {success}/{len(tif_files)} 件変換しました')
    print(f'出力先: {output_dir}')

if __name__ == '__main__':
    main()
