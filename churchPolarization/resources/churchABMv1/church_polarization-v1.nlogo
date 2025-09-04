;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Political Polarization in Church Communities - Agent-Based Model
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Global variables
globals [
  num-seats                 ; Fixed number of church seats (400)

  ;; Network parameters
  initial-connections       ; Average number of initial connections per person
  rewiring-probability      ; Probability of rewiring connections (for small-world)
  max-spatial-distance      ; Maximum distance for spatial connections
]

;; Church member breed
breed [churchgoers churchgoer]

;; Agent properties
churchgoers-own [
  political-leaning         ; Range -1 to 1 (progressive to conservative)
  threshold-tolerance       ; Scalar 0 to 1 (tolerance for political diversity)
  activity-level           ; Range 0 to 1 (probability of attending services)
  emotional-state          ; Range -1 to 1 (emotional well-being)

  home-x                   ; Fixed x position (church seat)
  home-y                   ; Fixed y position (church seat)
  attending?               ; Boolean: is agent attending this Sunday?

  ;; Interaction tracking
  interaction-score        ; Quality of interactions this Sunday (for emotional updates)

  ;; Church membership status
  active-member?           ; Boolean: is agent still an active member of the church?
  weeks-since-attendance   ; Counter for consecutive weeks of non-attendance
]

;; Link properties for network connections
undirected-link-breed [connections connection]
connections-own [
  tie-strength             ; Strength of relationship (0 to 1)
  political-similarity     ; Political similarity between connected agents
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SETUP PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all

  ;; Set global parameters
  set num-seats 400          ; Fixed church capacity
  ; num-members is controlled by the interface slider
  ; alpha is controlled by the interface slider
  ; beta is controlled by the interface slider
  ; base-emotional-state is controlled by the interface slider

  ;; Network parameters
  set initial-connections 6   ; Average connections per person (creates connected network)
  set rewiring-probability 0.1 ; Small-world rewiring probability
  set max-spatial-distance 3  ; Maximum distance for spatial connections

  ;; Setup world (church layout)
  setup-world

  ;; Create church members
  create-members

  ;; Position members in church seats
  assign-church-seats

  ;; Initialize agent properties
  initialize-member-properties

  ;; Create social network
  create-social-network

  ;; Visualize the setup
  update-display

  ;; Initialize plots
  initialize-plots

  reset-ticks
end

to initialize-plots
  ;; Initialize plots after network creation
  set-current-plot "Degree Distribution"
  plot-degree-distribution
end

to setup-world
  ;; Create a church with exactly 400 seats
  ;; Layout: 25 rows × 16 seats per row (8 on each side of center aisle)
  ;; Total: 25 × 16 = 400 seats exactly

  ;; Use 27 rows total to include altar space
  resize-world 0 17 0 26

  ;; Ensure world doesn't wrap around
  __change-topology false false

  ;; Set patch colors to represent church interior
  ask patches [
    set pcolor white + 2  ; Light church interior color
  ]

  ;; Add some visual elements for church layout
  ;; Center aisle (2 columns in the middle)
  ask patches with [pxcor = 8 or pxcor = 9] [
    set pcolor gray + 1
  ]

  ;; Altar area at the front (top 2 rows)
  ask patches with [pycor >= 25] [
    set pcolor brown + 1
  ]
end

to create-members
  create-churchgoers num-members [
    set shape "person"
    set size 0.8
    set attending? true  ; Initially all members attend
  ]
end

to assign-church-seats
  ;; Create exactly 400 seats: 25 rows × 16 seats per row
  ;; Layout: 8 seats | center aisle | 8 seats per row
  ;; Rows 0-24 are pews, rows 25+ are altar area
  ;; People can sit anywhere, including on separator lines

  let seat-positions []

  ;; Generate all 400 seat positions
  foreach (range 0 25) [ row ->  ; 25 pew rows (0-24)
    ;; Left side: 8 seats (columns 0-7)
    foreach (range 0 8) [ col ->
      set seat-positions lput (list col row) seat-positions
    ]
    ;; Right side: 8 seats (columns 10-17, skipping aisle at 8-9)
    foreach (range 10 18) [ col ->
      set seat-positions lput (list col row) seat-positions
    ]
  ]

  ;; Verify we have exactly 400 seats
  if length seat-positions != 400 [
    print (word "ERROR: Expected 400 seats, got " length seat-positions)
  ]

  ;; Now assign members to seats (only if there are members)
  if num-members > 0 [
    let member-list sort churchgoers
    let members-to-seat min (list num-members num-seats)

    foreach (range 0 members-to-seat) [ i ->
      let seat-pos item i seat-positions
      let seat-x item 0 seat-pos
      let seat-y item 1 seat-pos

      ask item i member-list [
        set home-x seat-x
        set home-y seat-y
        setxy home-x home-y
      ]
    ]

    ;; If there are more members than seats, place extras in the aisles
    ;; This should never happen
    if num-members > num-seats [
      foreach (range num-seats num-members) [ i ->
        ask item i member-list [
          set home-x 8 + random 2  ; center aisle
          set home-y random 25      ; avoid altar area
          setxy home-x home-y
        ]
      ]
    ]
  ]
end

to initialize-member-properties
  ask churchgoers [
    ;; Political leaning: normal distribution around 0 with some spread
    set political-leaning random-normal 0 0.4
    ;; Clamp to [-1, 1] range
    if political-leaning > 1 [ set political-leaning 1 ]
    if political-leaning < -1 [ set political-leaning -1 ]

    ;; Threshold tolerance: uniform distribution
    set threshold-tolerance random-float 1

    ;; Activity level: initially high (most people attend regularly)
    set activity-level 0.7 + random-float 0.3

    ;; Initial emotional state: start neutral to positive
    set emotional-state base-emotional-state + random-normal 0 0.2
    ;; Clamp to [-1, 1] range
    if emotional-state > 1 [ set emotional-state 1 ]
    if emotional-state < -1 [ set emotional-state -1 ]

    ;; Initialize interaction tracking
    set interaction-score 0

    ;; Initialize church membership status
    set active-member? true
    set weeks-since-attendance 0
  ]
end

to update-display
  ;; Color agents based on political leaning
  ask churchgoers [
    ;; Red for conservative, blue for progressive, purple for moderate
    let red-component (political-leaning + 1) / 2 * 255
    let blue-component (1 - political-leaning) / 2 * 255
    set color rgb red-component 0 blue-component
  ]

  ;; Show or hide network connections based on switch
  ask connections [
    set hidden? not show-links?
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; NETWORK CREATION PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to create-social-network
  ;; Create initial network based on likely attendance patterns
  ;; Only create connections between people who are likely to attend regularly
  ;; Step 1: Create connections only among high-activity members
  create-initial-connections-for-regular-attendees

  ;; Step 2: Add some connections based on political homophily (but still activity-dependent)
  add-homophily-connections-among-attendees

  ;; Step 3: Minimal rewiring for small-world properties (only among connected members)
  rewire-existing-connections

  ;; Step 4: Calculate political similarity and tie strength for all connections
  update-connection-properties
end

to create-initial-connections-for-regular-attendees
  ;; Only create initial connections among people likely to attend regularly
  ;; Activity level > 0.8 indicates regular attendees
  let regular-attendees churchgoers with [activity-level > 0.8]

  ask regular-attendees [
    ;; Find spatial neighbors among other regular attendees
    let my-neighbors regular-attendees in-radius max-spatial-distance
    let my-neighbors-sorted sort-by [ [a b] -> distance a < distance b ] my-neighbors

    ;; Connect to closest regular attendee neighbors
    let spatial-connections-target (initial-connections / 3)  ; Fewer initial connections
    let connections-made 0

    foreach my-neighbors-sorted [ neighbor ->
      if connections-made < spatial-connections-target and neighbor != self [
        if not connection-neighbor? neighbor [
          create-connection-with neighbor
          set connections-made connections-made + 1
        ]
      ]
    ]
  ]
end

to add-homophily-connections-among-attendees
  ;; Add political homophily connections, but only among people who attend regularly
  let regular-attendees churchgoers with [activity-level > 0.8]

  ask regular-attendees [
    let my-connections-count count my-connections
    let connections-needed (initial-connections / 2) - my-connections-count  ; Reduced target

    if connections-needed > 0 [
      ;; Store my political leaning for use in sort function
      let my-political-leaning political-leaning

      ;; Find politically similar regular attendees who aren't already connected
      let potential-friends regular-attendees with [
        not connection-neighbor? myself and
        self != myself
      ]

      ;; Sort by political similarity
      let similar-people sort-by [ [a b] ->
        abs([political-leaning] of a - my-political-leaning) <
        abs([political-leaning] of b - my-political-leaning)
      ] potential-friends

      ;; Connect to most similar people
      let connections-made 0
      foreach similar-people [ friend ->
        if connections-made < connections-needed [
          create-connection-with friend
          set connections-made connections-made + 1
        ]
      ]
    ]
  ]
end

to rewire-existing-connections
  ;; Only rewire existing connections (don't create new ones between non-attendees)
  ask connections [
    if random-float 1 < (rewiring-probability / 2) [  ; Reduce rewiring probability
      ;; Pick one end of the connection
      let node1 end1
      let node2 end2

      ask node1 [
        ;; Find a random new target among regular attendees that isn't already connected
        let regular-attendees churchgoers with [activity-level > 0.8]
        let potential-targets regular-attendees with [
          not connection-neighbor? node1 and
          self != node1 and
          self != node2
        ]

        if any? potential-targets [
          let new-target one-of potential-targets
          ;; Remove old connection and create new one
          ask myself [ die ]
          create-connection-with new-target
        ]
      ]
    ]
  ]
end

to update-connection-properties
  ;; Calculate political similarity and initial tie strength for all connections
  ask connections [
    let member1 end1
    let member2 end2

    ;; Calculate political similarity (1 = identical, 0 = completely different)
    let political-diff abs([political-leaning] of member1 - [political-leaning] of member2)
    set political-similarity 1 - (political-diff / 2)  ; normalize to 0-1 range

    ;; Initial tie strength based on political similarity and spatial proximity
    let spatial-factor 1 / (1 + [distance member2] of member1)  ; closer = stronger
    set tie-strength 0.3 + 0.4 * political-similarity + 0.3 * spatial-factor

    ;; Clamp tie strength to [0, 1] range
    if tie-strength > 1 [ set tie-strength 1 ]
    if tie-strength < 0 [ set tie-strength 0 ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MAIN SIMULATION PROCEDURES - SUNDAY SIMULATION LOOP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  ;; Main simulation loop - one tick = one Sunday service

  ;; Reset interaction tracking for this Sunday
  ask churchgoers [
    set interaction-score 0
    ;; Safety check: non-attending members should have no interactions
    if not attending? [
      set interaction-score 0
    ]
  ]

  ;; Step 1: Determine who attends this Sunday
  determine-attendance

  ;; Step 2: Position attending members in church seats
  position-attendees

  ;; Step 3: Interactions between attending members
  conduct-social-interactions

  ;; Safety check: ensure non-attending members have no interaction scores
  ask churchgoers with [not attending?] [
    set interaction-score 0
  ]

  ;; Step 4: Update emotional states
  update-emotional-states

  ;; Step 5: Update tie strengths
  update-tie-strengths

  ;; Step 6: Check for members leaving the church
  process-church-departures

  ;; Update display and advance time
  update-display
  tick
end

to determine-attendance
  ;; Each member decides whether to attend based on their activity level
  ask churchgoers with [active-member?] [  ; Only active members can attend
    ;; Activity level represents probability of attending
    ;; Higher emotional state also increases likelihood of attendance
    let attendance-probability activity-level

    ;; Boost attendance probability based on emotional state
    ;; Positive emotional state increases attendance, negative decreases it
    let emotional-boost (emotional-state - base-emotional-state) * 0.2
    set attendance-probability attendance-probability + emotional-boost

    ;; Clamp probability to [0, 1] range
    if attendance-probability > 1 [ set attendance-probability 1 ]
    if attendance-probability < 0 [ set attendance-probability 0 ]

    ;; Make attendance decision
    set attending? (random-float 1 < attendance-probability)

    ;; Update weeks since attendance counter
    ifelse attending? [
      set weeks-since-attendance 0
    ] [
      set weeks-since-attendance weeks-since-attendance + 1
    ]
  ]

  ;; Inactive members never attend
  ask churchgoers with [not active-member?] [
    set attending? false
  ]
end

to position-attendees
  ;; Move attending members to their church seats, non-attendees become invisible
  ask churchgoers [
    ifelse attending? [
      ;; Attending members go to their assigned seats
      setxy home-x home-y
      set hidden? false
      set size 0.8
    ] [
      ;; Non-attending members become hidden
      set hidden? true
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SOCIAL INTERACTION PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to conduct-social-interactions
  ;; Each attending member greets a random number of others (Normal distribution, μ = 5)
  ask churchgoers with [attending?] [
    ;; Determine how many people this member will greet today
    let num-interactions round (random-normal 5 1.5)  ; μ = 5, σ = 1.5
    if num-interactions < 0 [ set num-interactions 0 ]
    if num-interactions > 10 [ set num-interactions 10 ]  ; reasonable upper limit

    ;; Conduct interactions with selected people
    if num-interactions > 0 [
      let interaction-partners select-interaction-partners num-interactions
      interact-with-partners interaction-partners
    ]
  ]
end

to-report select-interaction-partners [num-interactions]
  ;; Select people to interact with, biased toward spatial neighbors and strong ties
  let potential-partners churchgoers with [attending? and self != myself]

  if not any? potential-partners [ report turtle-set nobody ]

  let selected-partners turtle-set nobody
  let remaining-interactions num-interactions

  ;; First priority: existing network connections who are attending
  ;; Prioritize stronger connections
  let my-strong-connections my-connections with [tie-strength > 0.5]
  let strong-connected-attendees (turtle-set [other-end] of my-strong-connections) with [
    attending? and member? self potential-partners
  ]

  if any? strong-connected-attendees and remaining-interactions > 0 [
    let num-strong min (list remaining-interactions count strong-connected-attendees)
    let selected-strong n-of num-strong strong-connected-attendees
    set selected-partners (turtle-set selected-partners selected-strong)
    set remaining-interactions remaining-interactions - num-strong
  ]

  ;; Then weaker connections if still need more
  if remaining-interactions > 0 [
    let weak-connected-attendees potential-partners with [
      connection-neighbor? myself and
      not member? self selected-partners and
      attending?
    ]
    if any? weak-connected-attendees [
      let num-weak min (list remaining-interactions count weak-connected-attendees)
      let selected-weak n-of num-weak weak-connected-attendees
      set selected-partners (turtle-set selected-partners selected-weak)
      set remaining-interactions remaining-interactions - num-weak
    ]
  ]

  ;; Second priority: spatial neighbors (people sitting nearby)
  if remaining-interactions > 0 [
    let spatial-neighbors potential-partners in-radius 4 with [not member? self selected-partners]
    if any? spatial-neighbors [
      let num-spatial min (list remaining-interactions count spatial-neighbors)
      let selected-spatial n-of num-spatial spatial-neighbors
      set selected-partners (turtle-set selected-partners selected-spatial)
      set remaining-interactions remaining-interactions - num-spatial
    ]
  ]

  ;; Third priority: random others if still need more interactions
  if remaining-interactions > 0 [
    let random-others potential-partners with [not member? self selected-partners]
    if any? random-others [
      let num-random min (list remaining-interactions count random-others)
      let selected-random n-of num-random random-others
      set selected-partners (turtle-set selected-partners selected-random)
    ]
  ]

  report selected-partners
end

to interact-with-partners [partners]
  ;; Conduct individual interactions with each selected partner
  ask partners [
    interact-with myself
  ]
end

to interact-with [other-member]
  ;; Conduct a single interaction between this member and another
  ;; SAFETY CHECK: Both members must be attending
  if not attending? or not [attending?] of other-member [
    ;; This should never happen due to partner selection logic, but safety first
    stop
  ]

  let my-political-leaning [political-leaning] of self
  let other-political-leaning [political-leaning] of other-member

  ;; Calculate political similarity for this interaction
  let political-difference abs(my-political-leaning - other-political-leaning)
  let interaction-similarity 1 - (political-difference / 2)  ; normalize to 0-1

  ;; Calculate interaction quality based on similarity and tolerance
  let my-tolerance [threshold-tolerance] of self
  let other-tolerance [threshold-tolerance] of other-member
  let avg-tolerance (my-tolerance + other-tolerance) / 2

  ;; Interaction quality depends on similarity and mutual tolerance
  let interaction-quality interaction-similarity * (0.5 + 0.5 * avg-tolerance)

  ;; Store interaction results for emotional state updates
  ;; Take the BEST interaction score (or average if you prefer)
  ;; This way multiple interactions accumulate positively
  if interaction-quality > interaction-score [
    set interaction-score interaction-quality
  ]
  ask other-member [
    if interaction-quality > interaction-score [
      set interaction-score interaction-quality
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; EMOTIONAL STATE UPDATE PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-emotional-states
  ;; Update emotional states based on the core model equation:
  ;; emotional-state ← base + α × (connection-score) − β × (dissimilarity-penalty)

  ask churchgoers [
    ifelse attending? [
      ;; For attending members: update based on actual interactions
      let connection-score calculate-connection-score
      let dissimilarity-penalty calculate-dissimilarity-penalty

      ;; Apply the core equation
      let new-emotional-state base-emotional-state + alpha * connection-score - beta * dissimilarity-penalty

      ;; Clamp to [-1, 1] range
      if new-emotional-state > 1 [ set new-emotional-state 1 ]
      if new-emotional-state < -1 [ set new-emotional-state -1 ]

      set emotional-state new-emotional-state
    ] [
      ;; For non-attending members: slight decay toward base state
      let decay-rate 0.05  ; Small decay when not attending
      set emotional-state emotional-state * (1 - decay-rate) + base-emotional-state * decay-rate
    ]
  ]
end

to-report calculate-connection-score
  ;; Calculate connection score based on interactions with network connections
  ;; Weight interactions by tie strength - stronger connections matter more

  let my-connections-attending (turtle-set [other-end] of my-connections) with [attending?]

  if not any? my-connections-attending [
    ;; If no connected friends attended, use general interaction score
    report interaction-score
  ]

  ;; Calculate weighted average of interactions based on tie strength
  let weighted-interaction-sum 0
  let total-weight 0

  ask my-connections-attending [
    ;; Check if we actually interacted with this connected person
    if interaction-score > 0 [
      ;; Get the tie strength for this connection
      let connection-strength 0
      ask myself [
        ask connection-with myself [
          set connection-strength tie-strength
        ]
      ]

      ;; Weight the interaction by tie strength
      set weighted-interaction-sum weighted-interaction-sum + (interaction-score * connection-strength)
      set total-weight total-weight + connection-strength
    ]
  ]

  ;; Calculate weighted average
  let connected-score 0
  if total-weight > 0 [
    set connected-score weighted-interaction-sum / total-weight
  ]

  ;; Combine connected friend interactions with general interactions
  ;; Give more weight to connected interactions if they exist
  let final-score 0.8 * connected-score + 0.2 * interaction-score

  report final-score
end

to-report calculate-dissimilarity-penalty
  ;; Calculate penalty based on interactions with politically dissimilar people
  ;; Higher penalties when forced to interact with very different viewpoints

  let penalty 0
  let interactions-with-dissimilar 0

  ;; Check interactions with all attending members
  let attendees churchgoers with [attending? and self != myself]

  ask attendees [
    ;; Only count if we actually interacted (interaction-score > 0)
    if interaction-score > 0 [
      let political-difference abs([political-leaning] of myself - political-leaning)

      ;; Only penalize if political difference is substantial (> 0.5)
      if political-difference > 0.5 [
        ;; Penalty is stronger for larger differences and lower tolerance
        let difference-factor political-difference - 0.5  ; Scale from 0 to 1.5
        let tolerance-factor 1 - [threshold-tolerance] of myself  ; Lower tolerance = higher penalty
        let interaction-penalty difference-factor * tolerance-factor

        set penalty penalty + interaction-penalty
        set interactions-with-dissimilar interactions-with-dissimilar + 1
      ]
    ]
  ]

  ;; Average penalty across dissimilar interactions
  if interactions-with-dissimilar > 0 [
    set penalty penalty / interactions-with-dissimilar
  ]

  report penalty
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DYNAMIC NETWORK EVOLUTION PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-tie-strengths
  ;; Update tie strengths based on this Sunday's interactions and attendance patterns

  ;; First, update existing connections based on interactions
  update-existing-connections

  ;; Second, potentially create new connections from positive interactions
  create-new-connections

  ;; Third, potentially remove weak connections
  remove-weak-connections

  ;; Finally, update activity levels based on emotional states
  update-activity-levels
end

to update-existing-connections
  ;; Update tie strength for existing connections based on interactions
  ask connections [
    let member1 end1
    let member2 end2
    let both-attended ([attending?] of member1 and [attending?] of member2)

    ifelse both-attended [
      ;; Both attended: check if they actually interacted
      let member1-score [interaction-score] of member1
      let member2-score [interaction-score] of member2

      ;; If both have positive interaction scores, they likely interacted
      if member1-score > 0 and member2-score > 0 [
        ;; Strengthen tie based on interaction quality
        let interaction-quality (member1-score + member2-score) / 2
        let strength-change 0.1 * (interaction-quality - 0.5)  ; Change based on quality
        set tie-strength tie-strength + strength-change
      ]
    ] [
      ;; One or both didn't attend: slight weakening due to missed interaction
      let absence-penalty 0.02
      set tie-strength tie-strength - absence-penalty
    ]

    ;; Clamp tie strength to [0, 1] range
    if tie-strength > 1 [ set tie-strength 1 ]
    if tie-strength < 0 [ set tie-strength 0 ]
  ]
end

to create-new-connections
  ;; Create new connections between people who had very positive interactions
  ;; AND have high political homophily (similar political views)

  ask churchgoers with [attending?] [
    ;; Store my political leaning for similarity calculations
    let my-political-leaning political-leaning

    ;; Look for other attendees we had positive interactions with but aren't connected to
    let potential-new-friends churchgoers with [
      attending? and
      self != myself and
      not connection-neighbor? myself and
      interaction-score > 0.8  ; High-quality interaction threshold
    ]

    ;; Filter for high political homophily (political similarity > 0.7)
    let politically-similar-friends potential-new-friends with [
      (1 - (abs([political-leaning] of self - [political-leaning] of myself) / 2)) > 0.7  ; High homophily threshold
    ]

    ;; Create new connections with probability based on both interaction quality and political similarity
    ask politically-similar-friends [
      ;; Calculate political similarity for connection probability
      let political-diff abs([political-leaning] of self - [political-leaning] of myself)
      let local-political-similarity 1 - (political-diff / 2)

      ;; Connection probability depends on both interaction quality and political similarity
      let interaction-factor interaction-score  ; 0.8 to 1.0
      let similarity-factor local-political-similarity  ; 0.7 to 1.0
      let connection-probability (interaction-factor * similarity-factor) * 0.15  ; 15% max chance

      if random-float 1 < connection-probability [
        ask myself [
          create-connection-with myself
          ;; Set initial tie strength based on both factors
          ask connection-with myself [
            let avg-quality ([interaction-score] of myself + [interaction-score] of other-end) / 2
            let calculated-similarity 1 - (abs([political-leaning] of myself - [political-leaning] of other-end) / 2)
            set tie-strength avg-quality * calculated-similarity * 0.8  ; Start strong but not maximum
            set political-similarity calculated-similarity  ; Store the calculated similarity
          ]
        ]
      ]
    ]
  ]
end

to remove-weak-connections
  ;; Remove connections that have become very weak over time
  ask connections with [tie-strength < 0.1] [
    ;; Small probability of connection dissolution for very weak ties
    if random-float 1 < 0.05 [  ; 5% chance per Sunday for very weak connections
      die
    ]
  ]
end

to update-activity-levels
  ;; Update activity levels based on emotional states
  ;; People with consistently low emotional states become less active

  ask churchgoers with [active-member?] [
    let emotional-influence (emotional-state - base-emotional-state) * 0.02
    set activity-level activity-level + emotional-influence

    ;; Clamp activity level to [0, 1] range
    if activity-level > 1 [ set activity-level 1 ]
    if activity-level < 0.1 [ set activity-level 0.1 ]  ; Minimum activity level
  ]
end

to process-church-departures
  ;; Handle members leaving the church permanently
  ask churchgoers with [active-member?] [
    let departure-probability 0

    ;; Probability of leaving increases with:
    ;; 1. Low emotional state
    ;; 2. Extended non-attendance
    ;; 3. Very low activity level

    ;; Emotional state factor (higher chance if emotional state < 0.2)
    if emotional-state < 0.2 [
      set departure-probability departure-probability + (0.2 - emotional-state) * 0.1
    ]

    ;; Non-attendance factor (higher chance after 8+ weeks)
    if weeks-since-attendance > 8 [
      set departure-probability departure-probability + (weeks-since-attendance - 8) * 0.02
    ]

    ;; Activity level factor (higher chance if activity < 0.3)
    if activity-level < 0.3 [
      set departure-probability departure-probability + (0.3 - activity-level) * 0.05
    ]

    ;; Cap departure probability at reasonable level
    if departure-probability > 0.15 [ set departure-probability 0.15 ]

    ;; Make departure decision
    if random-float 1 < departure-probability [
      leave-church
    ]
  ]
end

to leave-church
  ;; Permanently leave the church community
  set active-member? false
  set attending? false
  set activity-level 0

  ;; Sever all social connections (they leave the community)
  ask my-connections [ die ]

  ;; Visual indicator: make them gray and smaller
  set color gray
  set size 0.5
  set hidden? true  ; They disappear from view
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; REPORTERS AND UTILITY FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report average-political-leaning
  report mean [political-leaning] of churchgoers
end

to-report political-polarization
  ;; Measure of how spread out political opinions are
  report standard-deviation [political-leaning] of churchgoers
end

to-report average-emotional-state
  report mean [emotional-state] of churchgoers
end

to-report church-capacity
  report num-seats
end

to-report empty-seats
  report num-seats - count churchgoers
end

to-report network-density
  ;; Calculate network density (actual connections / possible connections)
  let total-possible-connections (count churchgoers * (count churchgoers - 1)) / 2
  if total-possible-connections > 0 [
    report count connections / total-possible-connections
  ]
  report 0
end

to-report weighted-network-density
  ;; Calculate network density weighted by tie strength
  ;; This gives a more realistic measure of network connectivity
  let total-possible-connections (count churchgoers * (count churchgoers - 1)) / 2
  if total-possible-connections > 0 and any? connections [
    let total-tie-strength sum [tie-strength] of connections
    report total-tie-strength / total-possible-connections
  ]
  report 0
end

to-report effective-network-density
  ;; Calculate network density considering only strong ties (strength > 0.5)
  let total-possible-connections (count churchgoers * (count churchgoers - 1)) / 2
  let strong-connections connections with [tie-strength > 0.5]
  if total-possible-connections > 0 [
    report count strong-connections / total-possible-connections
  ]
  report 0
end

to-report average-tie-strength
  if any? connections [
    report mean [tie-strength] of connections
  ]
  report 0
end

to-report average-clustering-coefficient
  ;; Measure of local clustering (how connected are your neighbors to each other)
  ;; Standard binary clustering coefficient
  let total-clustering 0
  let valid-nodes 0

  ask churchgoers [
    let my-neighbors (turtle-set [other-end] of my-connections)
    let neighbor-count count my-neighbors

    if neighbor-count >= 2 [
      ;; Count connections between my neighbors
      let neighbor-connections 0
      ask my-neighbors [
        let other-neighbors (turtle-set [other-end] of my-connections)
        set neighbor-connections neighbor-connections + count (other-neighbors with [member? self my-neighbors])
      ]

      ;; Clustering coefficient for this node
      let possible-neighbor-connections neighbor-count * (neighbor-count - 1) / 2
      let clustering-coeff neighbor-connections / (2 * possible-neighbor-connections)
      set total-clustering total-clustering + clustering-coeff
      set valid-nodes valid-nodes + 1
    ]
  ]

  if valid-nodes > 0 [
    report total-clustering / valid-nodes
  ]
  report 0
end

to-report weighted-clustering-coefficient
  ;; Clustering coefficient that considers tie strength
  let total-clustering 0
  let valid-nodes 0

  ask churchgoers [
    ;; Only consider strong connections (tie-strength > 0.5) for clustering
    let my-strong-connections my-connections with [tie-strength > 0.5]
    let my-neighbors (turtle-set [other-end] of my-strong-connections)
    let neighbor-count count my-neighbors

    if neighbor-count >= 2 [
      ;; Count strong connections between my neighbors
      let neighbor-connections 0
      ask my-neighbors [
        let other-strong-connections my-connections with [tie-strength > 0.5]
        let other-neighbors (turtle-set [other-end] of other-strong-connections)
        set neighbor-connections neighbor-connections + count (other-neighbors with [member? self my-neighbors])
      ]

      ;; Clustering coefficient for this node
      let possible-neighbor-connections neighbor-count * (neighbor-count - 1) / 2
      if possible-neighbor-connections > 0 [
        let clustering-coeff neighbor-connections / (2 * possible-neighbor-connections)
        set total-clustering total-clustering + clustering-coeff
        set valid-nodes valid-nodes + 1
      ]
    ]
  ]

  if valid-nodes > 0 [
    report total-clustering / valid-nodes
  ]
  report 0
end

to-report attendance-rate
  report count churchgoers with [attending?] / count churchgoers
end

to-report current-attendees
  ;; Count of people currently attending this Sunday
  report count churchgoers with [attending?]
end

to-report average-activity-level
  ;; Average activity level across all members
  report mean [activity-level] of churchgoers
end

to-report emotional-state-distribution
  ;; Report distribution statistics for emotional states
  let states [emotional-state] of churchgoers
  report (list (min states) (mean states) (max states) (standard-deviation states))
end

to-report average-interaction-score
  ;; Average interaction score for attending members this Sunday
  let attending-members churchgoers with [attending?]
  if any? attending-members [
    report mean [interaction-score] of attending-members
  ]
  report 0
end

to-report emotional-state-change-rate
  ;; Measure how much emotional states are changing
  ;; (Would need to track previous states for full implementation)
  let states [emotional-state] of churchgoers
  report standard-deviation states
end

to-report network-fragmentation
  ;; Measure how fragmented the network has become
  ;; Higher values indicate more isolated groups
  let weak-connections connections with [tie-strength < 0.3]
  let total-connections count connections
  if total-connections > 0 [
    report count weak-connections / total-connections
  ]
  report 0
end

to-report strong-tie-ratio
  ;; Ratio of strong ties (strength > 0.7) to total connections
  let strong-connections connections with [tie-strength > 0.7]
  let total-connections count connections
  if total-connections > 0 [
    report count strong-connections / total-connections
  ]
  report 0
end

to-report homophily-index
  ;; Measure how politically similar connected people are
  ;; Range 0-1, higher values indicate more homophily
  if any? connections [
    report mean [political-similarity] of connections
  ]
  report 0
end

to-report attendance-polarization
  ;; Measure if certain political groups are attending less
  let conservative-attendance mean [activity-level] of churchgoers with [political-leaning > 0.3]
  let progressive-attendance mean [activity-level] of churchgoers with [political-leaning < -0.3]
  report abs(conservative-attendance - progressive-attendance)
end

to-report regular-attendee-connections
  ;; Report average connections among regular attendees (activity > 0.8)
  let regular-attendees churchgoers with [activity-level > 0.8]
  if any? regular-attendees [
    report mean [count my-connections] of regular-attendees
  ]
  report 0
end

to-report irregular-attendee-connections
  ;; Report average connections among irregular attendees (activity <= 0.8)
  let irregular-attendees churchgoers with [activity-level <= 0.8]
  if any? irregular-attendees [
    report mean [count my-connections] of irregular-attendees
  ]
  report 0
end

to-report cross-activity-connections
  ;; Report connections between regular and irregular attendees
  let cross-connections 0
  ask connections [
    let member1 end1
    let member2 end2
    let member1-regular ([activity-level] of member1 > 0.8)
    let member2-regular ([activity-level] of member2 > 0.8)

    ;; Count if one is regular and other is irregular
    if member1-regular != member2-regular [
      set cross-connections cross-connections + 1
    ]
  ]
  report cross-connections
end

to-report new-connection-threshold
  ;; Report the minimum political similarity for new connections (0.7)
  report 0.7
end

to-report highly-homophilic-connections
  ;; Report count of connections with very high political similarity (> 0.8)
  let high-homophily-connections connections with [political-similarity > 0.8]
  report count high-homophily-connections
end

to-report average-new-connection-strength
  ;; Report average tie strength of strong connections (likely newer ones)
  let strong-connections connections with [tie-strength > 0.7]
  if any? strong-connections [
    report mean [tie-strength] of strong-connections
  ]
  report 0
end

to-report active-members
  ;; Count of members still active in the church
  report count churchgoers with [active-member?]
end

to-report departed-members
  ;; Count of members who have left the church
  report count churchgoers with [not active-member?]
end

to-report departure-rate
  ;; Percentage of original members who have left
  report (count churchgoers with [not active-member?]) / count churchgoers
end

to-report average-weeks-absent
  ;; Average weeks since attendance for active members
  let active-member-list churchgoers with [active-member?]
  if any? active-member-list [
    report mean [weeks-since-attendance] of active-member-list
  ]
  report 0
end

to-report at-risk-members
  ;; Count of active members at high risk of leaving (low emotional state + high absence)
  report count churchgoers with [
    active-member? and
    emotional-state < 0.3 and
    weeks-since-attendance > 4
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PLOTTING AND VISUALIZATION PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to plot-degree-distribution
  ;; Plot histogram of degree distribution (number of connections per churchgoer)
  clear-plot
  let degree-list [count my-connections] of churchgoers

  ;; Set histogram parameters
  set-plot-x-range 0 (max degree-list + 1)
  set-plot-y-range 0 (count churchgoers / 5)  ; Adjust range based on expected distribution

  ;; Create histogram
  histogram degree-list
end

to-report get-degree-list
  ;; Helper reporter to get list of degrees for external analysis
  report [count my-connections] of churchgoers
end

to-report average-degree
  ;; Report average number of connections per churchgoer
  if any? churchgoers [
    report mean [count my-connections] of churchgoers
  ]
  report 0
end

to-report max-degree
  ;; Report maximum number of connections
  if any? churchgoers [
    report max [count my-connections] of churchgoers
  ]
  report 0
end

to-report min-degree
  ;; Report minimum number of connections
  if any? churchgoers [
    report min [count my-connections] of churchgoers
  ]
  report 0
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
687
723
-1
-1
26.1
1
10
1
1
1
0
0
0
1
0
17
0
26
0
0
1
ticks
30.0

BUTTON
20
20
95
65
Setup
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
110
20
175
65
Go
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

BUTTON
20
80
95
125
Go Forever
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

SWITCH
20
140
170
173
show-links?
show-links?
1
1
-1000

SLIDER
20
185
192
218
num-members
num-members
50
600
400.0
50
1
NIL
HORIZONTAL

SLIDER
20
230
192
263
alpha
alpha
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
20
275
192
308
beta
beta
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
20
320
192
353
base-emotional-state
base-emotional-state
0
1
0.5
0.1
1
NIL
HORIZONTAL

MONITOR
710
20
850
65
Current Attendees
current-attendees
0
1
11

MONITOR
710
80
850
125
Active Members
active-members
0
1
11

MONITOR
710
140
850
185
Departed Members
departed-members
0
1
11

MONITOR
710
200
850
245
Attendance Rate
precision (attendance-rate * 100) 1
3
1
11

MONITOR
860
20
1000
65
Avg Political Leaning
precision average-political-leaning 3
3
1
11

MONITOR
860
80
1000
125
Political Polarization
precision political-polarization 3
3
1
11

MONITOR
860
140
1000
185
Avg Emotional State
precision average-emotional-state 3
3
1
11

MONITOR
860
200
1000
245
Network Density
precision network-density 3
3
1
11

MONITOR
1010
20
1150
65
Homophily Index
precision homophily-index 3
3
1
11

MONITOR
1010
80
1150
125
Strong Tie Ratio
precision strong-tie-ratio 3
3
1
11

MONITOR
1010
140
1150
185
At Risk Members
at-risk-members
0
1
11

MONITOR
1010
200
1150
245
Avg Weeks Absent
precision average-weeks-absent 1
3
1
11

PLOT
710
260
1150
400
Political Leaning Distribution
Political Leaning
Count
-1.0
1.0
0.0
50.0
true
false
"" ""
PENS
"default" 0.1 1 -16777216 true "" "histogram [political-leaning] of churchgoers"

PLOT
710
410
1150
550
Emotional State Over Time
Time (Sundays)
Average Emotional State
0.0
50.0
-1.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot average-emotional-state"

PLOT
710
560
1150
700
Network Statistics
Time (Sundays)
Value
0.0
50.0
0.0
1.0
true
true
"" ""
PENS
"Network Density" 1.0 0 -16777216 true "" "plot network-density"
"Homophily Index" 1.0 0 -2674135 true "" "plot homophily-index"
"Strong Tie Ratio" 1.0 0 -13345367 true "" "plot strong-tie-ratio"

PLOT
1169
415
1549
555
Degree Distribution
Number of Connections
Number of Churchgoers
0.0
10.0
0.0
50.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "plot-degree-distribution"

PLOT
1169
565
1549
705
Attendance Patterns
Time (Sundays)
Percentage
0.0
50.0
0.0
100.0
true
true
"" ""
PENS
"Attendance Rate" 1.0 0 -16777216 true "" "plot (attendance-rate * 100)"
"Active Members" 1.0 0 -13345367 true "" "plot ((active-members / count churchgoers) * 100)"

TEXTBOX
17
366
189
486
Model Parameters:\n- Alpha: Weight for connection score\n- Beta: Weight for dissimilarity penalty\n- Base Emotional State: Baseline mood
11
0.0
1

TEXTBOX
1170
20
1440
136
Church Polarization Model\n\nThis model simulates political polarization\nin a church community over time.
14
0.0
1

TEXTBOX
1171
117
1441
192
Instructions:\n1. Adjust sliders for desired parameters\n2. Click Setup to initialize the model\n3. Click Go to run one Sunday\n4. Click Go Forever for continuous simulation
11
0.0
1

TEXTBOX
1178
196
1448
298
Visualization:\n- Red agents = Conservative\n- Blue agents = Progressive\n- Purple agents = Moderate\n- Links show social connections
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

This model simulates political polarization within a church community. It explores how political differences among church members can affect their social interactions, emotional well-being, and ultimately their decision to remain active in the church or leave the community.

The model represents a church with 400 seats where members attend Sunday services, interact with each other, and form or weaken social connections based on their political compatibility and personal tolerance levels.

## HOW IT WORKS

### Agents (Church Members)
Each church member has several key attributes:
- **Political Leaning**: Ranges from -1 (progressive) to +1 (conservative)
- **Threshold Tolerance**: How much political difference they can tolerate (0-1)
- **Activity Level**: Probability of attending church services (0-1)
- **Emotional State**: Current well-being level (-1 to +1)
- **Media Exposure**: Influences political views (-1 to +1)

### Social Network
Members form connections with each other based on:
- **Spatial proximity** in church seating
- **Political homophily** (similarity in political views)
- **Regular attendance patterns**

### Weekly Cycle
Each tick represents one Sunday service:

1. **Attendance Decision**: Members decide whether to attend based on their activity level and emotional state
2. **Social Interactions**: Attending members interact with nearby members and existing connections
3. **Emotional Updates**: Members update their emotional state based on interaction quality
4. **Network Evolution**: Social connections strengthen or weaken based on interactions
5. **Departure Process**: Members with consistently low emotional states may leave the church

### Core Equation
Emotional state is updated using:
**emotional-state = base + α × (connection-score) - β × (dissimilarity-penalty)**

Where:
- α (alpha) weights positive interactions with connected friends
- β (beta) weights negative effects of interacting with politically dissimilar people

## HOW TO USE IT

### Setup
1. Adjust the **num-members** slider (50-600) to set church size
2. Set **alpha** (0-1) to control how much positive connections matter
3. Set **beta** (0-1) to control how much political dissimilarity hurts
4. Set **base-emotional-state** (0-1) as the baseline mood
5. Toggle **show-links?** to visualize social connections
6. Click **Setup** to initialize the model

### Running the Model
- Click **Go** to advance one Sunday (one tick)
- Click **Go Forever** to run continuously
- Watch the monitors and plots to track model dynamics

### Key Metrics to Watch
- **Attendance Rate**: Percentage of members attending each Sunday
- **Political Polarization**: How spread out political views are (standard deviation)
- **Network Density**: How connected the social network is
- **Homophily Index**: How politically similar connected people are
- **Departed Members**: How many have left the church permanently

## THINGS TO NOTICE

1. **Political Sorting**: Over time, people tend to form stronger connections with politically similar others
2. **Attendance Patterns**: Members with extreme political views or low tolerance may attend less frequently
3. **Emotional Decline**: Some members experience declining emotional states due to difficult interactions
4. **Network Fragmentation**: The social network may split into separate clusters
5. **Church Departures**: Members with consistently negative experiences may leave permanently

## THINGS TO TRY

1. **High Alpha, Low Beta**: Strong positive effects from connections, weak negative effects from dissimilarity
2. **Low Alpha, High Beta**: Weak positive effects, strong negative effects from political differences
3. **Different Church Sizes**: Compare small (100 members) vs large (500 members) churches
4. **Extreme vs Moderate Initial Conditions**: Start with politically diverse vs politically homogeneous populations

### Interesting Experiments
- What happens when alpha = beta? When alpha >> beta? When beta >> alpha?
- How does church size affect polarization dynamics?
- Can a highly tolerant population resist polarization?
- What combination of parameters leads to the most church departures?

## EXTENDING THE MODEL

Possible extensions include:
- **Leadership Effects**: Add church leaders with special influence
- **External Events**: Periodic political events that affect all members
- **Generational Differences**: Different age cohorts with different political tendencies
- **Multiple Churches**: Competition between different congregations
- **Conversion Dynamics**: Members changing their political views over time

## NETLOGO FEATURES

This model uses several advanced NetLogo features:
- **Breeds**: Separate churchgoer and connection breeds
- **Link Breeds**: Undirected connections with custom properties
- **Network Generation**: Spatial and homophily-based network creation
- **Complex Scheduling**: Multi-step weekly cycles with interaction tracking
- **Dynamic Visualization**: Real-time updates of agent colors and network display

## RELATED MODELS

This model relates to:
- Social network models in the NetLogo Models Library
- Opinion dynamics and consensus models
- Segregation models (like Schelling's model)
- Social influence and homophily models

## CREDITS AND REFERENCES

This model implements concepts from:
- Political polarization research in religious communities
- Social network theory and homophily
- Agent-based modeling of social dynamics
- Research on church attendance and community participation

The model structure is inspired by classic ABM approaches but tailored specifically to the dynamics of political polarization in religious communities.
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
Circle -7500403 true true 8 8 285
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
Polygon -16777216 true false 151 99 225 223 75 223

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
Circle -7500403 true true 24 174 42
Circle -7500403 true true 144 174 42
Circle -7500403 true true 234 174 42

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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
0
@#$#@#$#@
