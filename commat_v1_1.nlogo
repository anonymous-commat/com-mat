extensions [ csv ]

; ============================================================
;  COM-MAT HEAT PUMP MODEL
; ============================================================

globals [
  dt
  population-data

  ; ---- time / population ----
  tick-counter
  initial-hp-target-share

  ; ---- global norm ----
  perceived-global-hp-norm

  ; ---- economic environment ----
  hp-price
  gas-elec-eff-ratio
  gas-elec-eff-ratio-baseline
  price-lt-beta

  ; ---- opportunity event ----
  renovation-rate-annual

  ; ---- belief / norm learning ----
  local-weight-share
  adopter-signal
  age-sat-strength
  norm-sharpen-slope
  norm-mid

  ; ---- boiler lifetime ----
  boiler-lifetime-mean
  boiler-lifetime-sd

  ; ---- network ----
  mean-degree
  long-range-link-prob
  network-sample-size

  ; ---- price shock ----
  survey-gas-price
  survey-electricity-price
  shock-gas-price

  ; ---- adoption ----
  beta0
  beta-o
  beta-m
  beta-age
  beta-om

  ; ---- experiments ----
  subsidy-window-sensitivity
  campaign-reach-prob
  campaign-motivation-boost
  campaign-valence-boost

  ; ---- extra price window ----
  price-window-threshold
  extra-window-price-sensitivity

]

turtles-own [
  ; ---- adoption state ----
  has-heat-pump?

  ; ---- COM-B core ----
  capable?
  opportunity
  motivation
  opportunity-trigger

  ; ---- HUMAT states ----
  experiential-hp-satisfaction
  pro-sustainability
  self-sufficiency
  status-quo-bias

  ; ---- experiential HP satisfaction (factors and associated weights) ----
  hpf-investment-costs
  hpf-running-costs
  hpf-system-performance
  hpf-noise
  hpf-home-value

  hpw-investment-costs
  hpw-running-costs
  hpw-system-performance
  hpw-noise
  hpw-home-value

  ; ---- norm sensitivity ----
  hp-norm-sensitivity-local
  hp-norm-sensitivity-global

  ; ---- media ----
  media-exposure-level
  media-valence
  media-exposure-baseline
  media-valence-baseline

  ; ---- capability barriers ----
  financially-unable?
  baseline-financially-unable?
  home-unsuitable?
  decision-restricted?

  ; ---- other ----
  heat-network-planned?
  on-district-heating?
  has-sun-boiler?
  rental-type
  urbanism
  education-level
  energy-label-code
  hp-willingness-to-pay

  ; ---- boiler states ----
  boiler-age
  boiler-lifetime

  ; ---- diagnosis ----
  recently-learned?
  trigger-type
  synthetic-id
  path-group
]

; ============================================================
;  SETUP
; ============================================================

to setup
  clear-all

  set dt 0.25
  set tick-counter 0

  setup-parameters

  random-seed seed-number

  setup-urbanism-patches
  load-population-data

  create-turtles length population-data [
    let my-data item who population-data
    initialize-agent my-data
  ]

  assign-urbanism-by-density
  position-turtles-in-concentric-circles
  setup-connections

  update-financial-capability
  update-capability

  seed-extra-initial-hp-owners

  update-global-norm

  recolor-all

  reset-ticks
end

to setup-parameters
  ; ---- population / initialization ----
  set initial-hp-target-share 0.08

  ; ---- economic defaults ----
  set hp-price hp-initial-price
  set survey-gas-price 1.30
  set survey-electricity-price 0.25
  set gas-elec-eff-ratio (gas-price / electricity-price) / 3
  set gas-elec-eff-ratio-baseline (survey-gas-price / survey-electricity-price) / 3
  set price-lt-beta 1.5

  ; ---- policy / environment ----
  set campaign-valence-boost 1

  ; ---- structural change ----
  set renovation-rate-annual 0.01

  ; ---- learning / norms ----
  set local-weight-share 0.60
  set adopter-signal 0.75
  set age-sat-strength 0.25
  set norm-sharpen-slope 2
  set norm-mid 0.20

  ; ---- boiler lifetimes ----
  set boiler-lifetime-mean 13.5
  set boiler-lifetime-sd 4.0

  ; ---- network ----
  set mean-degree 6
  set long-range-link-prob 0.02
  set network-sample-size 40

  ; ---- price shock ----
  set shock-gas-price 3.0

  ; ---- adoption ----
  set beta0 -2.6
  set beta-o 1.6
  set beta-m 1.8
  set beta-age 0.8
  set beta-om 0.8

  ; ---- extra price window ----
  set price-window-threshold 0.25
  set extra-window-price-sensitivity 0.60

  ; ---- experiments ----
  set subsidy-window-sensitivity 0.5
  set campaign-reach-prob 0.6
  set campaign-motivation-boost 0.10
end

; ---- LOADING FULL POP DATA WILL SLOW MODEL DOWN SIGNIFICANTLY, HERE 1,000 AGENTS ARE LOADED ----
to load-population-data
  let raw csv:from-file "synthetic_population_1.csv"
  let full-population but-first raw
  set population-data n-of 1000 full-population ; remove 'n-of ...' to set to full population
end

; ---- Initialize household agent with synthetic data ----
to initialize-agent [row]
  setxy random-xcor random-ycor
  set shape "house"
  set size 1

  set trigger-type "none" ; diagnosis
  set synthetic-id item 0 row ; diagnosis

  ; ---- rental / education ----
  let rental-code parse-num (item 6 row) 1
  set education-level parse-num (item 5 row) 0

  set rental-type "none"
  if rental-code = 2 [ set rental-type "private" ]
  if rental-code = 3 [ set rental-type "social" ]

  ; ---- heating system ----
  let heating-code parse-num (item 13 row) 1
  set on-district-heating? (heating-code = 4)
  set has-sun-boiler? (heating-code = 6)

  ; ---- initial adoption status ----
  let group-str item 117 row
  set path-group group-str

  ifelse path-group = "owner_hp" [
    set has-heat-pump? true
  ] [
    set has-heat-pump? false
  ]

  ; ---- barriers ----
  set baseline-financially-unable? (parse-num (item 30 row) 0 = 1)
  set financially-unable? baseline-financially-unable?
  set home-unsuitable? (parse-num (item 29 row) 0 = 1)
  set decision-restricted? ((parse-num (item 31 row) 0 = 1) or rental-code = 2 or rental-code = 3)

  set heat-network-planned? (random-float 1 < initial-heat-network-share)
  if on-district-heating? [
    set heat-network-planned? true
  ]

  if not has-heat-pump? [
    ; ---- experiential factors ----
    set hpf-investment-costs   likert1to5-or-neutral-neg  (item 47 row)
    set hpf-running-costs      likert1to5-or-neutral      (item 46 row)
    set hpf-system-performance likert1to5-or-neutral      (item 50 row)
    set hpf-noise              likert1to5-or-neutral-neg  (item 54 row)
    set hpf-home-value         likert1to5-or-neutral      (item 53 row)

    ; ---- factor weights ----
    set hpw-investment-costs   safe-weight-0-30 (parse-num (item 60 row) 0)
    set hpw-running-costs      safe-weight-0-30 (parse-num (item 59 row) 0)
    set hpw-system-performance safe-weight-0-30 (parse-num (item 63 row) 0)
    set hpw-noise              safe-weight-0-30 (parse-num (item 67 row) 0)
    set hpw-home-value         safe-weight-0-30 (parse-num (item 66 row) 0)

    ; ---- norms ----
    set hp-norm-sensitivity-local  clamp01 (((parse-num (item 72 row) 3) - 1) / 4)
    set hp-norm-sensitivity-global clamp01 (((parse-num (item 73 row) 3) - 1) / 4)

    ; ---- values ----
    set pro-sustainability clamp01 (((parse-num (item 8 row) 3) - 1) / 4)
    set self-sufficiency   clamp01 (((parse-num (item 9 row) 3) - 1) / 4)
    set status-quo-bias    clamp01 (((parse-num (item 10 row) 3) - 1) / 4)

    set experiential-hp-satisfaction compute-experiential-hp-satisfaction

    set hp-willingness-to-pay max list 0 (parse-num (item 83 row) 0)
    set energy-label-code parse-num (item 3 row) 4

  ]

  ; ---- media ----
  set media-exposure-level parse-num (item 93 row) 2
  set media-valence        parse-num (item 94 row) 3

  if media-exposure-level = 5 [ set media-exposure-level 4 ]

  set media-exposure-baseline media-exposure-level
  set media-valence-baseline  media-valence

  ; ---- boiler age / lifetime ----
  let age-code parse-num (item 21 row) 6
  let boiler-age-range age-range-from-code age-code
  set boiler-age sample-age-from-range boiler-age-range
  set boiler-lifetime draw-truncated-normal boiler-lifetime-mean boiler-lifetime-sd (boiler-age + dt)

  ; ---- COM-B starting states ----
  set capable? false
  set opportunity 0
  set motivation 0
  set opportunity-trigger 0
  set recently-learned? false
end

; ============================================================
;  MAIN LOOP
; ============================================================

to go
  set tick-counter tick-counter + 1

  update-economic-environment
  update-global-norm

  ask turtles [ set recently-learned? false ]

  update-home-suitability-from-label
  expand-heat-networks
  age-boilers
  update-opportunity-triggers
  update-financial-capability
  update-capability

  update-experiential-hp-satisfaction
  update-opportunity
  update-motivation

  maybe-adopt

  recolor-all
  tick
end

; ============================================================
;  CORE DYNAMICS
; ============================================================

; ---- Updates heat pump prices and energy prices ----
to update-economic-environment
  let t tick-counter * dt
  let current-year 2015 + t

  set hp-price hp-initial-price * ((1 - hp-price-annual-decline) ^ t)

  if electricity-price <= 0 [ set electricity-price 0.0001 ]

  let effective-gas-price gas-price

  ; ---- historical gas shock for calibration, if switched on in GUI ----
  if historical-gas-shock? and current-year >= 2021 and current-year < 2024 [
    set effective-gas-price shock-gas-price
  ]
  ; ----

  set gas-elec-eff-ratio (effective-gas-price / electricity-price) / 3
end

; ---- Updates global norm (share of population that owns a heat pump) ----
to update-global-norm
  if count turtles = 0 [
    set perceived-global-hp-norm 0
    stop
  ]
  set perceived-global-hp-norm (count turtles with [has-heat-pump?] / count turtles)
end

; ---- Updates home energy label with random probability that home is retrofitted ----
to update-home-suitability-from-label
  let p-improve per-tick-prob-from-annual label-annual-improvement-rate

  ask turtles with [home-unsuitable? and energy-label-code = 3 and not has-heat-pump?] [
    if random-float 1 < p-improve [
      set home-unsuitable? false
    ]
  ]
end

; ---- Expands district heating networks to homes not previously connected ----
to expand-heat-networks
  let pHN per-tick-prob-from-annual heat-network-expansion-rate

  ask turtles with [not heat-network-planned? and not has-heat-pump? and not on-district-heating?] [
    if random-float 1 < pHN [
      set on-district-heating? true
    ]
  ]
end

; ---- Boilers age each year ----
to age-boilers
  ask turtles with [not has-heat-pump?] [
    set boiler-age boiler-age + dt
  ]
end

; ---- Updates which agents are triggered into an Opportunity event from boiler EoL, moving, renovating, large price changes; probability increases with boiler age ----
to update-opportunity-triggers
  let p-move per-tick-prob-from-annual annual-move-prob
  let p-reno per-tick-prob-from-annual renovation-rate-annual

  ask turtles with [not has-heat-pump?] [
    set opportunity-trigger 0
    set trigger-type "none"

    if boiler-lifetime > 0 and boiler-age >= boiler-lifetime [
      set opportunity-trigger 1
      set trigger-type "eol"
    ]

    if random-float 1 < p-move [
      set opportunity-trigger 1
      set trigger-type "move"
    ]

    if random-float 1 < p-reno [
      set opportunity-trigger 1
      set trigger-type "reno"
    ]

    let price-pressure gas-price-pressure

    if capable? and
       not on-district-heating? and
       not heat-network-planned? and
       not has-sun-boiler? [

      let age-pressure 0
      if boiler-lifetime > 0 [
        set age-pressure clamp01 (boiler-age / boiler-lifetime)
      ]

      let p-price-window dt * extra-window-price-sensitivity * price-pressure * age-pressure

      if random-float 1 < p-price-window [
        set opportunity-trigger 1
        set trigger-type "price"
      ]

      let subsidy-pressure hp-subsidy-rate
      let p-subsidy-window dt * subsidy-window-sensitivity * subsidy-pressure * age-pressure

      if random-float 1 < p-subsidy-window [
        set opportunity-trigger 1
        set trigger-type "subsidy"
      ]
    ]
  ]
end

; ---- Updates which agents have financial capability by comparing the effective heat pump price with the agent's willingness-to-pay ----
to update-financial-capability
  ask turtles with [not has-heat-pump?] [
    let net-hp-price hp-price * (1 - hp-subsidy-rate)

    if baseline-financially-unable? [
      ifelse hp-willingness-to-pay >= net-hp-price
        [ set financially-unable? false ]
        [ set financially-unable? true ]
    ]
    if not baseline-financially-unable? [
      set financially-unable? false
    ]
  ]
end

; ---- Checks current Capability barriers to update agent's Capability ----
to update-capability
  ask turtles with [not has-heat-pump?] [
    set capable? not (financially-unable? or home-unsuitable? or decision-restricted?)
  ]

  ask turtles with [has-heat-pump?] [
    set capable? true
  ]
end

; ---- Updates experiential satisfaction with heat pump based on changes in investment/running costs and social/media learning ----
to update-experiential-hp-satisfaction
  ask turtles with [not has-heat-pump?] [
    ; ---- investment cost perception ----
    let net-hp-price hp-price * (1 - hp-subsidy-rate)

    ifelse hp-willingness-to-pay <= 0
      [ set hpf-investment-costs 0 ]
      [
        let ratio net-hp-price / hp-willingness-to-pay
        set hpf-investment-costs clamp01 (1 - clamp01 ((ratio - 0.5) / 1.0))
      ]

    ; ---- running cost perception ----
    let rel-change 0
    if gas-elec-eff-ratio-baseline > 0 [
      set rel-change (gas-elec-eff-ratio - gas-elec-eff-ratio-baseline) / gas-elec-eff-ratio-baseline
    ]

    set hpf-running-costs clamp01 (0.5 + price-lt-beta * rel-change)

    ; ---- recompute experiential belief ----
    set experiential-hp-satisfaction compute-experiential-hp-satisfaction

    ; ---- social learning ----
    let hp-neighbors link-neighbors with [has-heat-pump?]
    if any? hp-neighbors [
      set experiential-hp-satisfaction clamp01 (
        experiential-hp-satisfaction +
        learning-social * (adopter-signal - experiential-hp-satisfaction)
      )
      set recently-learned? true
    ]

    ; ---- media learning ----
    let effective-exposure media-exposure-baseline
    let effective-valence media-valence-baseline
    let sees-media? false

    if information-campaign? [
      if effective-valence != 6 [
        set effective-valence min list 5 (effective-valence + campaign-valence-boost)
      ]
      set sees-media? (random-float 1 < campaign-reach-prob)
    ]

    if not information-campaign? [
      set sees-media? (effective-valence != 6) and (random-float 1 < effective-exposure / 4)
    ]

    if sees-media? [
      let media-target (effective-valence - 1) / 4
      set experiential-hp-satisfaction clamp01 (
        experiential-hp-satisfaction +
        media-learning-rate * (media-target - experiential-hp-satisfaction)
      )
      set recently-learned? true
    ]
  ]
end

; ---- Updates whether an agent has Opportunity to adopt ----
to update-opportunity
  ask turtles with [not has-heat-pump?] [
    if on-district-heating? or has-sun-boiler? [
      set opportunity 0
      stop
    ]

    let base 0
    set base base + 0.25 * installer-availability
    set base base + 0.40 * opportunity-trigger

    if heat-network-planned? [
      set base base * 0.10
    ]

    set opportunity clamp01 base
  ]

  ask turtles with [has-heat-pump?] [
    set opportunity 1
  ]
end

; ---- Updates whether an agent has Motivation to adopt based on experiential, social, and value satisfaction ----
to update-motivation
  ask turtles with [not has-heat-pump?] [
    let local-share local-hp-share
    let global-share perceived-global-hp-norm

    let local-norm 1 / (1 + exp (- norm-sharpen-slope * (local-share - norm-mid) * 4))
    let global-norm 1 / (1 + exp (- norm-sharpen-slope * (global-share - norm-mid) * 4))

    let effective-local  hp-norm-sensitivity-local  * local-norm
    let effective-global hp-norm-sensitivity-global * global-norm

    let social-norm clamp01 (
      local-weight-share * effective-local +
      (1 - local-weight-share) * effective-global
    )

    let pro-hp-values (pro-sustainability + self-sufficiency) / 2
    let anti-hp-value status-quo-bias

    let value-satisfaction clamp01 (
      (pro-hp-values + (1 - anti-hp-value)) / 2
    )

    set motivation clamp01 (
      total-sat-w-exp    * experiential-hp-satisfaction +
      total-sat-w-social * social-norm +
      total-sat-w-values * value-satisfaction
    )

    if information-campaign? and recently-learned? [
      set motivation clamp01 (motivation + campaign-motivation-boost)
    ]
  ]

  ask turtles with [has-heat-pump?] [
    set motivation 1
  ]
end

; --- Adoption decision-making, gated by Capability ----
to maybe-adopt
  ask turtles with [
    path-group = "owner_no_hp" and
    not has-heat-pump? and
    not on-district-heating? and
    capable?
  ] [
    let at-end-of-life? (boiler-lifetime > 0 and boiler-age >= boiler-lifetime)

    ; ---- heat pump adoption under heat pump-by-default policy
    if hp-standardization? and
       at-end-of-life? and
       capable? and
       not decision-restricted? and
       not on-district-heating? and
       not heat-network-planned? and
       not has-sun-boiler? [

      adopt-hp
      stop

    ]

    ; ---- heat pump adoption under baseline
    if random-float 1 < adoption-probability self [

      adopt-hp

    ]

    ; ---- if no heat pump is adopted at boiler EoL, agent adopts new boiler
    if not has-heat-pump? and at-end-of-life? [
      set boiler-age 0
      set boiler-lifetime draw-truncated-normal boiler-lifetime-mean boiler-lifetime-sd dt
    ]
  ]
end



; ---- Fixes attribute states for heat pump owner ----
to adopt-hp
  set has-heat-pump? true
  set on-district-heating? false
  set heat-network-planned? false
  set has-sun-boiler? false
  set capable? true
  set opportunity 1
  set motivation 1
  set experiential-hp-satisfaction adopter-signal
  set boiler-age 0
  set boiler-lifetime 0
  set opportunity-trigger 0
end

; ============================================================
;  NETWORK / SPACE
; ============================================================

; ---- Sets up social network and hides links in the map ----
to setup-connections
  ask turtles [
    let needed mean-degree - count my-links
    if needed < 0 [ set needed 0 ]

    repeat needed [
      let candidates n-of-up-to network-sample-size turtles with
        [self != myself and not link-neighbor? myself]

      if any? candidates [
        let similar candidates with [
          (urbanism = [urbanism] of myself) or
          (education-level = [education-level] of myself)
        ]

        let choice-pool nobody
        ifelse any? similar
          [ set choice-pool similar ]
          [ set choice-pool candidates ]

        let partner one-of choice-pool
        if partner != nobody [
          create-link-with partner [ hide-link ]
        ]
      ]
    ]

    if random-float 1 < long-range-link-prob [
      let partner one-of turtles with [self != myself and not link-neighbor? myself]
      if partner != nobody [
        create-link-with partner [ hide-link ]
      ]
    ]
  ]
end

; ---- Creates 5 concentric rings each depicting a level of urbanism with associated population density ----
to setup-urbanism-patches
  let n-levels 5
  let max-radius min list max-pxcor max-pycor
  let ring-width max-radius / n-levels

  ask patches [
    let r distancexy 0 0

    if r > max-radius [
      set pcolor white
      stop
    ]

    let level floor (r / ring-width) + 1
    if level > n-levels [ set level n-levels ]

    if level = 1 [ set pcolor 105 ]
    if level = 2 [ set pcolor 106 ]
    if level = 3 [ set pcolor 107 ]
    if level = 4 [ set pcolor 108 ]
    if level = 5 [ set pcolor 109 ]
  ]
end

; ---- Assigns household an urbanism level, respecting population densities of each level ----
to assign-urbanism-by-density
  let densities [2000 1500 750 375 200]
  let n-levels length densities

  let max-radius sqrt ((max-pxcor ^ 2) + (max-pycor ^ 2))
  let ring-width max-radius / n-levels

  ask turtles [ set urbanism 0 ]

  let ring-demands []
  let i 0
  while [i < n-levels] [
    let r-min ring-width * i
    let r-max ring-width * (i + 1)
    let area pi * (r-max ^ 2 - r-min ^ 2)
    let demand area * item i densities
    set ring-demands lput demand ring-demands
    set i i + 1
  ]

  let total-demand sum ring-demands
  let total-turtles count turtles

  let ring-counts []
  set i 0
  while [i < n-levels] [
    let share (item i ring-demands) / total-demand
    set ring-counts lput round (share * total-turtles) ring-counts
    set i i + 1
  ]

  set i 0
  while [i < n-levels] [
    let requested item i ring-counts
    let available turtles with [urbanism = 0]
    let num min list requested count available
    let chosen n-of-up-to num available
    ask chosen [ set urbanism (i + 1) ]
    set i i + 1
  ]

  ask turtles with [urbanism = 0] [
    set urbanism n-levels
  ]
end

; ---- Positions households on map ----
to position-turtles-in-concentric-circles
  let n-levels 5
  let max-radius min list max-pxcor max-pycor
  let ring-width max-radius / n-levels

  ask turtles [
    let level urbanism
    let r-min ring-width * (level - 1)
    let r-max ring-width * level
    let r r-min + random-float (r-max - r-min)
    let theta random-float 360
    setxy (r * cos theta) (r * sin theta)
  ]
end

; ============================================================
;  INITIALIZATION HELPERS
; ============================================================

; ---- Seed more heat pump owners in addition to survey-derived heat pump owners to arrive at Dutch national share of heat pump adopters in 2025 (8%) ----
to seed-extra-initial-hp-owners
  let total count turtles
  if total = 0 [ stop ]

  let target round (initial-hp-target-share * total)
  let current count turtles with [has-heat-pump?]
  let extra max list 0 (target - current)
  if extra = 0 [ stop ]

  ask n-of-up-to extra turtles with [
    not has-heat-pump? and
    rental-type = "none" and
    not on-district-heating? and
    not has-sun-boiler? and
    not heat-network-planned? and
    capable?
  ] [
    adopt-hp
  ]
end

to recolor-all
  ask turtles [ update-color ]
end

; ---- Colors the homes in map ----
to update-color
  ifelse (rental-type = "private" or rental-type = "social") [
    set color yellow ; Renter
  ] [
    ifelse has-heat-pump? [
      set color 64 ; Heat pump adopter
    ] [
      ifelse (on-district-heating? or has-sun-boiler? or heat-network-planned?) [
        set color violet ; Alternative (non-HP) sustainable heating system owner
      ] [
        ifelse capable? [
          set color 25 ; Boiler owner capable to adopt heat pump
        ] [
          set color 14 ; Currently not capable to adopt heat pump
        ]
      ]
    ]
  ]
end

; ============================================================
;  REPORTERS / HELPERS
; ============================================================

to-report adoption-probability [ag]
  let p 0

  ask ag [
    let age-pressure 0
    if boiler-lifetime > 0 [
      set age-pressure clamp01 (boiler-age / boiler-lifetime)
    ]

    let score (
      beta0 +
      beta-o * opportunity +
      beta-m * motivation +
      beta-age * age-pressure +
      beta-om * opportunity * motivation
    )

    set p clamp01 (1 / (1 + exp (- score)))

    if opportunity-trigger = 0 [
      set p 0
    ]

    if not capable? [
      set p 0
    ]
  ]

  report clamp01 p
end

to-report current-social-norm
  let local-share local-hp-share
  let global-share perceived-global-hp-norm

  let local-norm 1 / (1 + exp (- norm-sharpen-slope * (local-share - norm-mid) * 4))
  let global-norm 1 / (1 + exp (- norm-sharpen-slope * (global-share - norm-mid) * 4))

  let effective-local  hp-norm-sensitivity-local  * local-norm
  let effective-global hp-norm-sensitivity-global * global-norm

  report clamp01 (
    local-weight-share * effective-local +
    (1 - local-weight-share) * effective-global
  )
end

to-report current-pro-hp-values
  report clamp01 (
    (pro-sustainability + self-sufficiency) / 2
  )
end

to-report gas-price-pressure
  if gas-elec-eff-ratio-baseline <= 0 [ report 0 ]
  let ratio-change ((gas-elec-eff-ratio / gas-elec-eff-ratio-baseline) - 1)
  report max list 0 (ratio-change - price-window-threshold)
end

to-report compute-experiential-hp-satisfaction
  let total 0
  let total-weight 0

  set total total + (hpf-investment-costs   * hpw-investment-costs)
  set total-weight total-weight + hpw-investment-costs

  set total total + (hpf-running-costs      * hpw-running-costs)
  set total-weight total-weight + hpw-running-costs

  set total total + (hpf-system-performance * hpw-system-performance)
  set total-weight total-weight + hpw-system-performance

  set total total + (hpf-noise              * hpw-noise)
  set total-weight total-weight + hpw-noise

  set total total + (hpf-home-value         * hpw-home-value)
  set total-weight total-weight + hpw-home-value

  if total-weight = 0 [ report 0.5 ]
  report clamp01 (total / total-weight)
end

to-report safe-weight-0-30 [n]
  if n < 0 [ report 0 ]
  if n > 30 [ report 30 ]
  report n
end

to-report local-hp-share
  let neigh link-neighbors
  if not any? neigh [
    report perceived-global-hp-norm
  ]
  report count neigh with [has-heat-pump?] / count neigh
end

to-report hp-share-percent
  if count turtles = 0 [ report 0 ]
  report 100 * count turtles with [has-heat-pump?] / count turtles
end

to-report mean-motivation-nonadopters
  let xs turtles with [not has-heat-pump?]
  if not any? xs [ report 0 ]
  report mean [motivation] of xs
end

to-report mean-opportunity-nonadopters
  let xs turtles with [not has-heat-pump?]
  if not any? xs [ report 0 ]
  report mean [opportunity] of xs
end

to-report per-tick-prob-from-annual [p-annual]
  report 1 - ((1 - p-annual) ^ dt)
end

to-report clamp01 [x]
  report max list 0 min list 1 x
end

to-report parse-num [x default-value]
  if is-number? x [ report x ]

  let result default-value
  carefully [
    set result read-from-string x
  ] [
    set result default-value
  ]
  report result
end

to-report likert1to5-or-neutral [raw]
  let v parse-num raw 3
  if v = 6 [ set v 3 ]
  if v < 1 or v > 5 [ set v 3 ]
  report (v - 1) / 4
end

to-report likert1to5-or-neutral-neg [raw]
  let v parse-num raw 3
  if v = 6 [ set v 3 ]
  if v < 1 or v > 5 [ set v 3 ]
  let base (v - 1) / 4
  report 1 - base
end

to-report age-range-from-code [age-code]
  let age-ranges ["0-4" "5-9" "10-14" "15-19" "20+" "idk"]

  if age-code = 1 [ report item 0 age-ranges ]
  if age-code = 2 [ report item 1 age-ranges ]
  if age-code = 3 [ report item 2 age-ranges ]
  if age-code = 4 [ report item 3 age-ranges ]
  if age-code = 5 [ report item 4 age-ranges ]
  if age-code = 6 [ report item 5 age-ranges ]

  report "idk"
end

to-report sample-age-from-range [range-str]
  if range-str = "0-4"   [ report random 5 ]
  if range-str = "5-9"   [ report 5 + random 5 ]
  if range-str = "10-14" [ report 10 + random 5 ]
  if range-str = "15-19" [ report 15 + random 5 ]
  if range-str = "20+"   [ report 20 + random 5 ]
  if range-str = "idk"   [ report random 20 ]
  report random 20
end

to-report draw-truncated-normal [mu sd lower]
  let x random-normal mu sd
  while [x < lower] [
    set x random-normal mu sd
  ]
  report x
end

to-report n-of-up-to [n agentset-input]
  if n <= 0 [ report no-turtles ]
  let k min list n count agentset-input
  if k <= 0 [ report no-turtles ]
  report n-of k agentset-input
end
@#$#@#$#@
GRAPHICS-WINDOW
605
20
1263
679
-1
-1
19.7
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
30
55
93
88
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
100
55
163
88
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1290
400
1470
445
HP adoption (%)
hp-share-percent
0
1
11

MONITOR
1290
445
1470
490
Mean motivation (non-adopters)
mean-motivation-nonadopters
2
1
11

MONITOR
1290
490
1470
535
Mean opportunity (non-adopters)
mean-opportunity-nonadopters
2
1
11

MONITOR
1290
580
1470
625
Capable households (%)
100 * count turtles with [capable?] / count turtles
0
1
11

MONITOR
1290
535
1470
580
Agents in decision window
count turtles with [opportunity-trigger = 1 and not has-heat-pump?]
0
1
11

PLOT
1290
20
1850
370
Adoption share
ticks
%
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"HP %" 1.0 0 -16777216 true "" "plot hp-share-percent"

SLIDER
30
250
225
283
installer-availability
installer-availability
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
30
435
225
468
learning-social
learning-social
0
1
0.25
0.01
1
NIL
HORIZONTAL

SLIDER
265
400
425
433
hp-subsidy-rate
hp-subsidy-rate
0
1
0.3
0.1
1
NIL
HORIZONTAL

INPUTBOX
30
100
105
160
seed-number
7.0
1
0
Number

SLIDER
30
290
225
323
hp-initial-price
hp-initial-price
3000
15000
8000.0
500
1
NIL
HORIZONTAL

SLIDER
30
320
225
353
hp-price-annual-decline
hp-price-annual-decline
0
0.3
0.02
0.01
1
NIL
HORIZONTAL

SLIDER
30
395
225
428
gas-price
gas-price
0.1
4
1.3
0.05
1
EUR/m3
HORIZONTAL

SLIDER
30
360
225
393
electricity-price
electricity-price
0.1
3
0.25
0.05
1
EUR/kWh
HORIZONTAL

SLIDER
30
505
225
538
label-annual-improvement-rate
label-annual-improvement-rate
0
1
0.05
0.05
1
NIL
HORIZONTAL

SLIDER
30
180
225
213
initial-heat-network-share
initial-heat-network-share
0
1
0.01
0.01
1
NIL
HORIZONTAL

SLIDER
30
210
225
243
heat-network-expansion-rate
heat-network-expansion-rate
0
1
0.01
0.01
1
NIL
HORIZONTAL

SWITCH
265
440
425
473
information-campaign?
information-campaign?
1
1
-1000

SWITCH
265
360
427
393
hp-standardization?
hp-standardization?
1
1
-1000

BUTTON
170
55
242
88
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
265
540
425
573
historical-gas-shock?
historical-gas-shock?
1
1
-1000

SLIDER
30
465
225
498
media-learning-rate
media-learning-rate
0
1
0.15
0.01
1
NIL
HORIZONTAL

SLIDER
30
585
225
618
total-sat-w-exp
total-sat-w-exp
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
30
615
225
648
total-sat-w-social
total-sat-w-social
0
1
0.38
0.01
1
NIL
HORIZONTAL

SLIDER
30
645
225
678
total-sat-w-values
total-sat-w-values
0
1
0.12
0.01
1
NIL
HORIZONTAL

SLIDER
30
545
225
578
annual-move-prob
annual-move-prob
0.01
0.2
0.02
0.01
1
NIL
HORIZONTAL

TEXTBOX
270
335
420
353
Policy interventions
14
0.0
1

TEXTBOX
270
515
420
533
Calibration
14
0.0
1

TEXTBOX
290
55
545
100
Green homes have adopted a heat pump
14
63.0
1

TEXTBOX
290
85
545
136
Orange homes have a boiler and are capable of adopting a heat pump
14
24.0
1

TEXTBOX
290
135
545
201
Red homes have a boiler and are currently not capable of adopting a heat pump
14
14.0
1

TEXTBOX
290
200
550
231
Yellow homes are rental accommodations
14
44.0
1

TEXTBOX
290
235
555
316
Purple homes are connected to district heating /an alternative sustainable heating system
14
114.0
1

TEXTBOX
435
360
600
386
If on: At end-of-life, boiler should be replaced by a heat pump
11
0.0
1

TEXTBOX
435
405
585
431
Reduce investment costs with x 100 %
11
0.0
1

TEXTBOX
435
440
585
481
If on: More frequent/positive media communication
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="subsidy_test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <metric>n-nonadopters-incapable</metric>
    <metric>n-nonadopters-heatnetwork</metric>
    <metric>n-nonadopters-no-window</metric>
    <metric>n-nonadopters-low-motivation</metric>
    <steppedValueSet variable="seed-number" first="1" step="1" last="30"/>
    <enumeratedValueSet variable="hp-subsidy-rate">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="info_c_test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <metric>n-nonadopters-incapable</metric>
    <metric>n-nonadopters-heatnetwork</metric>
    <metric>n-nonadopters-no-window</metric>
    <metric>n-nonadopters-low-motivation</metric>
    <steppedValueSet variable="seed-number" first="1" step="1" last="30"/>
    <enumeratedValueSet variable="information-campaign">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="stand_test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <steppedValueSet variable="seed-number" first="1" step="1" last="30"/>
    <enumeratedValueSet variable="hp-standardization">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="calibration_0319" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="40"/>
    <metric>hp-share-percent</metric>
    <metric>param-set-id</metric>
    <metric>seed-number</metric>
    <steppedValueSet variable="param-set-id" first="0" step="1" last="2"/>
    <enumeratedValueSet variable="seed-number">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="shock_test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="40"/>
    <metric>hp-share-percent</metric>
    <metric>current-sim-year</metric>
    <metric>adopt-eol</metric>
    <metric>adopt-move</metric>
    <metric>adopt-reno</metric>
    <metric>adopt-price</metric>
    <metric>mean-motivation-pre2021</metric>
    <metric>mean-opportunity-when-triggered</metric>
    <steppedValueSet variable="seed-number" first="0" step="1" last="9"/>
    <enumeratedValueSet variable="historical-gas-shock?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test_run" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="40"/>
    <metric>hp-share-percent</metric>
    <metric>current-sim-year</metric>
    <metric>adopt-eol</metric>
    <metric>adopt-move</metric>
    <metric>adopt-reno</metric>
    <metric>adopt-price</metric>
    <metric>mean-motivation-pre2021</metric>
    <metric>mean-opportunity-when-triggered</metric>
    <steppedValueSet variable="seed-number" first="0" step="1" last="9"/>
  </experiment>
  <experiment name="shock_calibration" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>hp-share-percent</metric>
    <metric>current-threshold</metric>
    <metric>current-sensitivity</metric>
    <steppedValueSet variable="seed-number" first="0" step="1" last="9"/>
    <enumeratedValueSet variable="price-window-threshold">
      <value value="0.15"/>
      <value value="0.2"/>
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extra-window-price-sensitivity">
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="calibration_0324" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="40"/>
    <metric>hp-share-percent</metric>
    <metric>param-set-id</metric>
    <metric>seed-number</metric>
    <steppedValueSet variable="param-set-id" first="0" step="1" last="299"/>
    <enumeratedValueSet variable="seed-number">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="light_calib" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="learning-social">
      <value value="0.05"/>
      <value value="0.15"/>
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="media-learning-rate">
      <value value="0.05"/>
      <value value="0.15"/>
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-sharpen-slope">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-mid">
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="seed-number">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="calib_weights" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>hp-share-percent</metric>
    <steppedValueSet variable="param-set-id" first="0" step="1" last="299"/>
    <enumeratedValueSet variable="seed-number">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="calib_beta" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>hp-share-percent</metric>
    <metric>current-beta0</metric>
    <metric>current-beta-age</metric>
    <metric>current-beta-om</metric>
    <enumeratedValueSet variable="beta0">
      <value value="-2.6"/>
      <value value="-2.9"/>
      <value value="-3.2"/>
      <value value="-3.5"/>
      <value value="-3.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta-age">
      <value value="0.8"/>
      <value value="0.6"/>
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta-om">
      <value value="0.8"/>
      <value value="0.6"/>
      <value value="0.4"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="4"/>
  </experiment>
  <experiment name="calib_beta_o_m" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>hp-share-percent</metric>
    <metric>current-beta-o</metric>
    <metric>current-beta-m</metric>
    <enumeratedValueSet variable="beta-o">
      <value value="1.1"/>
      <value value="1.3"/>
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta-m">
      <value value="1.3"/>
      <value value="1.5"/>
      <value value="1.7"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="4"/>
  </experiment>
  <experiment name="borogonovo_sa_0327" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <steppedValueSet variable="run-id" first="1" step="1" last="720"/>
  </experiment>
  <experiment name="ofat" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <metric>ofat-parameter</metric>
    <metric>ofat-test-level</metric>
    <metric>ofat-test-value</metric>
    <steppedValueSet variable="run-id" first="1" step="1" last="720"/>
  </experiment>
  <experiment name="valid_sweden" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <steppedValueSet variable="seed-number" first="0" step="1" last="99"/>
  </experiment>
  <experiment name="scenario_dh" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="heat-network-expansion-rate">
      <value value="0.005"/>
      <value value="0.01"/>
      <value value="0.03"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="scenario_price" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="hp-price-annual-decline">
      <value value="0.01"/>
      <value value="0.02"/>
      <value value="0.05"/>
      <value value="0.15"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="scenario_move" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="annual-move-prob">
      <value value="0.01"/>
      <value value="0.02"/>
      <value value="0.05"/>
      <value value="0.1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="scenario_label" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="label-annual-improvement-rate">
      <value value="0.025"/>
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="exp_subsidy" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <metric>n-adopt-total</metric>
    <metric>n-adopt-eol</metric>
    <metric>n-adopt-move</metric>
    <metric>n-adopt-reno</metric>
    <metric>n-adopt-price</metric>
    <metric>mean-motivation-nonadopters</metric>
    <metric>mean-opportunity-nonadopters</metric>
    <metric>n-nonadopters-incapable</metric>
    <steppedValueSet variable="seed-number" first="1" step="1" last="50"/>
    <enumeratedValueSet variable="hp-subsidy-rate">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp_info_c" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <metric>n-adopt-total</metric>
    <metric>n-adopt-eol</metric>
    <metric>n-adopt-move</metric>
    <metric>n-adopt-reno</metric>
    <metric>n-adopt-price</metric>
    <metric>mean-motivation-nonadopters</metric>
    <metric>mean-opportunity-nonadopters</metric>
    <metric>n-nonadopters-incapable</metric>
    <steppedValueSet variable="seed-number" first="1" step="1" last="50"/>
    <enumeratedValueSet variable="information-campaign?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="exp_stand" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <metric>n-adopt-total</metric>
    <metric>n-adopt-eol</metric>
    <metric>n-adopt-move</metric>
    <metric>n-adopt-reno</metric>
    <metric>n-adopt-price</metric>
    <metric>mean-motivation-nonadopters</metric>
    <metric>mean-opportunity-nonadopters</metric>
    <metric>n-nonadopters-incapable</metric>
    <steppedValueSet variable="seed-number" first="1" step="1" last="50"/>
    <enumeratedValueSet variable="hp-standardization?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="calib_0410" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>hp-share-percent</metric>
    <steppedValueSet variable="seed-number" first="0" step="1" last="99"/>
    <enumeratedValueSet variable="historical-gas-shock?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="calib_0410_sh" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>hp-share-percent</metric>
    <steppedValueSet variable="seed-number" first="0" step="1" last="99"/>
    <enumeratedValueSet variable="historical-gas-shock?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="scenario_dh_1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="heat-network-expansion-rate">
      <value value="0.005"/>
      <value value="0.01"/>
      <value value="0.02"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="scenario_price_1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="hp-price-annual-decline">
      <value value="0.01"/>
      <value value="0.02"/>
      <value value="0.04"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="scenario_label_1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="label-annual-improvement-rate">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="scen_sub_b" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="heat-network-expansion-rate">
      <value value="0.005"/>
      <value value="0.01"/>
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hp-subsidy-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="scen_pol_0415" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="hp-standardization?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="information-campaign?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hp-subsidy-rate">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="heat-network-expansion-rate">
      <value value="0.005"/>
      <value value="0.01"/>
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="label-annual-improvement-rate">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hp-price-annual-decline">
      <value value="0.01"/>
      <value value="0.02"/>
      <value value="0.04"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="pol_scen_dh" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="hp-standardization?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="information-campaign?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hp-subsidy-rate">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="heat-network-expansion-rate">
      <value value="0.005"/>
      <value value="0.01"/>
      <value value="0.02"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="pol_scen_label" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="hp-standardization?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="information-campaign?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hp-subsidy-rate">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="label-annual-improvement-rate">
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.15"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="pol_scen_price" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <enumeratedValueSet variable="hp-standardization?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="information-campaign?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hp-subsidy-rate">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hp-price-annual-decline">
      <value value="0.01"/>
      <value value="0.02"/>
      <value value="0.04"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
  <experiment name="pol_mix" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>hp-share-percent</metric>
    <metric>mean-motivation-adopters</metric>
    <metric>share-nonadopters-financially-unable</metric>
    <metric>share-adopt-subsidy</metric>
    <enumeratedValueSet variable="hp-standardization?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="information-campaign?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hp-subsidy-rate">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-number" first="0" step="1" last="49"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
