# global.R
library(shiny)
library(bslib)
library(tidyverse) 
library(DT)
library(plotly)
library(rchess)
library(zoo)
library(markdown)

if (file.exists("helper.R")) source("helper.R")

main_data <- readRDS("data/optimized/main_data_thesis_final.rds")
danya_data    <- readRDS("data/optimized/danya_light.rds")
danya_summary <- readRDS("data/optimized/danya_summary.rds")

# SAFETY PATCHES & DATA CLEANING

# Timeline Fix
# My earlier data prep scripts accidentally dropped the raw Date from the Danya summary table.
# Instead of rebuilding the entire dataset from scratch, I built this bridge to join 
# the dates back in based on the Game_ID, ensuring the Timeline plot in tab_memorial doesn't crash.
if (!"Date.orig" %in% colnames(danya_summary)) {
  
  date_bridge <- danya_data %>%
    select(Game_ID, Date.orig) %>%
    distinct()
  
  danya_summary <- danya_summary %>%
    left_join(date_bridge, by = "Game_ID")
}

# The Metadata Fix
# Historical PGN files from the 1970s often lack the 'Event' tag. If it's missing, 
# I overwrite it with my Environmental classification (Isolated/Social) so the Case Dossier 
# UI box always has a clean string to render.
if(!"Event.orig" %in% colnames(main_data)) {
  main_data$Event.orig <- main_data$environment
}

# GLOBAL CONSTANTS
# I defined the elite roster here to easily use regex for name filtering across 
# different eras of chess history, preventing spelling mismatches in the raw data.
legends <- c("Bobby Fischer", "Anatoly Karpov")
elite_names <- c("Carlsen", "Nakamura", "Niemann", "Naroditsky", 
                 "Kasparov", "Kramnik", "Fischer", "Karpov")
elite_regex <- paste(elite_names, collapse = "|")

# Crucial type casting for the filtering engine. 
# Game_IDs must be characters so they perfectly match the customdata strings passed 
# back by user click events in Plotly. Environment and Tempo are converted to factors 
# to drastically speed up the dropdown filters in the sidebar.
main_data$Game_ID <- as.character(main_data$Game_ID)
danya_data$Game_ID <- as.character(danya_data$Game_ID)
main_data$environment <- as.factor(main_data$environment)
main_data$Tempo <- as.factor(main_data$Tempo)

# MODULE SOURCING
source("R/tab_memorial.R")
source("R/tab_interactive.R")
source("R/tab_audit.R")
source("R/tab_index.R")
source("R/tab_simulator.R")
source("R/tab_defense.R")
source("R/tab_thesis.R")