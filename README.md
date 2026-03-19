# SHAREbrain
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=Neural-Systems-at-UIO/SHAREbrain&file=sharebrain_install.m) 

SHAREbrain is a workflow aimed to help researchers prepare data and metadata in a standardised manner for sharing via the EBRAINS Data &amp; Knowledge service

## Step-by-step guide
Check out the [step-by-step](https://github.com/Neural-Systems-at-UIO/SHAREbrain/wiki) guide in this repository's Wiki

## Workflow Diagram
<img width="1579" alt="SHAREbrain workflow" src="https://github.com/user-attachments/assets/f1d35783-3940-4357-b240-6a302257b47d">

## Workflow Modules

NANSEN to NWB
1. [NANSEN](https://github.com/VervaekeLab/NANSEN/tree/dev) `branch: dev`
2. [NANSEN-SHAREbrain module](https://github.com/NansenModules/SHAREbrain)
3. [NANSEN-NWB module](https://github.com/NansenModules/NANSEN-NWB) (requires [MATNWB](https://github.com/NeurodataWithoutBorders/matnwb))


NANSEN to openMINDS / EBRAINS
1. [openMINDS-MATLAB](https://github.com/openMetadataInitiative/openMINDS_MATLAB)
2. [openMINDS-KG-Sync](https://github.com/ehennestad/openminds-kg-sync)
3. [openMINDS-MATLAB-GUIDE](https://github.com/ehennestad/openMINDS-MATLAB-GUI)
4. [EBRAINS_MATLAB](https://github.com/ehennestad/EBRAINS-MATLAB)

## Getting Started

### Requirements
- MATLAB R2022b to R2024b (R2025a and later compatibility under testing)
  - Image Processing Toolbox (NANSEN)
  - Statistics and Machine Learning Toolbox (NANSEN) 

### Installation
Clone this repository and run:
```matlab
sharebrain_install
```

## Acknowledgements
This project is funded by the University of Oslo via the Hub-Node SHAREbrain
