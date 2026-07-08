# ============================================================
# Read_mask_geotiff2ref_resolution_v03.r
# GeoTIFF → マスク・解像度変換 → PNG + ワールドファイル 一括処理
# ============================================================

library(terra)

# ============================================================
# ★ 設定（ここだけ変更する）
# ============================================================

# --- パス設定 ---
INPUT_DIR    <- "2026Ako0501/Masked_crop_04_sentinel/Supervise/"
TEMPLATE_PNG <- "Trim202302_img.png"          # 解像度テンプレート画像
POLY_FILE    <- "mask_Ako_poly_triangle.shp"  # マスク用ポリゴン
OUTPUT_DIR   <- file.path(INPUT_DIR, "png_output")  # 出力フォルダ（自動作成）

# --- ストレッチ設定（★明るさ調整はここ）---
# Sentinel-2 反射率（÷10000済み）の典型的な値域:
#   水域:   0.00〜0.05
#   植生:   0.02〜0.15（NIR除く）
#   裸地:   0.05〜0.20
#   雲:     0.30〜0.80
# 明るすぎる場合 → STRETCH_MAX を下げる（例: 0.3 → 0.15）
# 暗すぎる場合  → STRETCH_MAX を上げる、または STRETCH_MIN を下げる
STRETCH_MIN  <- 0.00   # 最小値（通常0.0のまま）
STRETCH_MAX  <- 0.15   # ★ 最大値（明るすぎる場合は下げる）

# --- ガンマ補正（1.0=補正なし, <1.0=明るく, >1.0=暗く）---
# 中間調の明るさを調整。線形ストレッチで白飛びする場合に有効
# 例: GAMMA=1.5 で中間部分が引き締まる
GAMMA        <- 1.0    # ★ 1.0〜2.0 を試す

# --- resample メソッド ---
RESAMP_METHOD <- "bilinear"  # "bilinear"（推奨）/ "near" / "cubic"

# --- GeoTIFF出力（TRUE=出力する / FALSE=PNGのみ）---
OUTPUT_GTIFF <- FALSE

# ============================================================
# 関数定義
# ============================================================

#' ワールドファイル（.pgw / .prj）を生成する
#' @param r       SpatRaster（空間情報の参照元）
#' @param out_png 出力PNGファイルパス
write_worldfile <- function(r, out_png) {
  e   <- ext(r)
  px  <-  (e$xmax - e$xmin) / ncol(r)
  py  <- -(e$ymax - e$ymin) / nrow(r)
  ulx <- e$xmin + px * 0.5
  uly <- e$ymax + py * 0.5

  writeLines(as.character(c(px, 0, 0, py, ulx, uly)),
             paste0(out_png, ".pgw"))
  writeLines(crs(r, proj = FALSE),
             paste0(out_png, ".prj"))
}


#' GeoTIFF 1ファイルを処理してPNG + ワールドファイルを出力する
#'
#' @param tif_path      入力GeoTIFFパス
#' @param poly          マスク用ポリゴン（SpatVector）
#' @param template      解像度テンプレート（SpatRaster）
#' @param out_dir       出力フォルダ
#' @param stretch_min   ストレッチ最小値（反射率）
#' @param stretch_max   ストレッチ最大値（反射率）※明るさの主要パラメータ
#' @param gamma         ガンマ補正値（1.0=なし, >1.0=暗く引き締め）
#' @param resamp_method resampleメソッド（"bilinear"等）
#' @param out_gtiff     GeoTIFFも出力するか（TRUE/FALSE）
process_tif <- function(tif_path,
                        poly,
                        template,
                        out_dir,
                        stretch_min  = 0.00,
                        stretch_max  = 0.15,
                        gamma        = 1.0,
                        resamp_method = "bilinear",
                        out_gtiff    = FALSE) {

  basename_noext <- tools::file_path_sans_ext(basename(tif_path))
  out_png        <- file.path(out_dir, paste0(basename_noext, ".png"))
  out_tif        <- file.path(out_dir, paste0(basename_noext, "_out.tif"))

  # --- 読み込み ---
  r <- tryCatch(rast(tif_path), error = function(e) {
    cat(sprintf("  [ERROR] 読み込み失敗: %s\n", basename(tif_path)))
    return(NULL)
  })
  if (is.null(r)) return(FALSE)
  if (nlyr(r) < 3) {
    cat(sprintf("  [SKIP]  %s: バンド数%dのためスキップ（RGB=3必要）\n",
                basename(tif_path), nlyr(r)))
    return(FALSE)
  }

  # --- CRS統一 ---
  poly_proj     <- project(poly, crs(r))
  template_proj <- project(template, crs(r))

  # --- ストレッチ（clamp → 0〜1に正規化）---
  r_stretched <- clamp(r, lower = stretch_min, upper = stretch_max)
  r_stretched <- (r_stretched - stretch_min) / (stretch_max - stretch_min)

  # --- ガンマ補正（gamma != 1.0 の場合のみ適用）---
  # 式: 出力 = 入力 ^ (1/gamma)
  # gamma > 1 → 中間調が暗くなりコントラスト向上
  # gamma < 1 → 中間調が明るくなる
  if (gamma != 1.0) {
    r_stretched <- r_stretched ^ (1 / gamma)
  }

  # --- マスク ---
  r_masked <- crop(r_stretched, poly_proj, mask = TRUE)

  # --- リサンプル（テンプレート解像度に合わせる）---
  r_resamp <- resample(r_masked, template_proj, method = resamp_method)

  # --- GeoTIFF出力（オプション）---
  if (out_gtiff) {
    writeRaster(r_resamp, out_tif,
                overwrite  = TRUE,
                datatype   = "FLT4S",
                gdal       = c("COMPRESS=LZW", "INTERLEAVE=PIXEL"))
    cat(sprintf("    GeoTIFF出力: %s\n", basename(out_tif)))
  }

  # --- 8bit変換 → PNG出力（余白ゼロ）---
  r_8bit <- round(r_resamp * 255)
  writeRaster(r_8bit, out_png,
              overwrite = TRUE,
              datatype  = "INT1U",
              NAflag    = 0)

  # --- ワールドファイル生成 ---
  write_worldfile(r_resamp, out_png)

  cat(sprintf("  [OK]  %s  (%d×%d px, stretch:%.2f-%.2f, gamma:%.1f)\n",
              basename(out_png), ncol(r_resamp), nrow(r_resamp),
              stretch_min, stretch_max, gamma))
  return(TRUE)
}


# ============================================================
# メイン処理
# ============================================================

setwd(INPUT_DIR)
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# テンプレート・ポリゴン読み込み（1回だけ）
r_template <- rast(TEMPLATE_PNG)
poly       <- vect(POLY_FILE)

# フォルダ内の全TIFを取得
tif_files <- list.files(INPUT_DIR,
                        pattern    = "\\.tiff?$",
                        full.names = TRUE,
                        ignore.case = TRUE)

if (length(tif_files) == 0) stop(paste("TIFファイルが見つかりません:", INPUT_DIR))

cat("============================================================\n")
cat(" GeoTIFF → PNG 一括変換\n")
cat("============================================================\n")
cat(sprintf(" 入力フォルダ:  %s\n", INPUT_DIR))
cat(sprintf(" 出力フォルダ:  %s\n", OUTPUT_DIR))
cat(sprintf(" テンプレート:  %s\n", TEMPLATE_PNG))
cat(sprintf(" ポリゴン:      %s\n", POLY_FILE))
cat(sprintf(" ストレッチ:    %.2f 〜 %.2f\n", STRETCH_MIN, STRETCH_MAX))
cat(sprintf(" ガンマ補正:    %.1f\n", GAMMA))
cat(sprintf(" 対象ファイル:  %d 件\n", length(tif_files)))
cat("------------------------------------------------------------\n")

results <- sapply(tif_files, process_tif,
                  poly          = poly,
                  template      = r_template,
                  out_dir       = OUTPUT_DIR,
                  stretch_min   = STRETCH_MIN,
                  stretch_max   = STRETCH_MAX,
                  gamma         = GAMMA,
                  resamp_method = RESAMP_METHOD,
                  out_gtiff     = OUTPUT_GTIFF)

cat("------------------------------------------------------------\n")
cat(sprintf(" 完了: %d / %d 件\n", sum(results), length(tif_files)))
cat(sprintf(" 出力先: %s\n", OUTPUT_DIR))
