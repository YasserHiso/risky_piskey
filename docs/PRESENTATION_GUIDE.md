# Presentation Guide

How to present this project to your instructor, written to prepare a
beginner to explain this exact implementation. See `PROJECT_GUIDE.md` for
the full technical reasoning this leans on — nothing here goes beyond what's
actually in the project.

---

## 1. 30-second explanation

> "This is an AI Driving Risk Simulator. You control a car's speed and
> seatbelt status in a simple 2D driving scene, the environment changes
> automatically, and every few seconds the app sends those conditions to a
> real trained machine-learning model, which predicts whether the situation
> is Safe, Minor Risk, or High Risk — and shows you the model's actual
> probability, live."

---

## 2. 1-minute explanation

> "This is an AI Driving Risk & Accident Severity Simulator — a Flutter app
> with a small 2D side-view driving scene built in Flame, connected to a
> real machine-learning model through a FastAPI backend. I control the
> car's speed and whether the seatbelt is on, and the environment — weather,
> road surface, lighting — changes automatically every 10 seconds. Each time
> something changes, the app sends the current conditions to a trained
> Random Forest classifier and shows its actual predicted risk: Safe, Minor
> Risk, or High Risk, with a real probability percentage. The model was
> trained on BDRoadRisk, a large synthetic benchmark dataset — I chose it
> specifically because, unlike two other datasets I tested first, it
> actually contains real speed and seatbelt columns, which let me build the
> original speed/seatbelt game concept honestly instead of faking it or
> substituting unrelated controls."

---

## 3. 3-minute technical explanation

> "The project has four layers. At the bottom is the ML pipeline: I trained
> a RandomForestClassifier on BDRoadRisk, a 10-million-row synthetic
> traffic-event dataset, using a reproducible 500,000-row systematic sample.
> The target is `accident_severity` with three classes — No_Accident,
> Minor, and Major. Before picking features, I read the dataset's own data
> dictionary carefully and found that several columns — `junction_type` and
> `visibility_km` in particular — were documented as being generated *from*
> the severity label itself, which would make them leakage if I used them.
> I excluded those, plus two columns that describe the mechanics of a
> specific incident rather than a condition you could know in advance
> (`acceleration_ms2`, `reaction_time_sec`), plus one the dataset's own docs
> call pure noise (`temperature_celsius`). That left 18 features, and I
> compared three models — Logistic Regression, Random Forest, and Extra
> Trees — using 5-fold cross-validation and picked Random Forest by
> cross-validated ROC-AUC, which came out to 0.921 in cross-validation and
> 0.920 on a completely held-out test set, with 81% accuracy and 77% macro
> recall.
>
> The whole preprocessing-plus-model pipeline is saved as a single file. A
> FastAPI backend loads it once at startup and exposes one endpoint,
> `POST /predict`, which validates the incoming request against the exact
> categories and ranges the model was trained on, builds a single row of
> data, and calls `predict_proba()` — which returns real probabilities for
> all three classes. The Flutter app is the frontend: I built a simple 2D
> side-view driving scene with the Flame game engine — sky, road, a car
> drawn from the side, weather effects — purely as a visualization layer.
> The player controls two things, speed and seatbelt, and the environment
> auto-changes every 10 seconds through five predefined scenarios. Every
> time something changes, Flutter sends a real HTTP request to FastAPI and
> displays whatever comes back — there's no hardcoded logic anywhere
> translating conditions into a risk label; the label and percentage always
> come from the model."

---

## 4. ML explanation

The model is a **RandomForestClassifier** wrapped in a scikit-learn
`Pipeline` alongside its preprocessing (imputers, one-hot encoding,
scaling), so the saved file can take a raw row of data and return a
prediction with no separate preprocessing code needed elsewhere.

## 5. Dataset explanation

**BDRoadRisk** (Mendeley Data, DOI `10.17632/m33bsbsgx2.3`) — 10,000,000
synthetic GPS traffic-event records simulating Dhaka and Chittagong,
Bangladesh, 23 features + `accident_severity` as the target. It's
explicitly synthetic: the dataset's own description says labels were
"generated using a context-driven probabilistic model," with intentional
noise added at the class boundary. This project uses a 500,000-row
systematic sample (every 20th row) rather than the full 10M for
development speed, verified to preserve the original class balance almost
exactly.

## 6. Why Random Forest

Three models were compared fairly, under the same 5-fold cross-validation:
Logistic Regression (CV ROC-AUC 0.917), Random Forest (0.921), Extra Trees
(0.897). Random Forest wasn't picked because it's a "fancier" model — it
was picked because it scored highest on the metric that matters most for
an imbalanced 3-class problem (ROC-AUC), and it was competitive rather than
just narrowly ahead on the accuracy/precision/recall/F1 numbers too.

## 7. What train/test split means

Before comparing any models, the data was split 80/20 into a training set
and a held-out test set, **stratified** so both halves keep the same
74/17/8 class balance. The test set is never touched during training or
model selection — it exists purely to give one honest, final answer to
"how does this model do on data it has never seen."

## 8. What cross-validation means

Rather than trusting a single 80/20 split for *choosing* between models
(which could be lucky or unlucky depending on which rows land where),
5-fold cross-validation splits the training data into 5 equal chunks,
trains on 4 of them and tests on the 5th, repeats that 5 times so every
chunk gets used as the test set exactly once, then averages the 5 scores.
This gives a much more reliable estimate of how well a model generalizes.

## 9. Accuracy / Precision / Recall / F1 / ROC-AUC

- **Accuracy** — the fraction of predictions that were exactly right.
  Misleading here on its own: a model that always guesses "No_Accident"
  would score ~74% while being useless.
- **Precision** (per class) — of everything the model labeled as that
  class, what fraction actually was. High precision = few false alarms.
- **Recall** (per class) — of everything that actually was that class,
  what fraction the model caught. High recall = few missed cases.
- **F1** — the harmonic mean of precision and recall; a single number that
  penalizes a model for being lopsided toward one or the other.
- **Macro-averaged** — precision/recall/F1 are each computed per class,
  then averaged with equal weight across the 3 classes, so the rare `Major`
  class counts as much as the common `No_Accident` class in the headline
  number.
- **ROC-AUC** (one-vs-rest, macro) — measures how well the model *ranks*
  each class above the others, independent of any specific decision
  threshold. 0.5 = no better than random guessing; 1.0 = perfect ranking.
  This project's final model scored 0.920 on the held-out test set.

## 10. What predict_proba() means

Instead of just returning one label, `predict_proba()` returns a
probability for *every* class — e.g. `{"Major": 0.44, "Minor": 0.40,
"No_Accident": 0.16}` — which always sum to 1.0. The API returns all three
plus picks the highest as the headline prediction. This is the actual,
real, unmodified output of the trained model — nothing about it is
post-processed beyond rounding for display.

## 11. What data leakage means

Using information at training time that wouldn't genuinely be available,
or that was generated *from* the answer you're trying to predict — it
makes a model look artificially accurate while learning nothing real. In
this project, `junction_type` and `visibility_km` were excluded because the
dataset's own documentation admits their values were partly sampled based
on the eventual severity class — meaning a model using them would partly be
decoding the label from a feature built out of that label, not discovering
a genuine pattern.

## 12. Why some features were excluded

| Feature | Reason |
|---|---|
| `junction_type` | Dataset docs: "50/50 blend of road-class-driven **and severity-driven** distributions" — confirmed leakage. |
| `visibility_km` | Dataset docs: "Driven by weather condition **and severity class**" — confirmed leakage. |
| `acceleration_ms2` | Describes braking at the instant of a specific event, not a pre-existing condition a driver "has" in advance. |
| `reaction_time_sec` | Same — only meaningful in hindsight of a specific incident. |
| `temperature_celsius` | Dataset's own documentation: "non-predictive... Intentional noise feature." |

## 13. Why the dataset being synthetic is a limitation

Every row in BDRoadRisk was generated by a simulation, not observed in the
real world. That means the model can learn the *shape* of relationships the
dataset's designers built in (e.g., "no seatbelt correlates with more
severe outcomes" — a real, well-established road-safety fact) but the
specific numbers — exactly how much riskier, exactly which combinations
matter most — are a property of this benchmark's generator, not measured
reality. This is why the project documentation states clearly: **the
output probability must not be interpreted as a real-world accident
probability.** The project's value is in demonstrating a real, honest,
end-to-end ML + API + app pipeline — not in producing a deployable
real-world risk calculator.

## 14. FastAPI explanation

FastAPI is a Python web framework that turns typed Python functions into
HTTP endpoints with automatic request validation. This project has one
meaningful endpoint, `POST /predict`: it receives JSON, validates every
field (via Pydantic types plus an explicit check against the model's known
categories/ranges), builds one row of data, calls the saved pipeline's
`predict_proba()`, and returns JSON back. The model is loaded once at
server startup, not on every request.

## 15. Flutter explanation

Flutter is the UI framework — plain widgets (`Column`, `Slider`, custom
containers) built with a dark theme. State lives in `SimulatorPage`: current
speed, seatbelt status, active environment scenario, and the latest
`RiskResult` from the API. Changing speed/seatbelt or letting the
environment auto-cycle triggers a new HTTP request; the response updates
the state, which rebuilds the risk dashboard.

## 16. Flame explanation

Flame is a 2D game engine for Flutter, used here purely to draw and
animate the driving scene — sky, hills, road, a side-view car, weather
effects — as a visualization, not a game with rules or scoring. The car
stays in place; the road markings scroll to sell the feeling of movement,
at a speed tied to the current speed slider value (a visual cue only — the
actual API request always sends the exact speed number regardless of how
the animation looks).

## 17. Complete request/response flow

```
Player drags Speed slider
        ↓
Flutter: _onSpeedChanged() updates state, starts a 350ms debounce timer
        ↓ (after debounce fires)
Scenario.toApiFields() builds JSON:
  { speed_kmh, seatbelt_worn, weather_condition, road_surface,
    light_condition, time_of_day }
        ↓
RiskApiClient.predict() → POST http://127.0.0.1:8000/predict
        ↓
FastAPI: predict() route → predictor.predict(req)
        ↓
Predictor validates fields, merges with the 12 fixed-context defaults
into one full row
        ↓
pipeline.predict_proba(row)  ← the real, saved, trained scikit-learn Pipeline
        ↓
Response: { prediction, risk_label, probability, probability_percent, probabilities }
        ↓
Flutter: RiskResult.fromJson() parses it
        ↓
RiskDashboard widget re-renders: SAFE/MINOR RISK/HIGH RISK + % + color
```

---

## 18. Demo script

1. Open the app — point out the "model live" indicator (green dot means the
   backend responded to a health check).
2. Show the current environment pills (Weather / Road / Light) and the
   current risk card.
3. Wait for the 10-second auto-change (countdown shown bottom-right of the
   scene) — point out the risk percentage updates, and that it's a **new
   real API call**, visible in the "INPUT → output" strip at the bottom.
4. Drag the Speed slider from low to high — point out the debounce (it
   waits until you stop dragging before calling the API, not on every
   pixel of movement).
5. Toggle the Seatbelt OFF — an instant new prediction, no debounce needed
   for a discrete toggle.
6. Let it land on (or wait through a few cycles to reach) the Stormy Night
   scenario combined with high speed and no seatbelt, to show a High Risk
   state — point out the red border around the driving scene and the red
   risk card, and the decorative wind-gust lines (explain: visual only,
   not sent to the model).
7. Close by pointing at the input strip: *"this is the exact row of data
   being sent to the model — nothing is hidden or hardcoded."*

---

## 19. Expected instructor questions — honest answers

**Why did you choose this dataset?**
I tested two others first. The one I was originally given had zero real
predictive signal (ROC-AUC ≈ 0.50, verified with cross-validation) —
essentially random noise. A real police-recorded dataset had genuine but
modest signal, but no real speed or seatbelt columns, which would have
forced me to replace the core game controls with unrelated substitutes.
BDRoadRisk restores the original speed/seatbelt concept with real matching
columns, at the cost of being synthetic rather than real-world data — a
tradeoff I disclose clearly throughout the project.

**Why did you choose this target?**
`accident_severity` is the dataset's own target column — a 3-class
No_Accident/Minor/Major label. Unlike the real dataset I tested, BDRoadRisk
actually includes a No_Accident class, so the model genuinely predicts
"will this be an incident and how severe" rather than only "how severe,
given one already happened."

**Why did you remove some features?**
I read the dataset's own data dictionary carefully before training
anything. Two features (`junction_type`, `visibility_km`) were documented
as generated *from* the severity label itself — confirmed leakage. Two more
(`acceleration_ms2`, `reaction_time_sec`) describe the mechanics of a
specific incident rather than a pre-existing condition, so they don't fit
a real-time simulator regardless of leakage. One (`temperature_celsius`)
is explicitly documented by the dataset's authors as non-predictive noise.

**Why did you choose this ML model?**
Random Forest, selected by cross-validated ROC-AUC (0.921) across a fair
comparison against Logistic Regression (0.917) and Extra Trees (0.897), and
it was competitive — not just narrowly ahead — on every other metric too.

**What is overfitting?**
When a model memorizes quirks of the training data instead of learning
patterns that generalize — great on training data, worse on new data. This
project guards against it with cross-validation during model selection and
a held-out test set the model never saw until final evaluation.

**What is data leakage?**
Using information that wouldn't genuinely be available, or that was
generated from the answer itself — inflates apparent accuracy while
teaching the model nothing real. See §11/§12 above for exactly which
features were caught and why.

**Why is the dataset synthetic, and what does that mean for your results?**
Because no real dataset investigated combined genuine speed and seatbelt
columns with real-world grounding. I chose to be upfront about this rather
than present synthetic-benchmark numbers as if they were real-world
findings — the docs state explicitly that the output probability isn't a
calibrated real-world accident probability.

**Why do you need preprocessing?**
The model only understands numbers. Categorical features ("Rain",
"Motorcycle"...) need one-hot encoding before a classifier can use them;
numeric features are scaled; missing values are imputed — all bundled into
the saved pipeline so the API never has to reimplement any of it.

**Why use FastAPI?**
It's a fast, simple way to expose a Python (scikit-learn) model as an HTTP
API any client can call, with automatic request validation built in.

**Why not put the model directly inside Flutter?**
scikit-learn is Python; Flutter apps run Dart. There's no practical way to
run this trained pipeline inside the Flutter app itself, so a small server
in between is the standard pattern.

**What does the probability mean?**
The model's own `predict_proba()` output — its estimated probability, given
these conditions, that this event would be classified No_Accident, Minor,
or Major. It reflects patterns in a synthetic benchmark dataset, not
measured real-world accident statistics.

**How does the simulator communicate with the model?**
Flutter sends a JSON HTTP POST request to a locally-running FastAPI server;
the server runs the saved scikit-learn pipeline and returns JSON back.

**Is the prediction guaranteed to be correct?**
No — and I don't claim it is. The held-out test ROC-AUC is 0.920 and macro
recall is 0.770: real, well above chance, but not perfect, and computed
against a synthetic benchmark rather than real-world accident data.

**What are the limitations of the model?**
1. The dataset is 100% synthetic — no real accident records were used.
2. Several dataset features that would have boosted the reported accuracy
   were deliberately excluded because they were leakage or event-instant
   measurements, not because they didn't "help."
3. Some model features that matter a lot (driver experience, alcohol
   influence) are held fixed rather than exposed as controls, so the live
   demo only explores part of what the model actually learned.
4. Predicted probabilities should not be read as real-world accident
   probabilities.

## 20. Honest limitations and future improvements

**Limitations** (also stated in `README.md` and `PROJECT_GUIDE.md`):
- 100% synthetic training data.
- `junction_type`, `visibility_km`, `acceleration_ms2`, `reaction_time_sec`,
  and `temperature_celsius` were excluded — a stricter or looser leakage
  judgment call could change the feature set and the reported metrics.
- Several real model features (driver experience, alcohol influence,
  traffic density, vehicle age, driver age, road class/quality, speed limit
  zone, month, location) are fixed at default values rather than
  controllable, so the interactive demo shows only one slice of the
  model's learned behavior.
- Trained on a 500,000-row sample rather than the full 10,000,000 rows.

**Possible future improvements:**
- Train on the full 10M-row dataset (or a larger sample) to see whether
  metrics change meaningfully.
- Expose one or two of the fixed-context features (e.g. `driver_experience_level`)
  as additional optional controls, clearly labeled.
- Try additional models (Gradient Boosting, HistGradientBoosting) under
  the same cross-validation protocol.
- If a real-world dataset combining genuine speed/seatbelt telemetry with
  real accident outcomes ever becomes available, retrain on that instead
  and drop the synthetic-data disclosure.
