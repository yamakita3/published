library(terra)
library(sf)
library(dplyr)
library(purrr)


setwd("2026Ako0501\\Result_mask_crop03v01_04\\Ako_Masked_crop_04_sentinel\\test_median_all_Visuals_combined\\")

# グリッドshapefileとPNGリストの読み込み
grid_sf  <- st_read("2026Ako0501\\グリッド描画\\Trim2010_tiles.gpkg")           # グリッドポリゴン
grid_vec <- vect(grid_sf)                           # terra用に変換
names(grid_vec)[1] <-"grid_id" 

png_files <- sort(list.files(".", pattern = "\\.png$", full.names = TRUE))



# ---- A: zonal() ベース ----

process_zonal <- function(png_path, grid_vec) {
  r <- rast(png_path)
  
  # グリッドをラスタ解像度でラスタライズ（1度だけ実施して使い回せる）
  # グリッドに一意IDフィールドが必要（なければ連番を付与）
  if (!"grid_id" %in% names(grid_vec)) {
    grid_vec$grid_id <- seq_len(nrow(grid_vec))
  }
  
  zone_r <- rasterize(grid_vec, r, field = "grid_id")  # ゾーンラスタ
  
  # ゾーン統計（バンドが複数でも一括処理）
  z_mean <- zonal(r, zone_r, fun = "mean", na.rm = TRUE)
  z_mean2 <- zonal(r, zone_r, fun = "mean", na.rm = TRUE)
  z_sum <- zonal(r, zone_r, fun = "sum", na.rm = TRUE)
  z_sd   <- zonal(r, zone_r, fun = "sd",   na.rm = TRUE)
  z_min  <- zonal(r, zone_r, fun = "min",  na.rm = TRUE)
  z_max  <- zonal(r, zone_r, fun = "max",  na.rm = TRUE)
  z_n    <- zonal(r, zone_r, fun = function(x, ...) sum(!is.na(x)))
  
  # 結合して整形
  result <- z_mean |>
    rename(grid_id = 1) |>
    mutate(
      sd    = z_sd[[2]],
      min   = z_min[[2]],
      max   = z_max[[2]],
      n_px  = z_n[[2]],
      file  = basename(png_path)
    )
  
  return(result)
}

# ---- ラスタライズを1回だけ外でやる場合（ファイルが多い時は高速化）----
process_zonal_precomputed <- function(png_path, zone_r) {
  r <- rast(png_path)
  
  z_mean <- zonal(r, zone_r, fun = "mean", na.rm = TRUE)
  z_mean2 <- zonal(r, zone_r, fun = "mean", na.rm = TRUE)
  z_sum <- zonal(r, zone_r, fun = "sum", na.rm = TRUE)
  z_sd   <- zonal(r, zone_r, fun = "sd",   na.rm = TRUE)
  z_min  <- zonal(r, zone_r, fun = "min",  na.rm = TRUE)
  z_max  <- zonal(r, zone_r, fun = "max",  na.rm = TRUE)
  z_n    <- zonal(r, zone_r, fun = function(x, ...) sum(!is.na(x)))
  
  bind_cols(
    rename(z_mean, grid_id = 1),
	mean = z_mean2[[2]],
	sum = z_sum[[2]],
    sd   = z_sd[[2]],
    min  = z_min[[2]],
    max  = z_max[[2]],
    n_px = z_n[[2]]
  ) |>
    mutate(file = basename(png_path))
}

# 実行（ラスタライズを1枚目で作って使い回し）
r_template <- rast(png_files[[1]])
if (!"grid_id" %in% names(grid_vec)) grid_vec$grid_id <- seq_len(nrow(grid_vec))
zone_r <- rasterize(grid_vec, r_template, field = "grid_id")

results_zonal <- map_dfr(png_files, process_zonal_precomputed, zone_r = zone_r)
write.csv(results_zonal, "result_zonal2_04.csv", row.names = FALSE)

#
#grid_attr <- as.data.frame(grid_vec) |>
#  mutate(grid_id = as.numeric(grid_id))
#
#results_zonal_full <- results_zonal |>
#  left_join(grid_attr, by = "grid_id")
#  
#  



#########
タイプB：exact_extractr::exact_extract() ベース（クロス集計）

library(exact_extractr)  # install.packages("exactextractr")

# ---- B: exact_extract() ベース ----

process_exact <- function(png_path, grid_sf) {
  r <- rast(png_path)
  
  # exact_extract: リストで各ポリゴンの値を返す
  extracted <- exact_extract(
    r,
    grid_sf,
    fun       = c("mean", "stdev", "min", "max", "count"),
    na.rm     = TRUE,
    force_df  = TRUE,   # 結果をdata.frameで返す
    append_cols = names(grid_sf)[!names(grid_sf) == "geometry"]  # SHPの属性を付加
  )
  
  extracted |>
    mutate(file = basename(png_path))
}

results_exact <- map_dfr(png_files, process_exact, grid_sf = grid_sf)
write.csv(results_exact, "result_exact.csv", row.names = FALSE)