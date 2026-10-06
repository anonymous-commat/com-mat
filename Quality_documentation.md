Quality documentation COM-MAT
================

## 1 Model description

### 1.1 Goal and application of the model

The goal of the model is to better understand how behavior and external
factors drive heatpump adoption over time, and to explore the effect of
different policy scenarios on heat pump adoption in the Netherlands.

### 1.2 General description of the model

COM-MAT is an agent-based model that simulates heat pump adoption by
households in the Netherlands. Each agent in the model represents a
household. The households are interconnected, and each household has its
own parameters. These parameters combined with the households’
connection to other households drive heat pump adoption. Once a
households adopts a heat pump, that state is permanent. The model
simulates over time and each time step represents 3 months.

The model is based on two other models: the HUMAT modeling framework
((Jager et al. 2025)) and the COM-B model of behavioral change ((Michie
et al. 2011)). Combining the models into COM-MAT was done by integrating
the COM-B components into the HUMAT model.

For a more elaborate description of the model see (Jager et al. in
prep).

### 1.3 Conceptual and formal model

For the theory behind the model and the assumptions embedded in the
model see (Jager et al. in prep).

## 2 Technical implementation

### 2.1 Model implementation

For a manual on running the model, see the README in this repository see
[this README.](https://github.com/anonymous-commat/com-mat#)

### 2.3 Programming language and IDE

Both the programming language and IDE for this model are NetLogo.
Information on how to install NetLogo is present in the README in this
repository.

### 2.4 Verification of the model

The model was calibrated and verified against historical data. This
historical data was data on Dutch household heatpump adoption between
2015 and 2024. For more information see section 3.3 in (Jager et al. in
prep).

### 2.5 Tests of implementation



## 3 Parameters, input and output

### 3.1 Documentation of parameters and variables

COM-MAT takes the input parameters described in Table A1 of (Jager et
al. in prep).

### 3.2 Calibration of parameters

The model was calibrated with survey data on heat pump adoption and
living situation among Dutch citizens. More information on the
collection of this data can be found in section 3.2.1 of (Jager et al.
in prep). The synthetic dataset made from this survey data was published
here (insert zenodo link later).

### 3.3 Input and output

For the input parameters see section 3.1 above. The output of the model
is the fraction of houses that adopts a heat pump over time.

### 3.4 Data sources

The data used for creating and calibrating this model was collected via
a survey, from CBS and the Rijksoverheid. For a more detailed
description of the data used see (Jager et al. in prep).

## 4 Model evaluation

### 4.1 Sensitivity analysis

For the sensitivity analysis see section 3.4 and Appendix B of (Jager et
al. in prep).

### 4.2 Uncertainty analysis

### 4.3 Validation

For the validation see Appendix A of (Jager et al. in prep).

### 4.4 Documented use of the model

When the model is used in publications, these will be listed in this
section.

### 4.5 Fitness for purpose

<div id="refs" class="references csl-bib-body hanging-indent">

<div id="ref-dejager2026" class="csl-entry">

Jager, Lynn de, Natalie van der Wal, Liesbeth Claassen, Geeske Scholz,
Agnese Fuortes, and Emile Chappin. in prep. *Exploring Policy Effects on
Heat Pump Adoption with a Behavioral Agent-Based Model*. in prep.

</div>

<div id="ref-jager2025" class="csl-entry">

Jager, Wander, Patrycja Antosz, Loes Bouman, et al. 2025. “HUMAT: An
Integrated Framework for Modelling Individual Motivations, Social
Exchange and Network Dynamics.” *Journal of Artificial Societies and
Social Simulation* 28 (1): 4. <https://doi.org/10.18564/jasss.5611>.

</div>

<div id="ref-michie2011" class="csl-entry">

Michie, Susan, Maartje van Stralen, and Robert West. 2011. “The
Behaviour Change Wheel: A New Method for Characterising and Designing
Behaviour Change Interventions.” *Implementation Science : IS* 6
(April): 42. <https://doi.org/10.1186/1748-5908-6-42>.

</div>

</div>
