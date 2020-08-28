# Readme



## Installation Instructions

**Requirements:**

The wind turbine failure predictor is developed based on Jupyter Notebook. You can install Jupyter Notebook by Anaconda. In order to run the machine learning model you must have the following libraries installed. It is recommended to set up a virtual environment for these libraries.

- TensorFlow 2
- Pytorch 1.5
- Pandas
- Numpy
- Scikit-learn
- Matplotlib

In order to download the latest SCADA data, you also need to install MATLAB software.

- MATLAB R2020a



## Content

**Data Folder**

The project makes extensive use of txt files that contain SCADA data. You can use the example data prepared by the author which is included in "Data" folder. You can also use the MATLAB  script to download your own data files.



**Model Folder**

Trained neural networks are saved in the "Model" folder. You can load these trained model to make prediction without the training process.



**Code Folder**

There are four '.ipynb' file in the repository. Each of them contains a standard workflow with the implementation of one machine learning model.



**Matlab_script Folder**

There are 11 MATLAB scripts in this folder. You only need to run the "fcn_readApi.m" to download the SCADA data.



## How to run the model and make prediction

**Prepare  Data:**

First you need to prepare SCADA data. 

1. Use prepared data:

Example SCADA data txt files are provided in "Data" folder. You don't need to change anything.

2. Use new data

It's fine if you want to use the latest SCADA data. To download SCADA data, you need to open the "api input file.txt". You are required to decide the start date, end data, turbine instance ID and signal ID according to "available signals 2020_05.xlsm" file. Then you can simply run "fcn_readApi.m" and SCADA data will be downloaded automatically.



**Run the Models:**

Each ".ipynb" file contains completed workflow for prediction. You just need to run all the cells in sequence, and the final result will be showed in the end. Detailed comments are included so that you can easily understand the function of every line of the code.



Three types of models are developed: 

- Regression model
- Binary classification model
- Multinomial classification model

