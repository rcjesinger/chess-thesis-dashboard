# Chess Under Surveillance

[![Live Dashboard](https://img.shields.io/badge/Live_Dashboard-Click_Here-2563EB?style=for-the-badge)]([https://rcjesinger.shinyapps.io/chess-thesis-dashboard/])

Hi! I'm Rena. This repository holds the code for my undergraduate senior thesis in Science & Technology Studies (STS) at UC Davis. 

This project is an interactive statistical forensics dashboard built to evaluate human intuition versus algorithmic bot-detection in high-stakes chess. 

Click the "Live Dashboard" badge above to explore the actual project!

---

### Raw Data Access
The live Shiny application runs on highly compressed `.rds` files to optimize web performance. Because GitHub has a 100MB file limit, the uncompressed, raw CSV datasets (300MB+) I manually scraped and analyzed to build this architecture are hosted on my university cloud drive:

**[Access the Raw CSV Datasets Here](https://drive.google.com/drive/folders/1YYgdjmUReRLbIFUmJJkc3KDmOllU3jN6?usp=drive_link)**

---

### Installation
If you want to clone this code and run it locally in RStudio:
1. `git clone https://github.com/rcjesinger/chess-thesis-dashboard.git`
2. Open `Chess_Thesis_Dashboard.Rproj`.
3. Run `shiny::runApp()`.