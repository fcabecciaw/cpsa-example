<!--

Copyright © 2023 Advanced Micro Devices, Inc. All rights reserved.
SPDX-License-Identifier: MIT

Author: Daniele Bagni, AMD/Xilinx Inc
-->


<!-- <table class="sphinxhide" width="100%">
 <tr width="100%">
    <td align="center"><img src="https://raw.githubusercontent.com/Xilinx/Image-Collateral/main/xilinx-logo.png" width="30%"/><h1>Vitis™ AI Tutorials</h1>
    </td>
 </tr>
</table> -->

#  ResNet18 in PyTorch from Vitis AI Library

- Version:      Vitis AI 3.5 with Pytorch 1.13.1

- Support:      KV260

- Last update:  28 April 2026


## Table of Contents

[1 Introduction](#1-introduction)

[2 Prerequisites](#2-prerequisites)

[3 The Docker Tools Image](#3-the-docker-tools-image)

[4 The VCoR Dataset](#4-the-vcor-dataset)

[5 Vehicle Color Classification](#5-vehicle-color-classification)

[License](#license)



## 1 Introduction

### 1.1 Rationale

In this Deep Learning (DL) tutorial you will take a public domain Convolutional Neural Network (CNN) like [ResNet18](https://github.com/songrise/CNN_Keras/blob/main/src/ResNet-18.py) and pass it through the [Vitis AI 3.5](https://github.com/Xilinx/Vitis-AI) stack to run DL inference on FPGA devices; the application is classifying the different colors of the "car object" inside images.

Although ResNet18 was already trained on the [ImageNet](https://www.image-net.org/) dataset in the **PyTorch** framework, we will use another version fine-tuned on the [VCoR](https://www.kaggle.com/datasets/landrykezebou/vcor-vehicle-color-recognition-dataset) dataset. 	


### 1.2 The Vitis AI Flow

Assuming you have already trained your CNN and you own its original model, typically a [PT](https://docs.pytorch.org/tutorials/beginner/saving_loading_models.html) file with extension ``.pt``, you will deploy such CNN on the FPGA target boards by following these steps:

  <!-- 1. (optional) Run the [Model Inspector](https://xilinx.github.io/Vitis-AI/3.5/html/docs/workflow-model-development.html?highlight=inspector#model-inspector) to check if the original model is compatible with the AMD [Deep Processor Unit (DPU)](https://xilinx.github.io/Vitis-AI/3.5/html/docs/workflow-system-integration.html)  architecture available on the target board (if not, you have to modify your CNN and retrain it). -->

  1. Run the [Model Quantization](https://xilinx.github.io/Vitis-AI/3.5/html/docs/workflow-model-development.html?highlight=quantizer#model-quantization) process to generate a 8-bit fixed point (shortly "int8") model from the original 32-bit floating point CNN. If you apply the so called *Post-Training Quantization* (PTQ), this will be a single step, otherwise you would need to re-train - or more properly said "fine-tune" - the CNN with the *Quantization-Aware-Training* (QAT). Note that QAT is out of the scope of this tutorial.

  2. (optional) Run inference with the int8 model on the Vitis AI environment (running on the host desktop) to check the prediction accuracy: if the difference is not negligible (for example it is larger than 5%, you can re-do the quantization by replacing PTQ with QAT).  

  3. Run the [Model Compilation](https://xilinx.github.io/Vitis-AI/3.5/html/docs/workflow-model-development.html?highlight=quantizer#model-compilation) process  on the int8 model to generate the ``.xmodel`` microcode for the DPU IP soft-core of your target board.

  4. Compile the application running on the ARM CPU - tightly coupled with the DPU - of the target board, by using either C++ or Python code with the [Vitis AI RunTime (VART)](https://xilinx.github.io/Vitis-AI/3.5/html/docs/workflow-model-deployment.html#vitis-ai-runtime) APIs.  

Based on that you will be able to measure the inference performance both in terms of average prediction accuracy and frames-per-second (fps) throughput on your target board.

All the commands reported in this document are also collected into the [run_all.sh](files/run_all.sh) script.



## 2 Prerequisites

Here is what you need to have and do before starting with the real content of this tutorial.

- Familiarity with DL principles.

- Accurate reading of this [README.md](README.md) file from the top to the bottom, before running any script.

- Host PC with Ubuntu >= 18.04.5.

- Clone the entire repository of [Vitis AI 3.5](https://github.com/Xilinx/Vitis-AI) stack from [www.github.com/Xilinx](https://www.github.com/Xilinx) web site.

-  Accurate reading of [Vitis AI User 3.5 Guide 1414](https://docs.xilinx.com/r/en-US/ug1414-vitis-ai) (shortly UG1414).

- Accurate reading of [Vitis AI 3.5 Online Documentation](https://xilinx.github.io/Vitis-AI/3.5/html/index.html). In particular, pay attention to the installation and setup instructions for both host PC and target board. We prepared a plug-and-play virtual machine (```VM``` from now on) so that you do not need to pass through this step, but it may be a useful reading anyway.

- The target board AMD Zynq® UltraScale+™ MPSoC [KV260](https://www.amd.com/en/products/system-on-modules/kria/k26/kv260-vision-starter-kit.html), with its Starter Kit Application Firmware installed. The board must be reachable over serial console and Ethernet and must load the `kv260-benchmark-b4096` DPU firmware application. The full board preparation flow is detailed in Section [5.5](#55-run-on-the-target-board).

- The ``archive.zip`` file with the [Kaggle](www.kaggle.com) dataset of images, as explained in Section [4](#4-the-vcor-dataset).

- The [Model Zoo](https://github.com/Xilinx/Vitis-AI/tree/master/model_zoo) ``pt_vehicle-color-classification_3.5.zip`` archive, as explained in Section [5.1](#51-vehicle-color-classification).


### 2.1 Working Directory

In the following of this document it is assumed you have installed Vitis AI 3.5 (shortly ``VAI3.5``) somewhere in your file system and this will be your working directory ``${WRK_DIR}``. In the provided ```VM```, the path is ``/home/cpsa/VAI3.5``. Let's export it as a global variable for convenience:
```bash
export WRK_DIR = /home/cpsa/VAI3.5
```
Then, we need to build a folder named ``tutorials`` where we will clone this repo:
```bash
cd WRK_DIR
mkdir tutorials && cd ./tutorials
git clone https://github.com/fcabecciaw/cpsa-example.git
cd ./cpsa-example
```
Using the command ``tree -d -L 2`` you should see a directory structure similar to the following:

```
${WRK_DIR} # your Vitis AI 3.5 working directory
.
├── bck
├── board_setup
│   ├── v70
│   └── vek280
├── demos
├── docker
│   ├── common
│   ├── conda
│   └── dockerfiles
├── docs
│   ├── docs
│   ├── _downloads
│   ├── doxygen
│   ├── _images
│   ├── _sources
│   └── _static
├── docsrc
│   ├── build
│   └── source
├── dpu
├── examples
│   ├── custom_operator
│   ├── ofa
│   ├── OnBoard
│   ├── vai_library
│   ├── vai_optimizer
│   ├── vai_profiler
│   ├── vai_quantizer
│   ├── vai_runtime
│   ├── waa
│   └── wego
├── model_zoo
│   ├── images
│   └── model-list
├── src
│   ├── AKS
│   ├── vai_library
│   ├── vai_optimizer
│   ├── vai_petalinux_recipes
│   ├── vai_quantizer
│   └── vai_runtime
├── third_party
│   ├── tflite
│   └── tvm
└── tutorials # created by you
    ├── cpsa-example # this tutorial
```

### 2.2 Dos-to-Unix Conversion

In case you might get some strange errors during the execution of the scripts, you have to process (once) all the``*.sh`` shell and the python ``*.py`` scripts, which can be found at [scripts](files/scripts) and [code](files/code) with the [dos2unix](http://archive.ubuntu.com/ubuntu/pool/universe/d/dos2unix/dos2unix_6.0.4.orig.tar.gz) utility.
In that case run the following commands from your Ubuntu host PC (out of the Vitis AI docker images, in a different shell):

```
sudo apt-get install dos2unix

cd ${WRK_DIR}/tutorials/PyTorch-ResNet18 #your repo directory

for file in $(find . -name "*.sh"); do
  dos2unix ${file}
done
for file in $(find . -name "*.py"); do
  dos2unix ${file}
done
for file in $(find . -name "*.c*"); do
  dos2unix ${file}
done
for file in $(find . -name "*.h*"); do
  dos2unix ${file}
done
```

These operations are already included in the script [clean_all.sh](files/scripts/clean_all.sh), launched by the [run_all.sh](files/run_all.sh) script, which collects all the commands shown in the rest of this document.

It is strongly recommended that you familiarize with the [run_all.sh](files/run_all.sh) script in order to understand all what it does, ultimately the entire Vitis AI flow on the host computer.



## 3 The Docker Tools Image

You have to know few things about [Docker](https://docs.docker.com/) in order to run the Vitis AI smoothly on your host PC environment.

### 3.1 Build the Image

This tutorial assumes that you are going to use one of the containers available at [Docker Hub](https://hub.docker.com/u/xilinx), and thus this section is only useful if you would like to try a different combination of framework and architecture (e.g. PyTorch with CUDA).

From the Vitis AI 3.5 repository, run the following commands:

```
cd ${WRK_DIR}
cd docker
./docker_build.sh -t gpu -f pytoch
```

Once the process is finished, with the command ``docker images`` you should see something like this:

```
REPOSITORY                        TAG               IMAGE ID       CREATED         SIZE
xilinx/vitis-ai-pytorch-gpu  3.5.0.001-b56bcce50   3c5d174a1807   27 hours ago    21.4GB
```
For more information about this process, see the [Vitis-AI Installation Instructions](https://xilinx.github.io/Vitis-AI/3.5/html/docs/install/install.html#)

### 3.2 Launch the Docker Image

To launch the docker container with Vitis AI tools, execute the following commands from the ``${WRK_DIR}`` folder:

```
cd ${WRK_DIR} # you are now in Vitis_AI subfolder

./docker_run.sh xilinx/vitis-ai-pytorch-cpu:latest

conda activate vitis-ai-pytorch

cd /workspace/tutorials/cpsa-example # your current directory
```

Note that the container maps the shared folder ``/workspace`` with the file system of the Host PC from where you launch the above command.
This shared folder enables you to transfer files from the Host PC to the docker container and vice versa.

The docker container does not have any graphic editor, so it is recommended that you work with two terminals and you point to the same folder, in one terminal you use the docker container commands and in the other terminal you open any graphic editor you like. A typical setup would be [VSCode](https://code.visualstudio.com/) with the [DevContainer](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension, which allows you to attach the former to any running container in your system.

The test script also uses two PyTorch extensions, ``randaugment`` and ``torchsummary``. To install them:

```
sudo su
conda activate vitis-ai-pytorch
pip install randaugment
pip install torchsummary
#exit
```

then remember to permanently save the modified docker image from a different terminal (a second one, besides the first one in which you are running the docker image),
by launching the following commands:

```
$ sudo docker ps -l
$ sudo docker commit -m"COMMENT" CONTAINER_ID DOCKER_IMAGE
```

you should see something like this:

```
$ sudo docker ps -l
CONTAINER ID   IMAGE                                       COMMAND                  CREATED       
8626279e926e   xilinx/vitis-ai-pytorch-cpu:3.5.0.001-b56bcce50     "/opt/…"   6 hours ago  

$ sudo docker commit -m"pyt new_package" 8626279e926e   xilinx/vitis-ai-pytorch-cpu:3.5.0.001-b56bcce50  
```


### 3.3 Things to Know

1. In case you "[Cannot connect to the Docker daemon at unix:/var/d9f942cdf7de   xilinx/vitis-ai-tensorflow2-gpu:3.5.0.001-b56bcce50 run/docker.sock. Is the docker daemon running?](https://stackoverflow.com/questions/44678725/cannot-connect-to-the-docker-daemon-at-unix-var-run-docker-sock-is-the-docker)" just launch the following command:

  ```
  sudo systemctl restart docker
  ```

2. Note that docker does not have an automatic garbage collection system as of now. You can use this command to do a manual garbage collection:

  ```
  docker rmi -f $(docker images -f "dangling=true" -q)
  ```

3. In order to clean the (usually huge amount of) space consumed by Docker have a look at this post: [Docker Overlay2 Cleanup](https://bobcares.com/blog/docker-overlay2-cleanup/). The next commands are of great effect (especially the last one):

  ```
  docker system df
  docker image prune --all
  docker system prune --all
  ```


## 4 The VCoR Dataset

The dataset adopted in this tutorial is the **Kaggle' Vehicle Color Recognition**, shortened as  [VCoR](https://www.kaggle.com/datasets/landrykezebou/vcor-vehicle-color-recognition-dataset). 	

This dataset is composed of 15 classes of colors (for the cars) to be classified. It contains labeled RGB images that are 224x224x3 in size and it was developed for the paper

  - Panetta, Karen, Landry Kezebou, Victor Oludare, James Intriligator, and Sos Agaian. 2021. "Artificial Intelligence for Text-Based Vehicle Search, Recognition, and Continuous Localization in Traffic Videos" AI 2, no. 4: 684-704. [https://doi.org/10.3390/ai2040041](https://doi.org/10.3390/ai2040041)

  - open access: [https://www.mdpi.com/2673-2688/2/4/41](https://www.mdpi.com/2673-2688/2/4/41)

While being out of the docker container, download the ~602MB ``archive.zip`` file from the [VCoR](https://www.kaggle.com/datasets/landrykezebou/vcor-vehicle-color-recognition-dataset) website and then unzip it to the``build/dataset/vcor`` folder. Note that this process is also performed by the [run_all.sh](files/run_all.sh) script:

```bash
cd ${WRK_DIR}/tutorials/cpsa-example/files
# you must have already downloaded the zip archive
unzip ./archive.zip -d ./build/data/vcor/
```



## 5 Vehicle Color Classification with ResNet18

Once we have our dataset, we can move to the process of loading the model. From now on, every process will be performed on the container, so activate it as we saw in Section [3.2](#32-launch-the-docker-image).

### 5.1  Get ResNet18 from Vitis AI Model Zoo

You have to download the ``pt_vehicle-color-classification_3.5.zip`` archive of ResNet18 reported in this [model.yaml](https://github.com/Xilinx/Vitis-AI/blob/master/model_zoo/model-list/pt_vehicle-color-classification_3.5/model.yaml) file.
As the file name says, such CNN has been trained RGB images of input size 224x224 and it requires a computation of 3.64GOPs per image.

From the docker image, unzip the archive ``pt_vehicle-color-classification_3.5.zip`` in the ``files`` folder
and clean some files/folders, doing the following actions (already available in the [run_all.sh](files/run_all.sh) script):

```shell
cd ${WRK_DIR} # you are now in Vitis_AI subfolder
# enter in the docker image
./docker_run.sh xilinx/vitis-ai-pytorch-gpu:latest
# activate the environment
conda activate vitis-ai-pytorch
# go to the tutorial directory
cd /workspace/tutorials/
cd PyTorch-ResNet18/files # your current directory
# you must have already downloaded the archive
unzip pt_vehicle-color-classification_3.5.zip
# clean some files/folders
cd pt_vehicle-color-classification_3.5
rm -rf code data *.md *.txt *.sh
cd ..
```

You will get the ``files/pt_vehicle-color-classification_3.5/`` folder where you can find the pre-trained floating point model and the quantized model respectively in the sub-folder ``float`` and ``quant``. You can ignore and remove all the other sub-folders. The ResNet18 CNN applied in this tutorial aims to recognize the color of the car vehicle in the input image.

In practical applications, the input image often contains multiple vehicles, or there are many areas as the background,
so it is usually used together with an object detection CNN, which means firstly use the object detection network to detect the vehicle area and cut the original image according to the bounding box which is the output of the object detection network, then send the cropped image to the network for classification. In the ``pt_vehicle-color-classification_3.5``
you could use the YoloV3 CNN to detect the cars in the VCoR dataset and use cropped images to build a new dataset to train and test the model.
If your input image contains little background, or your CNN is not used in conjunction with an object detection CNN, then you can skip this step (which is what done indeed in this tutorial. but it may be an interesting extension).

This vehicle color model falls under the [Vitis AI Library “classification” examples](https://github.com/Xilinx/Vitis-AI/blob/master/examples/vai_library/samples/classification/readme):

- The model name is ``chen_color_resnet18_pt``, which makes it not obvious that it is actually a vehicle color classification.

- Here is the [list of the car colors](https://github.com/Xilinx/Vitis-AI/blob/master/src/vai_library/xnnpp/src/classification/car_color_chen.txt). Since there are 15 colors, there are also 15 classes to be classified.

- The DPU output will be a [data structure of classification results](https://docs.xilinx.com/r/en-US/ug1354-xilinx-ai-sdk/vitis-ai-Classification) with 15 classes. Such output tensor will then be used by the ARM CPU to compute the functions ``SoftMax`` and related ``Top-5`` prediction accuracy.



<!--### 5.2 Training

If you want to train the ResNet18 CNN on the VCoR dataset from scratch, just launch the script [run_train.sh](files/scripts/run_train.sh) (which is already done from the [run_all.sh](files/scripts/run_all.sh) script):

```shell
cd ${WRK_DIR} # you are now in Vitis_AI subfolder
# enter in the docker image
./docker_run.sh xilinx/vitis-ai-pytorch-gpu:latest
# activate the environment
conda activate vitis-ai-pytorch
# go to the tutorial directory
cd /workspace/tutorials/
cd PyTorch-ResNet18/files # your current directory
bash -x ./scripts/run_train.sh main_vcor
```

You should see something like this:

```text
. . .

Train Epoch: 29 [0/7267 (0%)]	Loss: 0.004103
Train Epoch: 29 [5120/7267 (71%)]	Loss: 0.006058
Test set: Average loss: 0.4320, Accuracy: 1380/1550 (89.032%)

. . .

classes: ['beige', 'black', 'blue', 'brown', 'gold', 'green', 'grey', 'orange', 'pink', 'purple', 'red', 'silver', 'tan', 'white', 'yellow']

Test set: Average loss: 0.4320, Accuracy: 1380/1550 (89.032%)
```

Note that when you use ``ToTensor()`` class in the [train.py](files/code/train.py) and [test.py](files/code/test.py) files, PyTorch [automatically converts all images into ``[0,1]`` range](https://discuss.pytorch.org/t/does-pytorch-automatically-normalizes-image-to-0-1/40022).

The images are supposed to be in RGB format and not in BGR (usually adopted by OpenCV library) -->


### 5.2 Quantization

Given the pre-trained floating-point model we can perform quantization using the script [run_quant.sh](files/scripts/run_quant.sh) (which is already done from the [run_all.sh](files/scripts/run_all.sh) script).

You should see something like this:

```text
. . .

[VAIQ_NOTE]: =>Doing weights equalization...
[VAIQ_NOTE]: =>Quantizable module is generated.(quantized/ResNet.py)
[VAIQ_NOTE]: =>Get module with quantization.

Test set: Average loss: 0.4234, Accuracy: 1376/1550 (88.774%)

. . .

[VAIQ_NOTE]: =>Successfully convert 'ResNet_0' to xmodel.(quantized/ResNet_0_int.xmodel)
[VAIQ_NOTE]: ResNet_int.pt is generated.(quantized/ResNet_int.pt)
[VAIQ_NOTE]: ResNet_int.onnx is generated.(quantized/ResNet_int.onnx)
```

This script can be easily adapted to other models and datasets by changing:
```bash
WEIGHTS_FILE=${path to the trained model checkpoint}
DATASET=${name of the dataset}
BACKBONE=${custom model}
```

### 5.3 Compile the Target DPU  

The quantized CNN has then to be compiled for the DPU architecture of your target board, with the script [run_compile.sh](files/scripts/run_compile_kv260.sh) (which is already done from the [run_all.sh](files/scripts/run_all.sh) script).

You should see something like this:

```text
-----------------------------------------
COMPILING MODEL FOR KV260 benchmark-b4096 DPU..
-----------------------------------------
[UNILOG][INFO] Compile mode: dpu
[UNILOG][INFO] Debug mode: null
[UNILOG][INFO] Target architecture: DPUCZDX8G_ISA1_B4096_0101000016010407
[UNILOG][INFO] Graph name: ResNet_0, with op num: 171
[UNILOG][INFO] Begin to compile...
[UNILOG][INFO] Total device subgraph number 3, DPU subgraph number 1
[UNILOG][INFO] Compile done.
[UNILOG][INFO] The meta json is saved to "/workspace/tutorials/PyTorch-ResNet18/files/./build/compiled_kv260/meta.json"
[UNILOG][INFO] The compiled xmodel is saved to "/workspace/tutorials/PyTorch-ResNet18/files/./build/compiled_kv260/kv260_ResNet_0_int.xmodel.xmodel"
[UNILOG][INFO] The compiled xmodel's md5sum is <different-md5sum>, and has been saved to "/workspace/tutorials/PyTorch-ResNet18/files/./build/compiled_kv260/md5sum.txt"
**************************************************
-----------------------------------------
MODEL COMPILED
-----------------------------------------
```


### 5.4 Run on the Target Board

Now that we have the compiled ```.xmodel``` we can deploy to the Kria. Before doing so though, we have to prepare the target board accordingly. From now on we will not be needing the VAI docker anymore, so we can switch to new fresh shell.

All the commands illustrated in the following subsections are inside the script [run_all_vcor_target.sh](files/target/vcor/run_all_vcor_target.sh), they are applied directly in the target board by launching the command ``run_all_target.sh kv260``, which involves  the [run_all_target.sh](files/target/run_all_target.sh) higher level script.

Before going forward though, let us focus for a second on the C++ application running on the embedded ARM CPU of your target board. This is written in the [main_int8.cc](files/target/vcor/code/src/main_int8.cc) file. Note that the input images are pre-processed - before entering into the DPU - exactly in the same way they were pre-processed during the training, that is:

  - RGB image format (and not BGR);

  - the pixel range [0, 255] is normalized into data range [0,1]

Here is the related fragment of C++ code:

```text
Mat image = imread(baseImagePath + images[n + i]);

/*image pre-process*/
Mat image2 = cv::Mat(inHeight, inWidth, CV_8SC3);
resize(image, image2, Size(inHeight, inWidth), 0, 0, INTER_NEAREST);
for (int h = 0; h < inHeight; h++)
{
  for (int w = 0; w < inWidth; w++)
  {
    for (int c = 0; c < 3; c++)
    {
      //in RGB mode
      imageInputs[i*inSize+h*inWidth*3+w*3+2-c] = (int8_t)( (image2.at<Vec3b>(h, w)[c]/255.0f)*input_scale );
    }
  }
}
```
This is very important: each time you perform inference you must pre-process the images the same way they were processed during training. 

Note that the DPU API apply [OpenCV](https://opencv.org/) functions to read an image file (either ``png`` or ``jpg`` or whatever format) therefore the images are seen as BGR and not as native RGB. All the training and inference steps done in this tutorial treat images as RGB, which is true also for the above C++ normalization routine.


#### 5.4.1 KV260 Board Setup and Execution

Before going forward with the execution, we must make sure that the board actually contains the target DPU and, if not, we must install it. In the following section we will see:
1. How to [connect](#connect-to-the-board) to the board.
2. How to [install](#install-the-b4096-dpu-firmware-package) the DPU firmware package.

###### Prerequisites

We assume the following prerequisites:

```text
Board:              Kria KV260
Board user:         ubuntu
Host OS:            Ubuntu/Linux
Host-board link:    Ethernet cable
Serial console:     USB-UART
Board IP:           10.42.0.217
Host Ethernet IP:   10.42.0.1
Target folder:      target_kv260
DPU application:    kv260-benchmark-b4096
```

The host Ethernet interface used in this tutorial is:

```text
eno1
```

Replace `eno1` with your actual wired Ethernet interface if different.

To find the host interfaces:

```bash
ip -br link
ip -br addr
```

Common wired interface names are:

```text
eno1
enp0s31f6
enp3s0
eth0
```

---

##### Connect to the board

###### Connect the cables

Connect:

1. USB-UART cable from host PC to the Kria board;
2. Ethernet cable from host PC to the Kria board;
3. Kria power supply.

The USB-UART connection is used for first access and recovery. Once we setup the ethernet connection it will not be needed anymore.
The Ethernet connection is used for SSH, SCP, and Internet sharing.

---

###### Open the serial console

On the host PC:

```bash
sudo apt update
sudo apt install -y putty

dmesg | grep -E "ttyUSB|ttyACM"
```

Find the serial device. It is usually one of:

```text
/dev/ttyUSB0
/dev/ttyUSB1
...
/dev/ttyACM0
/dev/ttyACM1
...
```
Note that ```dmesg``` only works if the board is correctly connected via USB (meaning we need the correct cable for that).
In this case the serial device is /dev/ttyUSB1, thus we can connect to the board with:

```bash
sudo putty -serial /dev/ttyUSB1 -sercfg 115200,8,n,1,N
```

If your device is different, replace `/dev/ttyUSB1` accordingly.

Log in as:

```text
user: ubuntu
password: cpsa2026
```

If needed, set or reset the password from the serial console:

```bash
sudo passwd ubuntu
```

---

###### Configure the direct Ethernet link

###### On the host PC
To setup the host side of the Ethernet connection we need to decide a static IP address for it. For simplicity, we will use 
```10.42.0.1/24```, but you can technically use any other address you want (see [this](#ip-subnet-note) section for a general rule of thumb).

```bash
HOST_BOARD_IF=eno1

sudo ip addr flush dev ${HOST_BOARD_IF}
sudo ip addr add 10.42.0.1/24 dev ${HOST_BOARD_IF}
sudo ip link set ${HOST_BOARD_IF} up

ip -br addr show ${HOST_BOARD_IF}
```

Expected:

```text
eno1 UP 10.42.0.1/24
```

Check that the physical Ethernet link is detected:

```bash
cat /sys/class/net/${HOST_BOARD_IF}/carrier
```

Expected:

```text
1
```

If it prints `0`, check the Ethernet cable and the board Ethernet port.

###### On the board, through serial console
Now we also fix the IP address of the board.

```bash
BOARD_IF=eth0

sudo ip addr flush dev ${BOARD_IF}
sudo ip addr add 10.42.0.217/24 dev ${BOARD_IF}
sudo ip link set ${BOARD_IF} up

ip -br addr show ${BOARD_IF}
```

Expected:

```text
eth0 UP 10.42.0.217/24
```

###### IP subnet note

The IP addresses used for the direct host-board Ethernet link are independent from the network used by the host PC to access the Internet. However, the two networks must not use the same subnet.

For example, if the host PC is connected to Wi-Fi on:

```text
192.168.1.0/24
```
then the following direct Ethernet configuration is safe:

```text
Host Ethernet: 10.42.0.1/24
Board Ethernet: 10.42.0.217/24
```
If the host PC is already using the ```10.42.0.0/24``` subnet for Internet access, choose a different private subnet for the direct board link, for example:
```text
Host Ethernet: 192.168.50.1/24
Board Ethernet: 192.168.50.2/24
```
The rule is:
```text
Host and board must be on the same subnet.
The host-board subnet must not conflict with the host Internet subnet.
```
---


###### Check that host and board can see each other

From the host PC:

```bash
ping -c 4 10.42.0.217
```

From the board:

```bash
ping -c 4 10.42.0.1
```

If both pings work, the host-board Ethernet link is correct.

You can now connect from the host to the board using SSH:

```bash
ssh ubuntu@10.42.0.217
```

---

##### Set up Internet sharing through the host PC

The board needs Internet access to install Kria packages, and the host PC will route the board traffic to the Internet.

---

###### Find the host Internet interface

On the host PC:

```bash
ip route | grep default
```

Example:

```text
default via 192.168.1.1 dev wlp2s0 proto dhcp metric 600
```

In this example, the Internet interface is:

```text
wlp2s0
```

Set the variables:

```bash
HOST_BOARD_IF=eno1
HOST_INTERNET_IF=$(ip route | awk '/default/ {print $5; exit}')

echo "Host-board interface: ${HOST_BOARD_IF}"
echo "Internet interface:   ${HOST_INTERNET_IF}"
```

Make sure `HOST_INTERNET_IF` is not the same as `HOST_BOARD_IF`.

---

###### Enable IPv4 forwarding on the host

On the host PC:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

Optional persistent setting:

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-kv260-ip-forward.conf
sudo sysctl --system
```
You can also perform this operation from Ubuntu's GUI, by going into ```Settings/Network```.

---

###### Add NAT forwarding rules on the host

On the host PC:

```bash
sudo iptables -t nat -C POSTROUTING -o ${HOST_INTERNET_IF} -j MASQUERADE 2>/dev/null || \
  sudo iptables -t nat -A POSTROUTING -o ${HOST_INTERNET_IF} -j MASQUERADE

sudo iptables -C FORWARD -i ${HOST_BOARD_IF} -o ${HOST_INTERNET_IF} -j ACCEPT 2>/dev/null || \
  sudo iptables -A FORWARD -i ${HOST_BOARD_IF} -o ${HOST_INTERNET_IF} -j ACCEPT

sudo iptables -C FORWARD -i ${HOST_INTERNET_IF} -o ${HOST_BOARD_IF} -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  sudo iptables -A FORWARD -i ${HOST_INTERNET_IF} -o ${HOST_BOARD_IF} -m state --state RELATED,ESTABLISHED -j ACCEPT
```

---

###### Configure gateway and DNS on the board

On the board:

```bash
sudo ip route replace default via 10.42.0.1 dev eth0

printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" | sudo tee /etc/resolv.conf
```

Test from the board:

```bash
ping -c 4 10.42.0.1
ping -c 4 8.8.8.8
ping -c 4 google.com
```

Interpretation:

```text
ping 10.42.0.1 fails     -> host-board Ethernet is not correct
ping 8.8.8.8 fails       -> host NAT/routing is not correct
ping google.com fails     -> DNS is not correct
```

Do not continue until the board can reach the Internet.

---

##### Install the required Kria packages and make the DPU available

The board must have the KV260 `benchmark-b4096` firmware application installed and loaded.

This firmware application provides the DPU needed by the compiled model.

---

###### Update package metadata

On the board:

```bash
sudo apt update
```

Search for the KV260 firmware packages:

```bash
apt search xlnx-firmware-kv260
```

You should see:

```text
xlnx-firmware-kv260-benchmark-b4096
```

If the package is visible, skip to section installation.

---

###### Initialize the Xilinx/Kria package sources if needed

If `xlnx-firmware-kv260-benchmark-b4096` is not found, initialize the Xilinx package setup:

```bash
sudo snap install xlnx-config --classic --channel=2.x
sudo xlnx-config.sysinit
sudo apt update
```

During this step, apt may ask what to do with a modified file such as:

```text
/etc/default/flash-kernel.oem-limerick-kria-meta
```

Choose:

```text
keep the local version currently installed
```

If apt was interrupted or reports a broken package state, run:

```bash
sudo dpkg --configure -a
sudo apt -f install
sudo apt update
```

If a dialog asks which services should be restarted, keep the default selections. Make sure `dfx-mgr.service` is selected. It is not necessary to restart display/session services such as `gdm`, `gdm3`, `dbus`, `systemd-logind`, or `user@*.service`.

If apt reports a pending kernel update, reboot after the installation finishes:

```bash
sudo reboot
```

After reboot, reconfigure the board Ethernet if the IP settings were temporary:

```bash
sudo ip addr flush dev eth0
sudo ip addr add 10.42.0.217/24 dev eth0
sudo ip link set eth0 up
sudo ip route replace default via 10.42.0.1 dev eth0
printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" | sudo tee /etc/resolv.conf
```

Then check again:

```bash
sudo apt update
apt search xlnx-firmware-kv260
```

---

###### Install the B4096 DPU firmware package

On the board:

```bash
sudo apt install -y xlnx-firmware-kv260-benchmark-b4096
```

If the services-restart dialog appears, keep the default selections and confirm with `<Ok>`. Make sure `dfx-mgr.service` is selected.

Restart the firmware manager:

```bash
sudo systemctl restart dfx-mgrd
```

List available accelerated applications:

```bash
sudo xmutil listapps
```

Expected: the list should include an application named similar to:

```text
kv260-benchmark-b4096
```

If the list still shows only:

```text
k26-starter-kits
```

then the DPU firmware package is not installed or not registered correctly.

---

###### Load the B4096 DPU application

On the board:

```bash
sudo xmutil unloadapp
sudo xmutil loadapp kv260-benchmark-b4096
```

Check the active application:

```bash
sudo xmutil listapps
```

Then check the DPU runtime:

```bash
xdputil query
show_dpu
```

Both commands must run without segmentation faults.

The DPU fingerprint expected by this tutorial package is:

```text
0x101000016010407
```

The compiled `.xmodel` in the repository is already prepared for this fingerprint. No manual DPU architecture editing is required. We are now ready to execute the target application we just built.

---

##### Copy the tutorial target package to the board

From the host PC, go to the directory containing the generated target archive:

```bash
ls -lh target_kv260.tar
```
By default, it is going to be under ```files/build```.

Copy it to the board:

```bash
scp target_kv260.tar ubuntu@10.42.0.217:/home/ubuntu/
```

Connect to the board:

```bash
ssh ubuntu@10.42.0.217
```

Extract it:

```bash
cd /home/ubuntu
rm -rf target_kv260
tar -xvf target_kv260.tar
```

---

##### Validate the target files before running

On the board:

```bash
cd /home/ubuntu/target_kv260/vcor
```

Check that the model exists:

```bash
ls -lh kv260_train_resnet18_vcor.xmodel
```

Check the model metadata:

```bash
xdputil xmodel kv260_train_resnet18_vcor.xmodel -l
```

Expected properties:

```text
DPU Arch:    DPUCZDX8G_ISA1_B4096_0101000016010407
fingerprint: 0x101000016010407
output shape: [1, 15]
```

Check the labels:

```bash
wc -l vcor_labels.dat
cat vcor_labels.dat
```

Expected:

```text
15 labels
```

The test images are generated by the target script, so they do not need to be manually copied separately.

---

##### Run the application

On the board:

```bash
cd /home/ubuntu/target_kv260
bash -x ./run_all_target.sh kv260
```

For a less verbose run:

```bash
bash ./run_all_target.sh kv260
```

A successful run should:

1. clean the target folders;
2. compile the C++ application on the board;
3. extract/build the test image directory;
4. run `cnn_resnet18_vcor`;
5. generate `rpt/predictions_vcor_resnet18.log`;
6. compute top-1/top-5 accuracy;
7. run the DPU FPS benchmark.

---

##### Useful manual test command

To run only the CNN executable manually:

```bash
cd /home/ubuntu/target_kv260/vcor

./cnn_resnet18_vcor \
  ./kv260_train_resnet18_vcor.xmodel \
  ./test/ \
  ./vcor_labels.dat \
  2>&1 | tee ./rpt/predictions_debug.log

echo "pipeline statuses: ${PIPESTATUS[@]}"
```

Expected:

```text
pipeline statuses: 0 0
```

The prediction log should contain prediction lines. If it contains only runtime errors, fix those before running the full script again.

---

##### Common checks

###### Host IP is wrong

Do not rely on:

```bash
hostname -i
```

It may print:

```text
127.0.1.1
```

Use:

```bash
hostname -I
ip -br addr
```

The host Ethernet interface connected to the board should be:

```text
10.42.0.1/24
```

---

###### Board cannot be pinged

On the host:

```bash
ip -br addr show eno1
cat /sys/class/net/eno1/carrier
ip route get 10.42.0.217
```

Expected:

```text
eno1 has 10.42.0.1/24
carrier is 1
route uses eno1
```

On the board:

```bash
ip -br addr show eth0
ip route
```

Expected:

```text
eth0 has 10.42.0.217/24
default route goes via 10.42.0.1
```

---

###### Board has no Internet

On the board:

```bash
ping -c 4 10.42.0.1
ping -c 4 8.8.8.8
ping -c 4 google.com
```

On the host:

```bash
sudo sysctl net.ipv4.ip_forward
sudo iptables -t nat -S
sudo iptables -S FORWARD
```

---

###### `xmutil listapps` shows only `k26-starter-kits`

Install and register the B4096 firmware package:

```bash
sudo apt install -y xlnx-firmware-kv260-benchmark-b4096
sudo systemctl restart dfx-mgrd
sudo xmutil listapps
```

---

###### `xdputil query` or `show_dpu` segfaults

The DPU application is not correctly loaded.

Run:

```bash
sudo xmutil listapps
sudo xmutil unloadapp
sudo xmutil loadapp kv260-benchmark-b4096
xdputil query
show_dpu
```

If it still fails, collect diagnostics:

```bash
dmesg -T | grep -Ei "dpu|xrt|zocl|xclbin|dfx|firmware|segfault|xilinx" | tail -100
```

---

###### Fingerprint mismatch

The model and the loaded DPU must have the same fingerprint.

Expected for this tutorial package:

```text
0x101000016010407
```

Check the model:

```bash
xdputil xmodel /home/ubuntu/target_kv260/vcor/kv260_train_resnet18_vcor.xmodel -l | grep fingerprint
```

Check the board DPU:

```bash
xdputil query | grep -i fingerprint
```

If they differ, use the `.xmodel` generated by the repository for the `benchmark-b4096` DPU package.

---

##### Compact command summary

###### Host PC

```bash
HOST_BOARD_IF=eno1
HOST_INTERNET_IF=$(ip route | awk '/default/ {print $5; exit}')

sudo ip addr flush dev ${HOST_BOARD_IF}
sudo ip addr add 10.42.0.1/24 dev ${HOST_BOARD_IF}
sudo ip link set ${HOST_BOARD_IF} up

sudo sysctl -w net.ipv4.ip_forward=1

sudo iptables -t nat -A POSTROUTING -o ${HOST_INTERNET_IF} -j MASQUERADE
sudo iptables -A FORWARD -i ${HOST_BOARD_IF} -o ${HOST_INTERNET_IF} -j ACCEPT
sudo iptables -A FORWARD -i ${HOST_INTERNET_IF} -o ${HOST_BOARD_IF} -m state --state RELATED,ESTABLISHED -j ACCEPT
```

###### Board

```bash
sudo ip addr flush dev eth0
sudo ip addr add 10.42.0.217/24 dev eth0
sudo ip link set eth0 up
sudo ip route replace default via 10.42.0.1 dev eth0
printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" | sudo tee /etc/resolv.conf

sudo apt update
sudo apt install -y xlnx-firmware-kv260-benchmark-b4096
sudo systemctl restart dfx-mgrd
sudo xmutil unloadapp
sudo xmutil loadapp kv260-benchmark-b4096

xdputil query
show_dpu
```

###### Copy and run

From the host:

```bash
scp target_kv260.tar ubuntu@10.42.0.217:/home/ubuntu/
```

On the board:

```bash
cd /home/ubuntu
rm -rf target_kv260
tar -xvf target_kv260.tar
cd target_kv260
bash -x ./run_all_target.sh kv260
```

#### 5.4.3 Generic Run-Time Execution Summary

It is possible and straight-forward to compile the application directly on the target (besides compiling it into the host computer environment).
In fact this is what the script [run_all_vcor_target.sh](files/target/vcor/run_all_vcor_target.sh)  does, when launched on the target.  

Turn on your target board and establish a serial communication with a ``putty`` terminal from Ubuntu or with a ``TeraTerm`` terminal from your Windows host PC.

Ensure that you have an Ethernet point-to-point cable connection with the correct IP addresses to enable ``ssh`` communication in order to quickly transfer files to the target board with ``scp`` from Ubuntu.

Once a ``tar`` file of the ``build/target_kv260``  folder has been created, copy it from the host PC to the target board. For example, in case of an Ubuntu PC, use the following command:
```
scp target_kv260.tar ubuntu@{board_IP}~/
```

From the target board terminal, run the following commands (in case of kv260):
```
tar -xvf target_kv260.tar
cd target_kv260
bash -x ./run_all_target.sh kv260
```


The application based on VART C++ APIs is built with the [build_app.sh](files/target/vcor/code/build_app.sh) script and finally launched for each CNN, the effective top-5 classification accuracy is checked by a python script [check_runtime_top5_vcor.py](files/target/code/src/check_runtime_top5_vcor.py) which is launched from within
the [vcor_performance.sh](files/target/vcor/vcor_performance.sh) script.

Note that the test images were properly prepared with the [generate_target_test_images.py](files/code/generate_target_test_images.py) script
in order to append the class name to the image file name, thus enabling the usage of [check_runtime_top5_vcor.py](files/target/vcor/code/src/check_runtime_top5_vcor.py)
to check the prediction accuracy.



#### 5.4.4 DPU Performance

On the KV260 board, the purely DPU performance (not counting the CPU tasks) measured in fps is:

-  ~200 fps with 1 thread,  

- ~244 fps fps with 3 threads.


The prediction accuracy is:

```
...
number of total images predicted  300
number of top1 false predictions  41
number of top1 right predictions  259
number of top5 false predictions  4
number of top5 right predictions  296
top1 accuracy = 0.96
top5 accuracy = 0.99
...
```




<div style="page-break-after: always;"></div>


<!-- ## License

The MIT License (MIT)

Copyright © 2023 Advanced Micro Devices, Inc. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


<p align="center"><sup>XD106 | © Copyright 2022 Xilinx, Inc.</sup></p> -->
