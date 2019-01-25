; @Todo copyright
;
;

extensions [profiler]

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
  ; For estimates we can refer to empirical data from Kelly 2013, p 99 14000 KCal/family day
  ; In stylized model the unit is energy per person per day, so default = 1
  ; a discussion o how much energy person requires for a week https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5094510/
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
  ;depletion-rate

  move-time-anticip ; when planning residential move, how long shall we think ahead?

  ; As resource regrowth takes lot of computing power we do it after nr of ticks
  regrow-after-ticks

  ; Variables related to seasonality and different resources, maybe exclude
  num-resources ; diversity of resources
  growing-season ; length of resource availability in weeks
  tp-smoothness ; smoothness of placement of resources

  min-usable-utility ;if utility is below this threshold the  place is scrapped

  ; @Todo - a multiplier defining the costs of residential moves per km per person
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

  ; Time recording variables and measurements
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
  report-std-energy
  report-std-movelen
  report-std-exptime
  report-std-logmobturn
  report-std-moves

  std-energy
]

to setup-vars
  clear-all
  ; Setup random seed
  ifelse the-random-seed > 0 [
    random-seed the-random-seed
    set run-seed the-random-seed
  ]
  [
    set run-seed new-seed
    random-seed run-seed
  ]

  ; calculate it to use patch instead of km
  set mean-energy-rate mean-energy-rate-km * (patch-size-km ^ 2)

  set std-energy mean-energy-rate * std-energy-rate

  ; @todo - maybe remove
  ;set tp-smoothness 20
  ;set num-resources 10

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
  set min-usable-utility base-population * (1 / (depletion-rate + 0.00001))

  set debug 0

  ; We don't go further than 4h moving
  set max-logistic-move min list (forage-speed * 3.9) max-logistic-move


end

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
end




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
  print "Mean energy rate:"
  print mean [energy] of patches

end

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
  print "Mean energy rate:"
  print mean [energy] of patches

end

to go
  set residential-moves 0
  set residential-move-length 0

  run-bases

  tick

  if ticks mod regrow-after-ticks = 0 [
    regrow-harvest
  ]

  slow-measurements

  calc-nni

  set report-mean-energy mean [energy - harvested] of patches
  set report-mean-movelen mean [last-move-length] of bases
  set report-mean-exptime mean [expected-time] of bases
  set report-mean-logmobturn mean [log-mobility-turn] of bases
  set report-mean-moves mean [moves] of bases * (365 / days-per-tick)/ ticks

  set report-std-energy mean [energy - harvested] of patches
  set report-std-movelen mean [last-move-length] of bases
  set report-std-exptime mean [expected-time] of bases
  set report-std-logmobturn mean [log-mobility-turn] of bases
  set report-std-moves mean [moves] of bases * (365 / days-per-tick)/ ticks


end


; debug function to print debig information to output
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
170
163
coloring
coloring
"utility" "resources" "none"
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

BUTTON
247
196
342
229
Profile go
;setup                  ;; set up the model\nprofiler:start         ;; start profiling\nrepeat 10 [ go ]       ;; run something you want to measure\nprofiler:stop          ;; stop profiling\nprint profiler:report  ;; view the results\nprofiler:reset         ;; clear the data\n
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
1.0
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
76.0
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
0.0
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
1.01
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
6.1
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
7.2
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
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
171
265
343
298
random-move
random-move
0
100
16.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## Todo

* **marginal value theorem** when it is time to move!
* Utility - return rate - change the logic. Return rate decreases, add return rate threshold. Energy amount - kcal / per person, depletion rate

* How to generlize depletion of patches? Linear gain curve falls below alternatives. Linear funtions (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5373393/)

* Landscape creation - make sliders make sense, the amount of energy will remin same with one slider. Write normalization procedures
* Measure morans I
* Moves per year -> moves last year, mõõdan siin täiesti vale asja, tulemus on keskmine koguaeg, peab ikka jooksvat hetke mõõtma...
* Construct an utility value based on Kelly / Binford
* Assumption of Storage
* Satisficer / maximizer. Minimizing effort
* Comparing energy with time, not good
* Calibrate - null model assumption are Kelly's results
* Risk management createsconstructed affordances, which make moving more costly.

### Questions

We explore can we explain relation between environmental features and rate of residential and logistic mobility by agent based settlement choice model.

Isolate the effect of environmental distribution of energy

Sisu - article

methods - overview of collector-forager continuum and second - 

agent based modelling in settlement chouce and archaeology

* TODO: increased logistical range (and thus longer-term planning) creates a more smooth utility space and this increase in agglomeration. Phase space, when the level of change is actually significant.


* Null model and central forager theory
* Impact of different resource densities
* Impact of different spatial confiurations (roughness, patchiness)
* Utility space is anyway smoothed by notion of access
* Seasonality of resources
* Cost of movement - storage and housing

* Continuation - critical resources water and wood
* Seasonality



## WHAT IS IT?

Goal: explore the possibilities of explaining settlement choice by optimal foraging theory. 
Goal: ask - in case of settlement choice by OFT, how does the distribution of resources on the landscape influence OFT strategies. 

Explore the question with agent based models


(a general understanding of what the model is trying to show or explain)

in reality not all of energy is harvested, sos we are approximating not total energy but the energy of harvest.

Model is calibrate for group and we check te changes. And compare them to general data.
They have a lot of influence, but correlation.

### Central HG concepts to test

All this from Kelly 1992


Binford (17) began to unpack the concept of mobility by differentiating
between **residential mobility**, movements of the entire band or local group
from one camp to another, and **logistical mobility**, foraging movements of
individuals or small task groups out from and back to the **residential camp**.

Binford used these descriptions to categorize two ideal hunter-gatherer settle-
ment systems. **Collectors** move residentially to key locations (e.g. water
sources) and use long logistical forays to bring resources to camp. **Foragers**
"map onto" a region’s resource locations. In general, foragers do not store
food; they make frequent residential moves and short logistical forays. Collec-
tors store food; they make infrequent residential moves but long logistical
forays.

The key difference of those strategies are moving resources to consumers not vice versa.
So we have here 2 dimensions - influence of placement of sources and seasonality to
different envirnonents. And use of storage.

From Kelly (1992) there is a description of Binford types of mobility which form a certain continuum. Forager mobility with a lot of residential moves and less logistical activity. While foragers use long logistic forays and ave more fixed base camps.
Binford added also another dimension of mobility: territorial or long-term mobility, which is either considered to be a conervation measure or responce to subsistence stress.

Kelly has two examples of foragers with very different residential moves rate, but only
because of resource densities they use. So 

Bettinger & Baurnhoff (15, 14:100-3) offer an alternative to Binford’s
forager-collector scheme. Their model proposes a continuum from **travelers**,
who have high mobility (presumably residential and logistical) and take only
high-return-rate food resources, especially large game, to **processors**, who are
less mobile and use intensively a diversity of resources, especially plant foods.
 
Foraging strategies is most important, because when foragers stay they face diminishing returns (Sahlins, M. D. 1972. StoneAge Economics. Chicago: Aldine; p 33)

Many ethnographic cases demonstrate that foragers
move not when all food has been consumed within reach of camp but when
daily returns decline to an unacceptable level (72). Although the Tanzanian
Hadza, for example, can forage for roots up to 8 km from camp, they generally
do not go beyond 5 km, preferring instead to move camp (160).

**Agents** We should point out that foragers do not always move as a group; forager
social units, in fact, can have an extremely fluid composition. Relieving social
tension is a reason often given lbr this fluidity, and subsistence can often be a
source of this tension (Kelly 1992: 47).

**How do decide on movement?**
from: (Kelly 1992: 47).
At the heart of the relationship between daily foraging and group movement
is perceived "costs" of camp movement
and foraging. While it is **unclear what period (e.g. per hour, day, or week) should be used in assessing** the cost and benefits of moving and foraging, we still might predict that as the cost of camp movement increases relative to the benefit of foraging in a new location, foragers will remain longer in the current camp (92).

As resource return rates decline, foragers reach the point of
diminishing returns at shorter and shorter distances and must move more
frequently. Likewise, if a resource appearing elsewhere provides higher return
rates than current foraging provides, the forager may also elect to move. (This,
rather than "affluence," probably explains why foragers pass up some re-
sources; see 70.) Another variable is the "cost" of moving, determined not
only by the distance to the next camp but also by what must be moved (e.g.
housing material), the terrain to be covered (e.g. mountains versus prairie),
availability of transport technology (such as dogsleds or horses) to move
housing, food, and/or people. If food has been stored, then the cost of moving
it must be balanced against the next camp’s anticipated resources. Models
predicting how far resources can be transported (87, 128) show that a re-
source’s return rate does not necessarily predict how far that resource can be
carried.

What Kelly basically said here is the core of the model:
return rate of current place, if diminishing returns, then move which has to be weighted against the moe cost with next canps anitcipated resources.

he variables that affect foraging are also
relevant to horticulture, for both can be evaluated in terms of time, returns,
cost, and risk
	
We also have to introduce a minimum treshold rate. 

We don't include unsknown or risk into our model. No sex / other social labour divisions 
discussed here.

Quatify collecting strategy somehow?

**simulation study by kelly** Kelly, R. L. 1990. Marshes and mobility in
the western Great Basin. In Wetlands Ad-
aptations in the Great Basin. Museum of
Peoples and Cultures Occasional Papers,
ed. J. C. Janetski, D. B. Madsen, 1:259-76.
Provo: Brigham Young Univ.

Because of no data on gain curves and diminishing returns we are using a stylized model to isolate the effect of environment.

## HOW IT WORKS

### On setup

1. System generates resource coverage of the whole space with max energy potential of locations. It will be determined by randomness currently

2. Generate utility space that is quantifies to access to resources 
every adjacent patchs until (max) adds existing resources value to space / divided by it's distance from potential home. (maybe should structure differently).

The utility is expected energy transition rate for different periods of time.

Let's do without seasonality. Week, 2 week, 4 weeks, 8 weeks, 16 weeks, 32 weeks.

Time for getting sufficient resources for pop of X during a period of time.

Should be simple equation from Kelly (2015).  

3. Optimize, search for best places (200), that might be interesting during the game.

### Every tick

1. Restore consumed resources

2. 

X. compare current acquisition rate to promise of the new location + moving costs there

X. take level of optimization from previous experience - mean of all previous time-span choices

### Every agent every tick

Calculate utility at current place. 

There are different evaluations regarding the expected length of stay. 
Selects the expected length, but adjusts it by previous experience.

Search whole map for utility, where utility > current place + moving costs.
We measure the ease of access to resources given time period selected (nr of weeks from
1-52)

The real leave time is changing the strategy for the next turn.

Ease of access to required amount of energy for given period of time.
(in case there will be no energy in the future? Calculate maps for all months)

if new place is better than current expected stay

### Calculation of the utility value

Kelly had a specific formula from calculating a return rate from biomass.



###
Results just scaling - system works slower and resources can regenerate before move is required. Sedantism.



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

## WORK LIST

* Expectations of stay length and settlement choice. This should be dynamic.
Next one will be on previous experience. No need to move.
Change strategy for longer location.


**Settlement choice**

Costs of logistical mobility vs residential mobility
Costs of storage - site investment ("home effect")

Create simulated resource spaces utility values considering different 
anticipations

If anticipated for next month and 6 months similar and sufficient, no need for storage.

3 different resource types.

Resource dynamics - plants, hunting, aquatic

Season availability
Costs of harvesting ji

* resource depletion, models of how it works
https://www.sciencedirect.com/science/article/pii/0278416588900013



* move before resource depletion:
http://www.pnas.org/content/early/2017/03/01/1617542114

* scope - areas of hunter-gatherer groups

* design stuff
http://www.cs.us.es/~fsancho/?e=137

* Overview of base concepts
https://www.unl.edu/rhames/courses/for97notes.htm
http://users.clas.ufl.edu/sassaman/pages/classes/ant6930/ANG6930-6.htm
http://homes.chass.utoronto.ca/~coupland/ANT310/lectures/HGtheory.htm

* Tallavaara implementation
https://zenodo.org/record/1167852#.XAD5B8tKhFQ
http://www.pnas.org/content/pnas/115/6/1232.full.pdf

## Concepts

### Net acquisition rate (productivity)
https://www.sciencedirect.com/science/article/pii/0278416588900013

### Carrying capacity

### Harvest and depletion, which effect has it on NAR

### Gain curves & depletion of resources

https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5373393/
cumulative resource acquisition through time

Currently there are is only one study done on them showing that the gain functions have a huge variety, so we generalize the gain function while isolating distribution effect,
but it must be generalized and the impact of different gain functions must be tested.

### Why stylized model?

Gain curves and diminishing returns have been difficult to quantify. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5373393/



### Environmental average return rate
Optimal foraging, the marginal value theorem.
Charnov EL
Theor Popul Biol. 1976 Apr; 9(2):129-36.




## Some data estimates collected by Binford

**tlpop**. Total number of persons to whom the ethnographic description applies; (Table:5.01); (Binford 2001:117)
mean 1697.854	min 23	max 14582	sd 2356.97

**area**. Ethnographers' estimate of total land area occupied by the group (100 sqkm); (Table: 5.01); (Binford 2001:117)
mean 388.75	min 0.8	max 6600	sd 832.748
 
**density**. Population density (==tlpop/area); (Table: 5.01); (Binford 2001:117)
mean 24.586	min 0.25	max 308.7	sd 36.085
 
**group1**. Size of smallest group that regularly cooperates for subsistence; smallest self-sufficient group; (Table: 5.01 & 8.01); (Binford 2001:117)
mean 17.525	min 5.6	max	70	sd	9.76
 
**group2**. The mean size of the consumer group that regularly camps together during the most aggregated phase of the yearly economic cycles; (Table: 5.01 & 8.01); (Binford 2001:117)
mean	74.908	min	19.5	max	650	sd	85.42
 
**group3**. The mean size of multigroup encampments that may aggregate periodically, but not necessarily annually, for immediate subsistence-related activities; (Table: 5.01 & 8.01); (Binford 2001:117)
mean	209.342	min	42	max	1500	sd	182.688

## Literature

* Kelly, R.L., 1992. Mobility/Sedentism: Concepts, Archaeological Measures, and Effects. Annual Review of Anthropology 21, 43–66. https://doi.org/10.1146/annurev.an.21.100192.000355

### TODO

Just map all data we have in human settlement patterns

### Parameter calibration


Model: All energy of environment; mean energy per square; max energy per square;

Reality: 


## Idee

Critical resources replaced by constructed resources / affordances



 
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
NetLogo 6.0.4
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
    <timeLimit steps="78"/>
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
    <metric>report-std-energy</metric>
    <metric>report-std-movelen</metric>
    <metric>report-std-exptime</metric>
    <metric>report-std-logmobturn</metric>
    <metric>report-std-moves</metric>
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
    <steppedValueSet variable="std-energy" first="0" step="1" last="4"/>
    <enumeratedValueSet variable="resource-thresh">
      <value value="0"/>
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
    <enumeratedValueSet variable="random-move">
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
