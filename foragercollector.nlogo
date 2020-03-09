; Copyright (c) 2018-20 Kaarel Sikk, C²DH, University of Luxembourg
; Licensed under the Creative Commons
; Attribution-NonCommercial-ShareAlike 3.0 License
; See Info tab for full copyright and license information
;
; Main model file

__includes[
  ; all operations on setting landscape
  "landscape.nls"
  ; agent behaviours as bases
  "bases.nls"
  ; resource harvesting and growth
  "resources.nls"
  ; measurements and reporting
  "reporting.nls"
]

; The type of agent in the system is base
breed [bases base]

globals [
  ; Energy / resource related configuration

  ; How much energy a human requires per day
  ; For estimates we can refer to empirical data from Kelly (2013, p 99)
  ; 14000 KCal/family day
  ; In stylized model the unit is energy per person per day, so default = 1
  ; For a discussion on how much energy person requires for a week see:
  ; Hamilton et al 2016 [https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5094510/]
  energy-per-person

  ; Minimum utility value, base has to move, if it's so low already
  ;min-base-utility

  ; percentage of energy rate of any patch that restore during a tick
  regrowth-rate

  ; speed of movement in km/h to and back to foraging spot
  forage-speed

  ; speed of movement while on residential move
  residential-move-speed

  ; how long is one tick, by default 7 days - a week
  days-per-tick

  ; rate (times energy on the spot) of how fast a harvested patch is being depleted in a tick
  ; must be recalculated if changing days-per-tick
  ; depletion-rate

  ; when planning residential move, how long shall we think ahead?
  move-time-anticip

  ; As resource regrowth takes lot of computing power we do it after nr of ticks
  regrow-after-ticks

  ; Variables related to seasonality and different resources, RESERVED VARIABLES, NOT USED CURRENTLY
  num-resources ; diversity of resources
  growing-season ; length of resource availability in weeks
  tp-smoothness ; smoothness of placement of resources

  min-usable-utility ;if utility is below this threshold the  place is scrapped

  ; A multiplier defining the costs of residential moves per km per person
  ; for logistical mobility that is going to be weighted against utility
  ;distance-multiplier

  ; a cost of residential move for weighting against utility
  ; while weighting will be multiplied by population
  ;move-start-cost

  ; Calculated helper variables
  mean-energy-rate ; variable is calculated by input options energy rate per km and km per patch
  max-energy-rate ; calculated highest energy rate for visualization purposes
  max-utility-rate ; calculated highest utility rate for visualization purposes

  ; Mobility
  ; Maximum logistic move / logistic range of residential base
  ; max-logistic-move
  ; Maximum residential move, how far can a new base camp be?
  ; max-residential-move

  ; Variables collected for reporting

  current-week ; 1-52
  current-year ; X
  nni ; nearest neighbor index - measure of clustering
  ; initial Moran's I value of utility distribution
  I-util-init
  ; initial Moran's I value of resource distribution
  I-resource-init
  ; Moran's I value of utility distribution
  I-util
  ; Moran's I value of resource distribution
  I-resource
  ; residential moves (while current tick)
  residential-moves
  ; residential move length (sum  of length during current tick)
  residential-move-length
  ; switch debug mode on
  debug
  ; store random seed
  run-seed
  ; reporting for Behviourspace
  report-mean-energy
  report-mean-movelen
  report-mean-exptime
  report-mean-logmobturn
  report-mean-moves
  report-mean-fradius
  report-std-energy
  report-std-movelen
  report-std-exptime
  report-std-logmobturn
  report-std-moves
  report-std-fradius

  std-energy
]

to setup-vars
  clear-all
  ; Setup random seed
  ifelse the-random-seed > 0 [
    random-seed the-random-seed
    set run-seed the-random-seed
  ]
  ; set seed
  [
    set run-seed new-seed
    random-seed run-seed
  ]

  ; calculate it to use patch instead of km
  set mean-energy-rate mean-energy-rate-km * (patch-size-km ^ 2)

  set std-energy mean-energy-rate * std-energy-rate

  ; movement utility penalty
  ; set distance-multiplier distance-multiplier * patch-size-km

  ; start how much hours it takes (will be multiplied by population when evaluating)
  ; set move-start-cost 10

  ; Real data: Binford data mean 4 sq per person with regrowth / per year
  ; for population n and map size m, required energy per patch would be
  ; n/m
  ;
  ; energy rate depletes (and recovers) though by 2/3 every TICK depending on the patch choice
  ;set depletion-rate 2 / 3

  ; mean-energy-rate-km

  ; define unit of energy, energy rate per person per DAY
  set energy-per-person 1

  ; How many days is one tick
  set days-per-tick 7

  ;Regrow X% of patch rate in a tick (currently full regrowth 50% year)
  set regrowth-rate (1 / recover-in-nyear) / (365 / days-per-tick)

  ;set min-base-utility 100
  ; Move speed to foraging location and back (km/h) - from Kelly 2015 p 97
  set forage-speed 3

  set residential-move-speed 3

  ; In evaluating the will to move - how many days we think ahead?
  set move-time-anticip 8

  set regrow-after-ticks 4

  ;this is minimum utility to survive at the pace for a tick to avoid div by zero
  set min-usable-utility 0.00000001 ;base-population * (1 / (depletion-rate + 0.00001))

  set debug 0

  ; We don't go further than 4h moving
  set max-logistic-move min list (forage-speed * 3.9) max-logistic-move


end

; Show different UI maps for different variables
to recolor-patches

  if coloring = "resources" [
    ask patches [
      ifelse energy > resource-thresh
      [set pcolor scale-color green (energy - harvested) 0 (max-energy-rate) ];resource-type * 10 + energy]
      [set pcolor gray]
    ]
  ]
  if coloring = "utility" [
    ask patches [
      set pcolor scale-color green utility 0 max-utility-rate
    ]
  ]
  if coloring = "debug-costs" [
    let max-agent-cost (max [tmp-agent-costs] of patches) + 10
    set max-agent-cost 20
    ask patches [
      set pcolor scale-color blue tmp-agent-costs 0 max-agent-cost
    ]
  ]
end


; setup model to run
to setup
  reset-ticks
  setup-vars
  setup-patches

  set max-energy-rate (max [energy] of patches) ;* patch-size-km
  set max-utility-rate max [max-utility] of patches
  setup-bases
  recolor-patches
  calc-morans-I "utility"
  calc-morans-I "resources"
  set I-util-init I-util
  set I-resource-init I-resource
  dout "Mean energy rate:"
  dout mean [energy] of patches

end

;setup model to run with uniform environment
to setup-null
  reset-ticks
  setup-vars
  setup-null-patches

  set max-energy-rate max [energy] of patches; * patch-size-km
  set max-utility-rate max [max-utility] of patches

  setup-bases
  recolor-patches
  calc-morans-I "utility"
  calc-morans-I "resources"
  set I-util-init I-util
  set I-resource-init I-resource
  dout "Mean energy rate:"

  dout mean [energy] of patches
end

; run step of a model
to go
  set residential-moves 0
  set residential-move-length 0
  ; agents move
  run-bases

  tick
  ;environment regrowth
  if ticks mod regrow-after-ticks = 0 [
    regrow-harvest
  ]
  ; measure
  slow-measurements

  calc-nni

  set report-mean-fradius 0
  set report-std-fradius 0

  let movedbases bases with [moves > 0]

  let foraged bases with [last-foraging-radius > 0]

  ;start recording after at least two bases have moved
  if (any? movedbases AND count movedbases > 2) [
    set report-mean-movelen mean [travelled / moves] of bases with [moves > 0]
    set report-std-movelen standard-deviation [travelled / moves] of bases with [moves > 0]
    set report-mean-energy mean [energy - harvested] of patches
    set report-mean-exptime mean [expected-time] of bases
    set report-mean-logmobturn mean [log-mobility-turn] of bases
    set report-mean-moves mean [moves] of bases * (365 / days-per-tick)/ ticks
    set report-std-energy standard-deviation [energy - harvested] of patches
    set report-std-exptime standard-deviation [expected-time] of bases
    set report-std-logmobturn standard-deviation [log-mobility-turn] of bases
    set report-std-moves standard-deviation [moves] of bases * (365 / days-per-tick)/ ticks
  ]

  if (any? foraged AND count foraged > 2) [
    set report-mean-fradius mean [last-foraging-radius] of bases with [last-foraging-radius > 0 ]
    set report-std-fradius standard-deviation [last-foraging-radius] of bases with [last-foraging-radius > 0 ]
  ]

end


; debug function to print debug information to output
to dout [msg]
  if debug = 1 [
   print msg
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
343
10
812
480
-1
-1
4.5644
1
10
1
1
1
0
0
0
1
-50
50
-50
50
0
0
1
ticks
30.0

BUTTON
1
196
75
229
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

CHOOSER
77
118
216
163
coloring
coloring
"utility" "resources" "debug-costs" "none"
1

BUTTON
162
196
248
229
Recolor
recolor-patches
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
1
229
74
262
Go 1T
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

SLIDER
-1
32
171
65
num-bases
num-bases
1
100
5.0
1
1
NIL
HORIZONTAL

SLIDER
171
32
342
65
smoothness
smoothness
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
170
97
342
130
resource-thresh
resource-thresh
0
25
0.5
0.1
1
NIL
HORIZONTAL

BUTTON
74
229
198
262
Go semester
repeat 13 [ go ]
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
74
196
162
229
Setup 0
setup-null
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
170
130
342
163
patch-size-km
patch-size-km
1
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
170
163
342
196
mean-energy-rate-km
mean-energy-rate-km
0.1
5
0.91
.01
1
NIL
HORIZONTAL

SLIDER
170
64
343
97
std-energy-rate
std-energy-rate
0
10
1.1
.1
1
NIL
HORIZONTAL

PLOT
812
309
1012
459
Nearest Neighbor Index
NIL
NIL
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot nni"

MONITOR
234
345
342
390
Morans I utility
I-util-init
17
1
11

MONITOR
234
300
342
345
Morans I resource
I-resource-init
17
1
11

PLOT
1012
159
1208
309
Morans I
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot I-util"
"pen-1" 1.0 0 -7500403 true "" "plot I-resource"

SLIDER
0
300
234
333
max-logistic-move
max-logistic-move
0
25
11.7
1
1
NIL
HORIZONTAL

SLIDER
0
332
234
365
max-residential-move
max-residential-move
0
50
25.0
1
1
NIL
HORIZONTAL

SLIDER
-2
163
170
196
the-random-seed
the-random-seed
0
100000
0.0
1
1
NIL
HORIZONTAL

PLOT
1208
159
1408
309
mean energy
NIL
NIL
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [energy - harvested] of patches"

BUTTON
197
229
284
262
Go year
repeat 52 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
0
364
234
397
move-start-cost
move-start-cost
0
200
10.0
.2
1
hrs
HORIZONTAL

PLOT
1012
10
1212
160
movelen
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [last-move-length] of bases"
"pen-1" 1.0 2 -7500403 true "" "ask turtles [ set-plot-pen-color (who * 10 + 5) plotxy ticks last-move-length]"
"pen-2" 1.0 0 -2674135 true "" "plot standard-deviation [last-move-length] of bases"

PLOT
812
10
1012
160
Expected move time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [expected-time] of bases"
"pen-1" 1.0 0 -5825686 true "" "plot standard-deviation [expected-time] of bases"
"pen-2" 1.0 2 -16777216 true "" "ask turtles [ set-plot-pen-color (who * 10 + 5) plotxy ticks expected-time]"

SLIDER
-2
64
170
97
base-population
base-population
0
100
20.0
1
1
NIL
HORIZONTAL

SWITCH
-1
131
89
164
random-start
random-start
0
1
-1000

PLOT
812
160
1012
310
Log mobility / moved turn
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" "ask turtles [ set-plot-pen-color (who * 10 + 5) plotxy ticks log-mobility-turn]"
"pen-1" 1.0 0 -16777216 true "" "plot mean [log-mobility-turn] of bases"
"pen-2" 1.0 0 -5825686 true "" "plot standard-deviation [log-mobility-turn] of bases"

TEXTBOX
8
7
158
25
Population config
12
0.0
1

TEXTBOX
194
9
344
27
Environment config
12
0.0
1

TEXTBOX
5
272
155
290
Mobility config
12
0.0
1

TEXTBOX
7
104
157
122
UI config
12
0.0
1

MONITOR
234
390
341
435
Moves/yr
mean [moves] of bases * (365 / days-per-tick)/ ticks
17
1
11

PLOT
1012
309
1212
459
Mover per turn
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot residential-moves"

SLIDER
-1
396
234
429
recover-in-nyear
recover-in-nyear
0
2
1.0
.1
1
NIL
HORIZONTAL

SLIDER
-1
429
234
462
depletion-rate
depletion-rate
0
1
0.66
0.01
1
NIL
HORIZONTAL

SLIDER
171
265
343
298
move-before
move-before
0
1
0.0
0.05
1
NIL
HORIZONTAL

MONITOR
1212
10
1356
55
NIL
report-mean-energy
17
1
11

MONITOR
1212
54
1355
99
NIL
report-mean-movelen
17
1
11

MONITOR
1211
398
1362
443
NIL
report-mean-exptime
17
1
11

MONITOR
1211
99
1355
144
NIL
report-mean-logmobturn
17
1
11

MONITOR
1211
308
1354
353
NIL
report-mean-moves
17
1
11

MONITOR
1211
353
1357
398
NIL
report-mean-fradius
17
1
11

@#$#@#$#@
## WHAT IS IT?

An Agent Based Model of hunter-gatherer settlement patterns generally based on Central Place Foraging (CPF) model of Kelly (2013).

The model is based a spatially explicit implementation of Kelly's CPF model. Unlike other CPF models, which simulate actions of individual foragers, the agent in current model is a hunter-gatherer camp that moves around on the landscape. The individual forager actions are thus reduced from the model for simplification.

The goal of the model is to provide a framework to explore connect decision theories to hunter-gatherer settlement pattern formation. 


The settlement patterns are formed as a results of agent choices of mobility and that of settlement location, which have essentially different causes. With the model framework it is possible to test theories of those decision processes and explore their results on settlement pattern scale. 

The framework is developed for use as a baseline model for experimenting research questions with explicit empirical case studies. Among those are testing formalised hypothesis and identifying emergent properties 

The goal of the CPF implementation is explore to the possibilities of explaining settlement choice by optimal foraging theory. 

The spatially explicit implementation of the CPF model includes several new mechanisms:

+ stochastic environment generation

+ choice model between alternative locations

+ resources harvesting and environment depletion process

+ multiple agents competing for the resources


### Possible questions

We explore can we explain relation between environmental features and rate of residential and logistic mobility by agent based settlement choice model.

Possible questions with the model are 

+ exploring mobility models

+ exploring settlement location choice models 

+ energy distribution in the environment and its effect to settlement pattern formation

+ dynamic environments, seasonality

+ movement costs and technology; site investment


The goal of the experiments by Sikk and Caruso (2019) are: 

+ test the robustness of Kelly's CPF model to initial spatial configuration of resource deistribution

+ evaluate its theoretical explanatory power of settlement pattern formation processes


## HOW IT WORKS

### On setup

1. System generates resource coverage of the whole space with max energy potential of locations. It will be determined by randomness currently

2. Generate utility space that is quantifies to access to resources 
every adjacent patchs until (max) adds existing resources value to space / divided by it's distance from potential home. (maybe should structure differently).



### Every tick

1. Restore consumed resources

2. Every agent

    2.1. Calculate utility at current place. 

    2.2. Compare current acquisition rate to the promise of the best alternative location - moving costs. If the alternative is better - move

    2.3. Harvest resources

    2.3. If moved, change your expectations for normal length of a stay - decide it to be the mean of the last two stays.


## REFERENCES


+ Kelly, R.L., 1992. Mobility/Sedentism: Concepts, Archaeological Measures, and Effects. Annual Review of Anthropology 21, 43–66. https://doi.org/10.1146/annurev.an.21.100192.000355

+ Kelly, R.L., 2013. The lifeways of hunter-gatherers: the foraging spectrum. Cambridge University Press.

+ Hamilton, M.J., Lobo, J., Rupley, E., Youn, H. and West, G.B., 2016. The ecological and evolutionary energetics of hunter‐gatherer residential mobility. Evolutionary Anthropology: Issues, News, and Reviews, 25(3), pp.124-132.

+ Venkataraman, V.V., Kraft, T.S., Dominy, N.J. and Endicott, K.M., 2017. Hunter-gatherer residential mobility and the marginal value of rainforest patches. Proceedings of the National academy of Sciences, 114(12), pp.3097-3102.


## HOW TO CITE

If you mention this model in a publication, or use  please include these citations for the model itself and for NetLogo  

+  Sikk, K. and Caruso G. 2019. Spatially explicit ABM of Central Place Foraging Theory and its explanatory power for hunter-gatherers settlement patterns formation processes. Adaptive Behaviour 2019

+  Wilensky, U. 1999. NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.  

## COPYRIGHT AND LICENSE

Copyright 2018-2020 Kaarel Sikk, C2DH, University of Luxembourg

![CC BY-NC-SA 4.0](http://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 License.  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
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
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="etest" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="104"/>
    <metric>the-random-seed</metric>
    <metric>max-logistic-move</metric>
    <metric>std-energy</metric>
    <metric>mean [energy - harvested] of patches</metric>
    <metric>residential-moves</metric>
    <metric>I-resource-init</metric>
    <metric>I-util-init</metric>
    <metric>nni</metric>
    <metric>mean [last-move-length] of bases</metric>
    <enumeratedValueSet variable="distance-multiplier">
      <value value="1.54"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="resource-thresh">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-bases">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-energy-rate-km">
      <value value="10"/>
      <value value="5"/>
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="global-population">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-residential-move">
      <value value="25"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-logistic-move" first="3" step="3" last="15"/>
    <steppedValueSet variable="std-energy" first="0" step="5" last="25"/>
    <enumeratedValueSet variable="smoothness">
      <value value="1"/>
      <value value="1"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-start-cost">
      <value value="10"/>
      <value value="5"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="coloring">
      <value value="&quot;utility&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="e1" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="104"/>
    <metric>the-random-seed</metric>
    <metric>max-logistic-move</metric>
    <metric>std-energy</metric>
    <metric>mean [energy - harvested] of patches</metric>
    <metric>residential-moves</metric>
    <metric>I-resource-init</metric>
    <metric>I-util-init</metric>
    <metric>nni</metric>
    <metric>mean [last-move-length] of bases</metric>
    <metric>mean [expected-time] of bases</metric>
    <metric>mean [log-mobility-turn] of bases</metric>
    <metric>mean [moves] of bases * (365 / days-per-tick)/ ticks</metric>
    <enumeratedValueSet variable="resource-thresh">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-bases">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="mean-energy-rate-km" first="0.5" step="0.5" last="2"/>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-population">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-residential-move">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="std-energy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="smoothness">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="move-start-cost" first="0" step="0.5" last="10"/>
    <steppedValueSet variable="depletion-rate" first="0.3" step="0.3" last="0.9"/>
    <enumeratedValueSet variable="coloring">
      <value value="&quot;utility&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="e2" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="104"/>
    <metric>run-seed</metric>
    <metric>std-energy</metric>
    <metric>mean [energy - harvested] of patches</metric>
    <metric>residential-moves</metric>
    <metric>I-resource-init</metric>
    <metric>I-util-init</metric>
    <metric>nni</metric>
    <metric>mean [last-move-length] of bases</metric>
    <metric>mean [expected-time] of bases</metric>
    <metric>mean [log-mobility-turn] of bases</metric>
    <metric>mean [moves] of bases * (365 / days-per-tick)/ ticks</metric>
    <enumeratedValueSet variable="num-bases">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-energy-rate-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-population">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-residential-move">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="std-energy">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="smoothness">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="move-start-cost" first="0" step="0.2" last="10"/>
    <enumeratedValueSet variable="depletion-rate">
      <value value="0.66"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="e3" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="104"/>
    <metric>word run-seed</metric>
    <metric>std-energy</metric>
    <metric>mean [energy - harvested] of patches</metric>
    <metric>residential-moves</metric>
    <metric>I-resource-init</metric>
    <metric>I-util-init</metric>
    <metric>nni</metric>
    <metric>mean [last-move-length] of bases</metric>
    <metric>mean [expected-time] of bases</metric>
    <metric>mean [log-mobility-turn] of bases</metric>
    <metric>mean [moves] of bases * (365 / days-per-tick)/ ticks</metric>
    <enumeratedValueSet variable="num-bases">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-energy-rate-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-population">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-residential-move">
      <value value="25"/>
    </enumeratedValueSet>
    <steppedValueSet variable="std-energy" first="0" step="2" last="10"/>
    <steppedValueSet variable="smoothness" first="0" step="5" last="25"/>
    <steppedValueSet variable="move-start-cost" first="0" step="0.5" last="10"/>
    <enumeratedValueSet variable="depletion-rate">
      <value value="0.66"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="e4" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup
reset-ticks</setup>
    <go>go</go>
    <timeLimit steps="104"/>
    <metric>word run-seed</metric>
    <metric>std-energy</metric>
    <metric>residential-moves</metric>
    <metric>I-resource-init</metric>
    <metric>I-util-init</metric>
    <metric>nni</metric>
    <metric>report-mean-energy</metric>
    <metric>report-mean-movelen</metric>
    <metric>report-mean-exptime</metric>
    <metric>report-mean-logmobturn</metric>
    <metric>report-mean-moves</metric>
    <enumeratedValueSet variable="num-bases">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-population">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="coloring">
      <value value="&quot;resources&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="the-random-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="smoothness" first="0" step="5" last="25"/>
    <steppedValueSet variable="std-energy" first="0" step="2" last="10"/>
    <enumeratedValueSet variable="resource-thresh">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-energy-rate-km">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-logistic-move">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-residential-move">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recover-in-nyear">
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="move-start-cost" first="0" step="0.5" last="10"/>
    <enumeratedValueSet variable="depletion-rate">
      <value value="0"/>
      <value value="0.33"/>
      <value value="0.66"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="force-move-after">
      <value value="0"/>
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="e5" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup
reset-ticks</setup>
    <go>go</go>
    <final>behaviorspace-run-number</final>
    <timeLimit steps="78"/>
    <metric>word run-seed</metric>
    <metric>std-energy</metric>
    <metric>mean-energy-rate-km</metric>
    <metric>residential-moves</metric>
    <metric>I-resource-init</metric>
    <metric>I-util-init</metric>
    <metric>I-util</metric>
    <metric>I-resource</metric>
    <metric>nni</metric>
    <metric>report-mean-energy</metric>
    <metric>report-mean-movelen</metric>
    <metric>report-mean-exptime</metric>
    <metric>report-mean-logmobturn</metric>
    <metric>report-mean-moves</metric>
    <metric>report-mean-fradius</metric>
    <metric>report-std-energy</metric>
    <metric>report-std-movelen</metric>
    <metric>report-std-exptime</metric>
    <metric>report-std-logmobturn</metric>
    <metric>report-std-moves</metric>
    <metric>report-std-fradius</metric>
    <enumeratedValueSet variable="num-bases">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-population">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="coloring">
      <value value="&quot;resources&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="the-random-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="smoothness">
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="12"/>
      <value value="16"/>
      <value value="25"/>
      <value value="40"/>
      <value value="60"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="std-energy">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="resource-thresh">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-energy-rate-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-logistic-move">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-residential-move">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recover-in-nyear">
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="move-start-cost" first="0" step="4" last="100"/>
    <enumeratedValueSet variable="depletion-rate">
      <value value="0.66"/>
    </enumeratedValueSet>
    <steppedValueSet variable="move-before" first="0" step="20" last="100"/>
  </experiment>
  <experiment name="e5nni" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup
reset-ticks</setup>
    <go>go</go>
    <final>print behaviorspace-run-number</final>
    <timeLimit steps="78"/>
    <metric>word run-seed</metric>
    <metric>std-energy</metric>
    <metric>mean-energy-rate-km</metric>
    <metric>residential-moves</metric>
    <metric>I-resource-init</metric>
    <metric>I-util-init</metric>
    <metric>I-util</metric>
    <metric>I-resource</metric>
    <metric>nni</metric>
    <metric>report-mean-energy</metric>
    <metric>report-mean-movelen</metric>
    <metric>report-mean-exptime</metric>
    <metric>report-mean-logmobturn</metric>
    <metric>report-mean-moves</metric>
    <metric>report-mean-fradius</metric>
    <metric>report-std-energy</metric>
    <metric>report-std-movelen</metric>
    <metric>report-std-exptime</metric>
    <metric>report-std-logmobturn</metric>
    <metric>report-std-moves</metric>
    <metric>report-std-fradius</metric>
    <enumeratedValueSet variable="num-bases">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-population">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="coloring">
      <value value="&quot;resources&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="the-random-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="std-energy">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="resource-thresh">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-energy-rate-km">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-logistic-move">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-residential-move">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recover-in-nyear">
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="move-start-cost" first="0" step="4" last="100"/>
    <enumeratedValueSet variable="depletion-rate">
      <value value="0.66"/>
    </enumeratedValueSet>
    <steppedValueSet variable="move-before" first="0" step="20" last="100"/>
    <enumeratedValueSet variable="smoothness">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="12"/>
      <value value="16"/>
      <value value="25"/>
      <value value="40"/>
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="e6" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup
reset-ticks</setup>
    <go>go</go>
    <final>print behaviorspace-run-number</final>
    <timeLimit steps="78"/>
    <metric>word run-seed</metric>
    <metric>I-resource-init</metric>
    <metric>I-util-init</metric>
    <metric>I-util</metric>
    <metric>I-resource</metric>
    <metric>nni</metric>
    <metric>report-mean-energy</metric>
    <metric>report-mean-movelen</metric>
    <metric>report-mean-exptime</metric>
    <metric>report-mean-logmobturn</metric>
    <metric>report-mean-moves</metric>
    <metric>report-mean-fradius</metric>
    <metric>report-std-energy</metric>
    <metric>report-std-movelen</metric>
    <metric>report-std-exptime</metric>
    <metric>report-std-logmobturn</metric>
    <metric>report-std-moves</metric>
    <metric>report-std-fradius</metric>
    <metric>residential-moves</metric>
    <enumeratedValueSet variable="num-bases">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-population">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="coloring">
      <value value="&quot;resources&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="the-random-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="smoothness">
      <value value="0"/>
      <value value="5"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="std-energy">
      <value value="1"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="resource-thresh">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-logistic-move">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-residential-move">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recover-in-nyear">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="depletion-rate">
      <value value="0.66"/>
    </enumeratedValueSet>
    <steppedValueSet variable="mean-energy-rate-km" first="0.6" step="0.2" last="5"/>
    <steppedValueSet variable="move-start-cost" first="0" step="4" last="100"/>
  </experiment>
  <experiment name="e7" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup
reset-ticks</setup>
    <go>go</go>
    <final>print behaviorspace-run-number</final>
    <timeLimit steps="78"/>
    <metric>word run-seed</metric>
    <metric>std-energy</metric>
    <metric>mean-energy-rate-km</metric>
    <metric>residential-moves</metric>
    <metric>I-resource-init</metric>
    <metric>I-util-init</metric>
    <metric>I-util</metric>
    <metric>I-resource</metric>
    <metric>nni</metric>
    <metric>report-mean-energy</metric>
    <metric>report-mean-movelen</metric>
    <metric>report-mean-exptime</metric>
    <metric>report-mean-logmobturn</metric>
    <metric>report-mean-moves</metric>
    <metric>report-mean-fradius</metric>
    <metric>report-std-energy</metric>
    <metric>report-std-movelen</metric>
    <metric>report-std-exptime</metric>
    <metric>report-std-logmobturn</metric>
    <metric>report-std-moves</metric>
    <metric>report-std-fradius</metric>
    <enumeratedValueSet variable="num-bases">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-population">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="coloring">
      <value value="&quot;resources&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="the-random-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="std-energy">
      <value value="6.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="resource-thresh">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-energy-rate-km">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-logistic-move">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-residential-move">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recover-in-nyear">
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="move-start-cost" first="0" step="2" last="60"/>
    <enumeratedValueSet variable="depletion-rate">
      <value value="0.5"/>
    </enumeratedValueSet>
    <steppedValueSet variable="move-before" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="smoothness">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
      <value value="12"/>
      <value value="16"/>
      <value value="25"/>
      <value value="40"/>
      <value value="60"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="e8" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="true">
    <setup>setup
reset-ticks</setup>
    <go>go</go>
    <final>print behaviorspace-run-number</final>
    <timeLimit steps="78"/>
    <metric>word run-seed</metric>
    <metric>I-resource-init</metric>
    <metric>I-util-init</metric>
    <metric>I-util</metric>
    <metric>I-resource</metric>
    <metric>nni</metric>
    <metric>report-mean-energy</metric>
    <metric>report-mean-movelen</metric>
    <metric>report-mean-exptime</metric>
    <metric>report-mean-logmobturn</metric>
    <metric>report-mean-moves</metric>
    <metric>report-mean-fradius</metric>
    <metric>report-std-energy</metric>
    <metric>report-std-movelen</metric>
    <metric>report-std-exptime</metric>
    <metric>report-std-logmobturn</metric>
    <metric>report-std-moves</metric>
    <metric>report-std-fradius</metric>
    <metric>residential-moves</metric>
    <enumeratedValueSet variable="num-bases">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-population">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="coloring">
      <value value="&quot;resources&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="the-random-seed">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="smoothness" first="0" step="1" last="40"/>
    <steppedValueSet variable="std-energy-rate" first="0" step="0.2" last="6"/>
    <enumeratedValueSet variable="resource-thresh">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-size-km">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-logistic-move">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-residential-move">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recover-in-nyear">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="depletion-rate">
      <value value="0.66"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-energy-rate-km">
      <value value="1.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-start-cost">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="move-before">
      <value value="0"/>
    </enumeratedValueSet>
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
0
@#$#@#$#@
