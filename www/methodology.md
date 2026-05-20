### DATA & METHODOLOGY

**Subject Selection:** Chose 8 Grandmasters to provide comparative generational baselines: Bobby Fischer, Anatoly Karpov, Garry Kasparov, Vladimir Kramnik, Daniel Naroditsky, Hans Niemann, Hikaru Nakamura, and Magnus Carlsen. The roster includes 2 pre-engine, 2 mid-engine invention, and 4 post-engine players to evaluate the evolution of cheating accusations.

**Context:** Inspired by the high-profile Hans Niemann/Magnus Carlsen and Daniel Naroditsky/Vladimir Kramnik cheating scandals over the last several years. These accusations occurred online for Naroditsky, but in-person (OTB) for Niemann.

**Data Collection:** Collected PGN game data through Python APIs interacting with Lichess and Chess.com, then pgnmentor.com for OTB games to ensure a full, longitudinal range of game data (including specific games where these grandmasters played each other).

**Variable Creation:** Created environmental and temporal variables "Blitz vs. Classical" and "Social vs. Isolated." Isolation includes all online games, but also features a time-of-day variable to analyze how players perform alone/streaming at night versus during the day.

**Sampling:** Implemented a random sample of 250 games per available category to ensure no single time of gameplay was overrepresented. The 4 Quadrants of the experiment were: Social + Classical; Social + Blitz; Isolated + Classical; Isolated + Blitz. (Note: Pre-engine games were automatically classified as ‘Social’ due to engines not being widely accessible, meaning older grandmasters naturally have less varied environmental data).

**Data Processing:** Filtered down to approximately 6,000 games (yielding 256,673 individual moves). Implemented string-trimming and case-normalization to standardize player names and generated a standardized set of headers per move.

**Algorithmic Analysis (The Human-Machine Delta):** Ran all game PGNs through AI engines to generate specific metrics, measured in Centipawn Loss (CPL), where a value of 100 equals 1 pawn.

* **Stockfish 16.1:** Represents the absolute truth of each move. Every position was analyzed at a depth of 20+ to calculate the CPL of the move actually played, generating the Best_Move and Best_Eval columns.
* **Maia 1900:** Acts as the sociotechnical proxy. Trained on human games, Maia predicts what a human would intuitively do, generating the Maia_Move and Maia_Match columns.
* **The Inhumanity Metric:** Created a "delta" metric to isolate moves where a player mathematically matched Stockfish but deviated from Maia’s human prediction.

**Optimization:** Once the website was finalized, full datasets were converted into `.rds` files to optimize dashboard loading times. Datasets include all listed Grandmasters and the last 3-4 months of online data for Naroditsky. (Keep in mind that tournaments have seasons, meaning the last 3-4 months of data lacked significant in-person games).

---

### WEBSITE: CHESS UNDER SURVEILLANCE

**Global Filters:** A persistent filter sidebar that applies to the entire dashboard to narrow down analysis. Allows the user to select the specific Grandmaster, Environment, and Tempo.

**Super-Clash Mode:** A special "elite matchup" toggle, as around 200 of the randomly selected games featured these specific Grandmasters playing against each other. (Note: When using Super-Clash, a specific Grandmaster must be selected first to isolate their side of the board for accurate analysis in subsequent tabs).

#### TAB 1: INTERACTIVE BOARD

**Key Definitions:**

* **Blunders:** Analyzed using a strict 50-centipawn FIDE threshold, with massive catastrophic tactical failures mathematically capped at 300 centipawns to preserve standard deviation stability in population-level variance.
* **Supermatches:** Defined as a sustained engine-match rate of >= 70% over at least 20 moves, excluding the opening phase.

**Reality Toggles:** The interactive board can be toggled to render three different realities:

* **Human:** The move actually played by the Grandmaster.
* **Stockfish:** The machine-optimal path (The "Ideal").
* **Maia:** The intuitive human path (The "Baseline").

**Move Cards & Javascript Timeline:** Each move is represented by a "Move Card" displaying the Human, Stockfish, and Maia moves side-by-side, along with the specific Loss for that ply. Clicking any card via a custom JS listener instantly pushes that index to the R server, triggering the rchess backend to recalculate the FEN and refresh the board without a full-page reload.

**Visual Ribboning:** Cards are color-coded with "Data Ribbons" (Crimson for Blunders, Electric Blue for Engine Matches) to allow for rapid visual pattern recognition across a game's timeline.

#### TAB 2: THE DEFENSE

This tab provides the aggregate statistical proof required for a formal accusation or exoneration in algorithmic anti-cheat systems.

**Baseline Calibration Toggle:** Before reviewing the charts, the user selects the definition of a ‘normal’ error:

* **Absolute (FIDE rules):** A strict, universal 50-centipawn threshold.
* **Relative (Personal):** A dynamic threshold based on the player’s personal distribution (Z > 3.0), identifying moves that are three standard deviations worse than their own historical average.

**Sociotechnical Stressors (Filters):** * **Spatial Stress (Cramped Filter):** Filters the dataset for moves where the player’s "Cramped" metric is flagged, allowing for an analysis of accuracy under physical/spatial restriction.

* **Calculation Load (Complexity Tiers):** Utilizing the Quantile Method, the system divides the dataset into three tertiles (Low, Medium, and High Complexity) based on full-population distribution. This allows for a "Stress Test" of accuracy as the mathematical difficulty of the position increases.

**Environment Significance (T-Test):** The dashboard runs a live Welch Two-Sample T-test comparing error rates in "Social" environments against "Isolated" environments. If the p-value is greater than 0.05, a player can argue their online accuracy is not mathematically distinct from their physical over-the-board play.

**Threshold Breaches (Z > 3.0):** This metric flags extreme human error. Because it scales Centipawn Loss into Z-scores, it highlights moves that are 3 standard deviations worse than the player's average. A player who frequently commits massive, verifiable calculation errors is highly unlikely to be utilizing computer assistance.

**Max Z-Score Observed:** The dashboard captured a peak outlier of 5.0+ standard deviations. This proves that even elite Grandmasters occasionally make statistically "impossible" blunders—moves so catastrophically bad that no engine in existence would ever suggest them.

**Chart: The Time Paradox (Maia Match Rate vs. Tempo)**

* Graphs the Maia Match Rate across Fast (Blitz) and Slow (Classical) tempos.
* Shows a highly resilient match rate across all environments, hovering steadily around 45–48%.
* The player's intuition remains robust and consistent regardless of algorithmic monitoring or extreme time constraints.

**Chart: The Tension Paradox (Complexity vs. Error):**

* A scatterplot mapping move-by-move Complexity against Centipawn Loss, colored by "Tension."
* Identifies if a player maintains machine-like precision specifically in high-tension positions where human friction should naturally increase.

**Chart: The Blunder Desert (Errorless Streaks by Environment)**

* Instead of looking at single moves, the algorithm calculates the max_streak: the longest uninterrupted sequence of moves a player makes without triggering the Calibration Threshold.
* By plotting the Isolated distribution against the Social distribution, the dashboard highlights environmental impact on stamina. For Niemann, the Isolated (OTB) environment contains extreme outliers, with games reaching 150+ move errorless streaks. The Social (Online) environment is far more compressed, maxing out around 90 moves. This strongly indicates that physical, isolated spaces actually facilitate deeper, longer states of sustained calculation than platform-governed online play (though the inverse was observed with Carlsen).

#### TAB 3: THE INDEX

This tab creates a multidimensional profile of each grandmaster to observe how environmental variables (time of day, move depth, board complexity) interact with human cognition.

**Chart: The Style Matrix (Volatility vs. Compliance)**

* A bivariate scatterplot mapping every game in the dataset.
* X-Axis represents Game Volatility (Average Centipawn Loss / how "messy" the game was). Y-Axis represents Compliance (Maia Match Rate / how closely the player followed the human-intuitive baseline).
* In a natural human state, high volatility (wild, tactical games) should lead to lower compliance. If a cluster of games exists in the top-right quadrant (High Volatility + High Compliance), it identifies a player who remains perfectly "intuitive" even when the position is chaotic or mathematically overwhelming.

**Chart: Stylistic Drift (OTB vs. Online)**

* A Dumbbell Plot (Connected Dot Plot) on a normalized 0–100 scale.
* Compares Accuracy (Engine Match %), Precision (Low Loss), and Endurance (Normalized Average Game Length).
* This chart visualizes the "Environmental Delta." By connecting the Social/OTB (Blue) dot to the Isolated/Online (Red) dot, we can instantly quantify the size of the stylistic shift. A short line indicates "Inhuman Consistency" (e.g., Magnus Carlsen), while a long line suggests a player whose style is fundamentally altered or "nudged" by digital platform surveillance.

**Chart: Phase Fingerprint (Proportional 1/3 Chunks)**

* A grouped bar chart faceted by relative game length.
* Compares engine match rates across the Beginning (1st 3rd), Middle (2nd 3rd), and Endgame (Final 3rd).
* Most Grandmasters match engines in the beginning due to memorized theory, making the "Surveillance Effect" most visible in the middle phases. If a player’s match rate spikes in the middle only when playing online, it indicates a shift toward algorithmic conformity during the most cognitively demanding phase of the game.

**Chart: Stylistic Performance (Positional vs. Tactical)**

* **Defining Stylistic Performance via Board Sharpness:** To categorize the stylistic nature of a game without relying on subjective human annotation or post-game error rates, this research mathematically defines 'Board Sharpness' by standardizing and combining Material Complexity (piece density) and Evaluation Tension (Euclidean distance of evaluation swings). Games residing in the bottom tertile of Sharpness are classified as Positional, the middle as Dynamic, and the top tertile as Tactical (sharp positions where the mathematical penalty for deviation is extreme).
* This acts as a "Stress Test." Humans typically struggle to match engines in sharp, tactical positions. If the match rate remains flat across all three profiles in the Isolated/Online environment, the subject is exhibiting a level of calculation consistency that defies standard human biological variance.

**Chart: Cognitive Fatigue (Accuracy over Move Depth)**

* A Generalized Additive Model (GAM) smooth trend line plotting Average Centipawn Loss against Move Number.
* Typically, the Social/OTB (Blue) line should rise as moves increase, representing Cognitive Fatigue (the longer the game, the more mistakes a human makes). If the Isolated/Online (Red) line stays flat or dips lower than the OTB baseline as the game hits late stages, it suggests a "Second Wind" that defies standard biological limits, indicating potential environmental augmentation.

**Chart: The Sleep Tracker (24-Hour Panopticon)**

* A 24-hour time-series aggregate line chart showing Average Engine Match Rate bucketed by the Local Hour of gameplay.
* This chart treats the player as a biological entity, looking for the "circadian dip" where human accuracy usually plummets. It also highlights a distinct metadata gap: online platforms log timestamps to the second (Isolated/Online), while physical tournament PGNs often lack specific time-of-day data (Social/OTB), visually contrasting "Digital Native" telemetry with traditional physical recording.

#### TAB 4: THE AUDIT

This tab acts as a micro-level microscope, shifting from macro-aggregate statistics to the "Forensic Telemetry" of a single specific game. It syncs directly with the Interactive Board to map human intuition versus independent calculation on a move-by-move basis, creating a chronological chain of evidence.

**Chart: Forensic Telemetry (Single Game Move Mapping)**

* Every move is categorized and color-coded into one of four distinct behavioral states:
* **Silicon Match (Stockfish):** The played move perfectly matches the machine-optimal path.
* **Human Intuition (Maia):** The played move matches the sociotechnical proxy of expected human behavior.
* **Inaccuracy / Blunder:** The move incurs a Centipawn Loss of 50 or greater, representing distinct biological error.
* **Independent Variance:** The move matches neither engine but avoids a massive loss penalty, representing unique, unassisted human creativity.


* This chronological mapping visualizes algorithmic mimicry in real-time. A sudden, unbroken streak of "Silicon Matches" occurring specifically in the late Middlegame or Endgame—after periods of high variance or inaccuracy—provides a distinct visual signature of potential external assistance.

**Panel: System Verdict & Phase Analysis (The Anomaly Spotlight)**

* **Defining Anomalous Precision:** To automate a FIDE-style tribunal judgment and remove subjective human bias, the system utilizes a hardcoded threshold. If a player achieves a Stockfish match rate greater than 60% AND maintains an average overall game loss of under 15 centipawns, the system flags the game as "ANOMALOUS PRECISION." If the metrics fall below these extreme thresholds, it returns "NORMAL BIOLOGICAL VARIANCE."

**Table: Move Telemetry & Chain of Custody**

* An interactive data ledger displaying the raw move-by-move analysis, complete with a CSV export function.
* In Science and Technology Studies (STS) and data forensics, statistical claims require a verifiable "Chain of Custody." This table acts as the raw, unadulterated evidence ledger, ensuring that the algorithmic judgment displayed in the dashboard is entirely transparent, reproducible, and available for independent review.

#### TAB 5: CI SIMULATOR

**Chart: Surveillance Threshold Configuration**

* An interactive control card featuring a high-precision slider for the Algorithmic Confidence Threshold (80% to 99.9%).
* This slider defines the strictness of the surveillance net. A 99.9% threshold represents an extreme "beyond a reasonable doubt" standard, while an 80% threshold represents a much more aggressive, "precautionary" surveillance state.
* This visualizes the fundamental tension in forensic data science: the tradeoff between Security and False Positives. It forces the user to decide at what exact mathematical point a "Peak Human Performance" becomes a "Systemic Anomaly."

**Chart: Population Distribution & Flagging Net**

* **Defining Deviance via Z-Scores:** To standardize "suspicion" across different grandmasters and environments, the system calculates a Z-score for every game. Because a lower centipawn loss indicates better (and potentially more suspicious) play, the deviance is calculated via an inverted Z-score: Z = (Population Mean - Average Loss) / Population Standard Deviation.
* This chart provides a visual audit of the "Normal Distribution" of elite chess. It allows the researcher to see if the flagged games are isolated outliers or if the entire population is shifting toward a higher level of precision.

**Chart: Flagged Games Registry**

* **The Chain of Custody:** The table uses a dynamic color-coding system for the Confidence column. Values over 95% appear in yellow, while those over 98.9% (the gold standard for a "Strong Accusation") appear in bold red. Includes a Download Registry function for independent peer review.

#### TAB 6: DANYA MEMORIAL

This tab serves as a dedicated case study on Daniel "Danya" Naroditsky, defining the "Digital Native" baseline by contrasting his performance against the traditional "Auditor" approach.

**Forensic Metrics: Value Boxes**

* **Silicon Alignment (48.4%):** Danya matches the optimal Stockfish path nearly half the time.
* **Humanity Baseline (50.2%):** He is slightly more likely to match the "Human" Maia prediction than the "Optimal" machine path.
* **Auditor Variance Delta (44.9 CPL):** This high delta quantifies the massive stylistic gap between the Native (Danya) and the Auditor (Kramnik).

**Chart: The Timeline of Intuition (Rolling Humanity Index)**

* A chronological line chart with a smooth trend line mapping a 50-game rolling average of the Maia Match Rate.
* Proves "Longitudinal Stability." His play isn't a series of spikes; it is a sustained cognitive state. His intuition is a constant, measurable variable that survives across hundreds of games.

**Chart: The 'Flow State' (Speed Mastery Density)**

* A 2D Density Bin Plot (Heatmap) charting Move Depth against Centipawn Loss.
* This is the visual definition of "Speed Mastery." A "Native" like Danya shows a thick horizontal band of near-perfect play (0-10 CPL) that does not dissipate as the game gets deeper. He remains "in the flow" long after a traditional player would have succumbed to fatigue.

**Chart: The Contrast (Native vs. Auditor)**

* Naroditsky (The Native) has a lower median Centipawn Loss (~15 CPL) compared to Kramnik (The Auditor, ~22 CPL) in online play.
* While Kramnik (The Auditor) has a "tighter" interquartile range, he has a much higher density of extreme outliers. Naroditsky’s distribution is "cleaner" at the high-precision end, statistically proving that the "Digital Native" is fundamentally more precise than the traditional "Auditor" in a digital environment.

#### TAB 7: HISTORICAL AUDITOR

This tab situates modern accusations within the history of human-machine co-evolution, demonstrating that "Stability" is a moving target and that modern surveillance often "over-reads" historical brilliance.

**Chart: The Silicon Ghost (Algorithmic Socialization Over Time)**

* Quantifies "Algorithmic Socialization"—the process by which humans have learned to think like machines, proving that a "normal" baseline in 1970 looks statistically distinct from a "normal" baseline in the modern era.

**Chart: The Back-Test (Applying Modern Surveillance to Historical Legends)**

* Applies the modern "Anomalous Precision" threshold (Stockfish Match > 60% AND Avg Loss < 15, on games > 15 moves) universally to historical data points.
* **The Insight:** Identifies significant "False Positives" in pre-engine legends. Proves that modern surveillance tools often fail to account for historical brilliance. If the greatest legends of the past cannot pass a 2026 "vibe check," then the thresholds themselves are historically contingent and must be used with caution in modern statistical audits.

---

### EMPIRICAL CONCLUSIONS (AGGREGATE DATA SUMMARY)

The `conclusions.R` data aggregation pipeline generated several key mathematical insights that challenge traditional fair-play auditing:

**1. The Myth of the Blunder Desert (Endurance Shifts)**
When tracking the `max_streak` of errorless moves (moves avoiding the 50-centipawn blunder threshold), the data indicates that Isolated (Online) platforms do not inherently generate longer calculation stamina. Instead, the physical presence of the board in Social (OTB) settings often yielded significantly longer unbroken precision streaks across the tested population.

**2. Sociotechnical Stress & The Friction Delta**
By stratifying the dataset into tertiles of "Board Sharpness" (a mathematical index combining evaluation Tension and piece Complexity), the analysis quantifies the "Friction Delta." Elite human calculation inherently degrades as board sharpness moves from Positional to Tactical. A flat standard deviation across all three tiers, defying this Friction Delta, serves as a more reliable indicator of algorithmic assistance than absolute engine-matching percentages.

**3. The Digital Native Baseline (Naroditsky vs. Kramnik)**
Isolating the isolated/online data of Daniel Naroditsky ("The Native") against Vladimir Kramnik ("The Auditor") proves that extreme speed mastery is biologically possible. Naroditsky maintained a lower median centipawn loss (~15 CPL) and a remarkably clean distribution in the 0-10 CPL band across move depth, indicating a sustained "Flow State." Conversely, while Kramnik exhibited a tighter overall interquartile range, his data contained a higher density of extreme outliers, highlighting the distinct stylistic gap between native digital play and traditional auditing standards.

**4. Algorithmic Socialization & The Historical Backtest**
Longitudinal tracking of the Maia 1900 match rate reveals a systemic upward drift, quantifying how human grandmasters have been slowly socialized to play more like optimal engines over the past 50 years. Consequently, back-testing the strict modern "Anomalous Precision" threshold (Stockfish > 60% and Avg Loss < 15) against 1970s and 1980s data yields high-confidence "False Positives" on historical legends (e.g., Anatoly Karpov). This proves that static surveillance nets are era-contingent and will invariably over-flag peak human brilliance if not dynamically calibrated.

**5. Z-Score Calibration Requirement**
The overarching conclusion drawn from standardizing the population data is the necessity of relative metric evaluation. Because individual games occasionally generate inverted Z-Scores representing deviances greater than 3.0 standard deviations from the mean, single-game anomalies are insufficient for proof of assistance. Reliable flagging requires a verifiable chain of `Confidence > 99.9%` breaches across a player's long-term timeline, paired with contextual markers like Phase Fingerprinting and Spatial Shift analysis.