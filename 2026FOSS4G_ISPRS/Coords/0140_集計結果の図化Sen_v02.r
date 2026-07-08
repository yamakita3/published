library(ggplot2)
library(dplyr)
library(tidyr)
library(reshape2)
library(readxl)

# ---- データ入力 ----
setwd("2026Ako0501\\Result_mask_crop03v01_04\\Ako_Masked_crop_04_sentinel\\")
df1 <- read_excel("0130_mono_result_zonal2_for04_sen_v02_255.xlsx", sheet = "Sheet5")

# ---- ワイド→ロング変換（mmを保持） ----
df_long <- df1 %>%
  melt(
    id.vars = c("yyyy", "mm", "Type", "file"),
    variable.name = "grid",
    value.name = "area"
  ) %>%
  filter(!is.na(area)) %>%
  mutate(
    yyyy = as.integer(yyyy),
    mm   = as.integer(mm)
  ) %>%
  select(yyyy, mm, Type, grid, area)

# ---- 同年同月同Type同グリッドで複数ある場合は平均 ----
df <- df_long |>
  group_by(yyyy, mm, Type, grid) |>
  summarise(area = mean(area), .groups = "drop")

# ---- グリッドの順序を固定 ----
grid_order <- c("x0000_y0000","x0640_y0000",
  "x1280_y0000","x1920_y0000","x2560_y0000","x3200_y0000","x3840_y0000",
  "x0000_y0640","x0640_y0640","x1280_y0640","x1920_y0640",
  "x2560_y0640","x3200_y0640","x3840_y0640",
  "x0000_y1280","x0640_y1280","x1280_y1280"
)
grid_order_rev <- rev(grid_order)
df$grid <- factor(df$grid, levels = grid_order_rev)

# ---- グリッドの色パレット ----
grid_colors <- c(
  "x0000_y0000" = "#eaf2fb",
  "x0640_y0000" = "#cfe2f3",
  "x1280_y0000" = "#a6cee3",
  "x1920_y0000" = "#62a8d0",
  "x2560_y0000" = "#1f78b4",
  "x3200_y0000" = "#4472C4",
  "x3840_y0000" = "#08306b",
  "x0000_y0640" = "#fdbf6f",
  "x0640_y0640" = "#f07c00",
  "x1280_y0640" = "#ED7D31",
  "x1920_y0640" = "#d95f0e",
  "x2560_y0640" = "#b35806",
  "x3200_y0640" = "#7f3b08",
  "x3840_y0640" = "#4d1f02",
  "x0000_y1280" = "#899c7c",
  "x0640_y1280" = "#6a7861",
  "x1280_y1280" = "#5a6352"
)

# ---- X軸を年月の連続数値に変換（例：2019年5月 → 2019.333） ----
# x_center = yyyy + (mm - 1) / 12
bar_w <- 0.06  # 月スケールに合わせて棒幅を調整（約2週間分）

df <- df |>
  mutate(x_center = yyyy + (mm - 1) / 12)

# ---- X軸ラベル用：データに実在する年月のみ ----
x_breaks <- df |>
  distinct(yyyy, mm, x_center) |>
  arrange(x_center)

# ---- プロット ----
p <- ggplot(df, aes(x = x_center, y = area, fill = grid)) +
  geom_col(
    aes(group = interaction(yyyy, mm, Type)),
    position = position_stack(),
    width = bar_w,
    linewidth = 0.5,
    color = "gray30"
  ) +
  scale_fill_manual(values = grid_colors, name = "Grid ID") +
  scale_x_continuous(
    breaks = x_breaks$x_center,
    labels = sprintf("%d-%02d", x_breaks$yyyy, x_breaks$mm),
    minor_breaks = NULL
  ) +
  # 棒の上に合計値ラベル（1ha以上のみ）
  stat_summary(
    aes(x = x_center, group = interaction(yyyy, mm, Type),
        label = ifelse(after_stat(y) >= 1, sprintf("%.1f", after_stat(y)), "")),
    fun = sum, geom = "text",
    vjust = -0.4, size = 2.8, color = "gray20", fontface = "bold"
  ) +
  labs(
    #title = "Seagrass Area (Sentinel-2, monthly)",
    subtitle = "",
    x = "Year-Month",
    y = "Area"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    #plot.title      = element_text(face = "bold", size = 15),
    axis.text.x     = element_text(angle = 60, hjust = 1, size = 8),
    axis.text.y     = element_text(size = 11),
    legend.position = "right",
    legend.key.size = unit(0.5, "cm"),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_line(color = "gray88"),
    panel.border = element_rect(fill = NA, linewidth = 1),
    axis.line = element_line()
  )

windows(width = 16, height = 7)
p

ggsave("tidal_flat_sentinel_monthly_v02_255.png", p, width = 16, height = 7, dpi = 150, bg = "white")