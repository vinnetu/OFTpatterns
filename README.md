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
