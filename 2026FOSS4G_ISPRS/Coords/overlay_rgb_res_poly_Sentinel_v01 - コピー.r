library(terra)
library(sf)
library(stringr)

setwd("2026Ako0501")
poly_path  <- "グリッド描画/Trim2025img_tiles.gpkg"
img_dir    <- "Result_mask_crop03v01_04/Ako_Masked_crop_04_sentinel/test_median_all"
result_dir <- "Result_mask_crop03v01_04/Ako_Masked_crop_04_sentinel/test_median_all_Visuals_combined"
out_dir    <- "Result_mask_crop03v01_04/Ako_Masked_crop_04_sentinel/combined"

##\Ako_Masked_crop_04_sentinel\test_median_all_Visuals_combined

if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

pol <- vect(poly_path)

files <- list.files(result_dir, pattern = "_.*_1\\.png$", full.names = TRUE)
files <- sort(files)

imgfiles <- list.files(img_dir, pattern = ".*\\.png$", full.names = TRUE)
imgfiles <- sort(imgfiles)

#---- ファイル名から年・月を取る関数（差し替え用） ----
# 対応例:
#   _S2_RGB_median_2019_01_1.png -> 2019 / 01
#   S2_RGB_median_2026_05.png    -> 2026 / 05
#   Trim202503.png               -> 2025 / 03
#   Trim2025_03.png              -> 2025 / 03
#   Trim202503_1.png             -> 2025 / 03

extract_ym <- function(x) {
  b <- basename(x)
  b <- tools::file_path_sans_ext(b)

  if (grepl("S2_RGB_median_", b)) {
    m <- regexec("(?:^|[_-])S2_RGB_median_(\\d{4})[ _-]?(\\d{2})(?:[_-]\\d+)?$", b, perl = TRUE)
    r <- regmatches(b, m)[[1]]
    if (length(r) >= 3) return(c(year = r[2], month = r[3]))
  }

  if (grepl("Trim", b)) {
    m1 <- regexec("Trim(\\d{6})", b, perl = TRUE)
    r1 <- regmatches(b, m1)[[1]]
    if (length(r1) >= 2) {
      ym <- r1[2]
      return(c(year = substr(ym, 1, 4), month = substr(ym, 5, 6)))
    }

    m2 <- regexec("Trim(\\d{4})(?:[_-]?(\\d{2}))?", b, perl = TRUE)
    r2 <- regmatches(b, m2)[[1]]
    if (length(r2) >= 2) {
      year <- r2[2]
      month <- if (length(r2) >= 3 && nzchar(r2[3])) r2[3] else NA_character_
      return(c(year = year, month = month))
    }
  }

  c(year = NA_character_, month = NA_character_)
}
# ---- 画像選択のルール（ここはそのまま使える） ----
# 1) 年+月が一致する画像を優先
# 2) なければ年だけ一致する画像を採用
# 3) それもなければ NA
match_img_to_file <- function(file_name, imgfiles, img_ym) {
  fy <- extract_ym(file_name)
  if (!is.na(fy["month"])) {
    idx <- which(img_ym[, "year"] == fy["year"] & img_ym[, "month"] == fy["month"])
    if (length(idx) > 0) return(imgfiles[idx[1]])
  }
  idx <- which(img_ym[, "year"] == fy["year"])
  if (length(idx) > 0) return(imgfiles[idx[1]])
  NA_character_
}

img_ym <- t(sapply(imgfiles, extract_ym))
file_ym <- t(sapply(files, extract_ym))


mapping <- data.frame(
  file = files,
  file_year = file_ym[, "year"],
  file_month = file_ym[, "month"],
  img = NA_character_,
  img_year = NA_character_,
  img_month = NA_character_,
  stringsAsFactors = FALSE
)

for (i in seq_along(files)) {
  m <- match_img_to_file(files[i], imgfiles, img_ym)
  mapping$img[i] <- m
  if (!is.na(m)) {
    ym <- extract_ym(m)
    mapping$img_year[i] <- ym["year"]
    mapping$img_month[i] <- ym["month"]
  }
}

print(mapping, row.names = FALSE)
write.csv(mapping, file.path(out_dir, "file_img_mapping.csv"), row.names = FALSE)

# 1 = 半透明緑、0 = 透明 にするための描画関数
process_one <- function(f) {
  bg <- mapping$img[mapping$file == f]
  if (length(bg) == 0 || is.na(bg) || !file.exists(bg)) {
    message("Skip: background not found for ", basename(f))
    return(invisible(NULL))
  }

  img.r <- rast(bg)
  res.r <- rast(f)

  if (nlyr(img.r) > 3) img.r <- img.r[[1:3]]
  if (nlyr(res.r) > 1) res.r <- res.r[[1]]

  pp <- pol
  if (!is.na(crs(img.r)) && !is.na(crs(pp)) && crs(img.r) != crs(pp)) {
    pp <- project(pp, crs(img.r))
  }

  # 背景範囲に合わせる
  pp_crop <- crop(pp, ext(img.r))#, snap = "out")
  if (nrow(pp_crop) == 0) {
    message("Skip: polygon outside extent for ", basename(f))
    return(invisible(NULL))
  }

  # res.r を背景画像に合わせて必要ならリサンプル
  if (!compareGeom(res.r, img.r, stopOnError = FALSE)) {
    res.r <- resample(res.r, img.r, method = "near")
  }

  # 0/1 を 0/1 として使う（1だけ緑、0は透明）
  res1 <- res.r
  values(res1) <- ifelse(values(res.r) >= 1, 1, NA)

  out <- file.path(out_dir, sub("\\.png$", "_overlay.png", basename(f)))

  png(out, width = ncol(img.r), height = nrow(img.r), bg = "transparent")
  par(mar = c(0, 0, 0, 0), xaxs = "i", yaxs = "i")
  plotRGB(img.r)
  plot(res1, col = adjustcolor("green", alpha.f = 0.35), add = TRUE, legend = FALSE)
  plot(pp_crop, border = "red", col = NA, lwd = 2, add = TRUE)
  dev.off()

  message("Saved: ", out)
}

for (f in files) process_one(f)
