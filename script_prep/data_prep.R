# data_prep.R

library(dplyr)
library(zoo)

danya_raw <- read.csv("data/Danya_Master_Dashboard_Data.csv", check.names = FALSE)

# makes sure variables are standardized
all_cols <- colnames(danya_raw)
white_idx <- grep("white", all_cols, ignore.case = TRUE)[1]
black_idx <- grep("black", all_cols, ignore.case = TRUE)[1]
date_idx  <- grep("date", all_cols, ignore.case = TRUE)[1]
result_idx <- grep("result", all_cols, ignore.case = TRUE)[1]

if(!is.na(white_idx)) colnames(danya_raw)[white_idx] <- "White"
if(!is.na(black_idx)) colnames(danya_raw)[black_idx] <- "Black"
if(!is.na(date_idx))  colnames(danya_raw)[date_idx]  <- "Date.orig"
if(!is.na(result_idx)) colnames(danya_raw)[result_idx] <- "Result.orig"


danya_ready <- danya_raw %>%
  mutate(ECO.orig = NA, Opening_Name = "Unknown Opening", is_super_clash = FALSE)

required_cols <- c(
  "Game_ID", "proper_identity", "White", "Black", "environment", 
  "Date.orig", "Result.orig", "ECO.orig", "Opening_Name", "is_super_clash",
  "Tempo", "local_hour", "FEN", "Color", "MoveNum", "Loss", 
  "Played_Move", "Stockfish_Move", "Maia_Move", "Maia_Match"
)

danya_light <- danya_ready %>% select(any_of(required_cols))

# detects any missing columns required by the UI and puts NA
missing_cols <- setdiff(required_cols, colnames(danya_light))
for(col in missing_cols) { danya_light[[col]] <- NA }

danya_light <- danya_light %>% select(all_of(required_cols))

saveRDS(danya_light, "data/optimized/danya_light.rds")


# pre-calculates the 50-game Rolling Humanity Index here. 
# This tracks his intuitive (Maia) match rate over time 
danya_summary <- danya_light %>%
  group_by(Game_ID) %>%
  summarise(Game_Humanity = mean(Maia_Match == 1, na.rm = TRUE) * 100, .groups = "drop") %>%
  mutate(Global_Game = row_number(),
         Rolling_Humanity = zoo::rollmean(Game_Humanity, k = 50, fill = NA, align = "right")) %>%
  filter(!is.na(Rolling_Humanity))

saveRDS(danya_summary, "data/optimized/danya_summary.rds")