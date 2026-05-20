# optb.R ---

library(dplyr)
library(stringr)
library(zoo)
library(bigchess)

required_cols <- c(
  "Game_ID", "proper_identity", "White", "Black", "WhiteElo.orig", "BlackElo.orig", 
  "environment", "Date.orig", "Result.orig", "ECO.orig", "Opening_Name", "is_super_clash",
  "Tempo", "local_hour", "FEN", "Color", "MoveNum", "Loss", "Best_Eval", 
  "Played_Move", "Stockfish_Move", "Maia_Move", "Maia_Match"
)

main_raw <- read.csv("data/Full_Master_Dashboard_Data.csv", check.names = FALSE)

# API Fragmentation Catcher
# Because data comes from multiple disparate sources (Lichess APIs, historical PGNs), 
# capitalization and column naming are highly volatile. This fuzzy-matching searches instead
cols <- colnames(main_raw)
eco_idx   <- which(cols %in% c("ECO.orig", "eco.orig", "ECO", "eco"))[1]
white_idx <- which(cols %in% c("White", "white", "White1", "white1"))[1]
black_idx <- which(cols %in% c("Black", "black", "Black1", "black1"))[1]
w_elo_idx <- grep("whiteelo", cols, ignore.case = TRUE)[1]
b_elo_idx <- grep("blackelo", cols, ignore.case = TRUE)[1]
eval_idx  <- grep("best_eval|besteval", cols, ignore.case = TRUE)[1]

if(!is.na(eco_idx))   colnames(main_raw)[eco_idx]   <- "ECO_Key"
if(!is.na(white_idx)) colnames(main_raw)[white_idx] <- "White"
if(!is.na(black_idx)) colnames(main_raw)[black_idx] <- "Black"
if(!is.na(w_elo_idx)) colnames(main_raw)[w_elo_idx] <- "WhiteElo.orig"
if(!is.na(b_elo_idx)) colnames(main_raw)[b_elo_idx] <- "BlackElo.orig"
if(!is.na(eval_idx))  colnames(main_raw)[eval_idx]  <- "Best_Eval"

# puts in big chess package
data(eco, package = "bigchess")
eco_dict <- eco %>% select(ECO, Opening) %>% group_by(ECO) %>% summarise(Opening_Name = first(Opening), .groups = "drop")

main_ready <- main_raw %>%
  left_join(eco_dict, by = c("ECO_Key" = "ECO")) %>%
  mutate(
    Opening_Name = if_else(is.na(Opening_Name), "Unknown Opening", as.character(Opening_Name)),
    ECO.orig = ECO_Key
  )

# Psychological Pressure Mapping
# if two of 8 grandmasters  are playing each other, it flags the game as a "Super-Clash"
elite_names <- c("Carlsen", "Nakamura", "Hikaru", "Niemann", "Naroditsky", "Kasparov", "Kramnik", "Fischer", "Karpov")
elite_regex <- paste(elite_names, collapse = "|")
main_ready <- main_ready %>%
  mutate(is_super_clash = str_detect(White, regex(elite_regex, ignore_case = TRUE)) & 
           str_detect(Black, regex(elite_regex, ignore_case = TRUE)))

# Strips away unneeded columns from the raw CSVs
# Converts the data into .rds 
main_light <- main_ready %>% select(any_of(required_cols))
missing_main <- setdiff(required_cols, colnames(main_light))
for(col in missing_main) main_light[[col]] <- NA
main_light <- main_light %>% select(all_of(required_cols))

saveRDS(main_light, "data/optimized/main_data_light.rds")


# Danya Baseline
# does same thing to make sure dataset works
danya_raw <- read.csv("data/Danya_Master_Dashboard_Data.csv", check.names = FALSE)

d_cols <- colnames(danya_raw)
d_white_idx <- grep("white", d_cols, ignore.case = TRUE)[1]
d_black_idx <- grep("black", d_cols, ignore.case = TRUE)[1]
d_date_idx  <- grep("date", d_cols, ignore.case = TRUE)[1]
d_res_idx   <- grep("result", d_cols, ignore.case = TRUE)[1]
d_w_elo_idx <- grep("whiteelo", d_cols, ignore.case = TRUE)[1]
d_b_elo_idx <- grep("blackelo", d_cols, ignore.case = TRUE)[1]
d_eval_idx  <- grep("best_eval|besteval", d_cols, ignore.case = TRUE)[1]

if(!is.na(d_white_idx)) colnames(danya_raw)[d_white_idx] <- "White"
if(!is.na(d_black_idx)) colnames(danya_raw)[d_black_idx] <- "Black"
if(!is.na(d_date_idx))  colnames(danya_raw)[d_date_idx]  <- "Date.orig"
if(!is.na(d_res_idx))   colnames(danya_raw)[d_res_idx]   <- "Result.orig"
if(!is.na(d_w_elo_idx)) colnames(danya_raw)[d_w_elo_idx] <- "WhiteElo.orig"
if(!is.na(d_b_elo_idx)) colnames(danya_raw)[d_b_elo_idx] <- "BlackElo.orig"
if(!is.na(d_eval_idx))  colnames(danya_raw)[d_eval_idx]  <- "Best_Eval"

danya_ready <- danya_raw %>% mutate(ECO.orig = NA, Opening_Name = "Unknown Opening", is_super_clash = FALSE)

danya_light <- danya_ready %>% select(any_of(required_cols))
missing_danya <- setdiff(required_cols, colnames(danya_light))
for(col in missing_danya) danya_light[[col]] <- NA
danya_light <- danya_light %>% select(all_of(required_cols))

saveRDS(danya_light, "data/optimized/danya_light.rds")

# Calculates the 50-game rolling average of Maia matching on backend.
danya_summary <- danya_light %>%
  group_by(Game_ID) %>%
  summarise(Game_Humanity = mean(Maia_Match == 1, na.rm = TRUE) * 100, .groups = "drop") %>%
  mutate(Global_Game = row_number(),
         Rolling_Humanity = zoo::rollmean(Game_Humanity, k = 50, fill = NA, align = "right")) %>%
  filter(!is.na(Rolling_Humanity))

saveRDS(danya_summary, "data/optimized/danya_summary.rds")