# databuild.R

library(dplyr)

sf_danya <- read.csv("data/Analysis_Stockfish_Danya_End.csv")
maia_danya <- read.csv("data/Analysis_Maia_Danya_End.csv")
input_danya <- read.csv("data/Danya_End_Analysis_Input.csv")

engine_danya <- inner_join(sf_danya, maia_danya, by = c("Game_ID", "MoveNum", "proper_identity", "environment", "game_type"))

# Python scrapers often zero-index data, while R is one-indexed. 
# standardize the Game_IDs so the metadata can map to the engine telemetry.
input_danya$Game_ID <- paste0("G_", seq_len(nrow(input_danya)) - 1)

master_danya <- inner_join(engine_danya, input_danya, by = "Game_ID")

master_danya <- master_danya %>%
  rename(Played_Move = Played_Move.x,
         proper_identity = proper_identity.x) %>%
  select(-Played_Move.y, -proper_identity.y)

write.csv(master_danya, "data/Danya_Master_Dashboard_Data.csv", row.names = FALSE)
print(paste("--> Danya Dataset Saved! Rows:", nrow(master_danya)))

# merge all datasets
sf_full <- read.csv("data/Analysis_Stockfish_FullGame.csv")
maia_full <- read.csv("data/Analysis_Maia_FullGame.csv")
input_full <- read.csv("data/Master_Engine_Queue.csv") 

sf_clean <- sf_full %>% 
  distinct(Game_ID, MoveNum, .keep_all = TRUE)

maia_clean <- maia_full %>% 
  distinct(Game_ID, MoveNum, .keep_all = TRUE)

# Ensures Game_ID is identically named across all datasets occurs.
input_metadata <- input_full %>%
  rename(Game_ID = game_uid) %>% 
  distinct(Game_ID, .keep_all = TRUE)


engine_full <- inner_join(sf_clean, maia_clean, by = c("Game_ID", "MoveNum", "proper_identity", "environment", "game_type"))

master_full <- inner_join(engine_full, input_metadata, by = "Game_ID")

# cleanup
master_full <- master_full %>%
  rename(Played_Move = Played_Move.x,
         proper_identity = proper_identity.x) %>%
  select(-any_of(c("Played_Move.y", "proper_identity.y", "Environment")))

write.csv(master_full, "data/Full_Master_Dashboard_Data.csv", row.names = FALSE)