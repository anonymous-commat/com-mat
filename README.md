# Agent-based model of household heat pump adoption in the Netherlands

Results generated with this model were published in the paper:

> **Exploring policy effects on heat pump adoption with a behavioral agent-based model**

The model includes two files:

- `commat_v1.nlogo`: contains the model itself  
- `synthetic population_1.csv`: contains the input data for the model  

These two files should be in the same folder.

---

## Install NetLogo

To run the model, first install the NetLogo application:

- Download: https://www.netlogo.org/downloads/windows/  

For the publication, **NetLogo version 6.3.0** was used.

---

## Run the model

Once NetLogo is installed:

1. Open the model:
   - In NetLogo, click **File > Open**
   - Select the `commat_v1.nlogo` file in the dialog box
2. Change any parameters if desired by:
   - Adjusting the sliders
   - Toggling the on/off switches  
   or leave the default values.
3. Click the blue **`setup`** button.
4. Click the blue **`go`** button, or the blue **`go once`** button.
5. To stop running, click the blue **`go`** button again.

Plots and data can be exported via:

- **File > Export**, then choose the desired option.

---

## Changing the number of agents

The downloaded model runs **1000 agents** by default, because running the full model would take too long otherwise.

To alter the number of agents:

1. Switch from **Interface** to **Code** in the top left corner of the NetLogo window.
2. Click **Find** in the top left corner.
3. In the dialog box after **"Find:"**, type:
   ```netlogo
   set population-data n-of 1000 full-population
4. In this line you can:
   
    a. Run the full population → remove n-of 1000 so it becomes:
    ```netlogo
       set population-data full-population
    ```
    b. Run a different number of agents
          → replace 1000 with another number, e.g.:
    ```netlogo    
          set population-data n-of 5000 full-population
