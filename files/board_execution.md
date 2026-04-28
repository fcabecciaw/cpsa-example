# KV260 / Kria Setup for Running the Vitis AI ResNet18 Tutorial

This tutorial explains how to prepare a Kria KV260 board to run the generated Vitis AI target application.

The flow is:

1. connect to the board;
2. configure a direct Ethernet link between host PC and board;
3. share the host PC Internet connection with the board;
4. install the required Kria firmware/runtime packages;
5. load the `benchmark-b4096` DPU application;
6. copy the target package to the board;
7. run the application.

The repository is assumed to already contain everything needed on the application side, including the target files and an `.xmodel` compiled for the DPU fingerprint used by the `benchmark-b4096` Kria application.

---

## Prerequisites

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

# 1. Connect to the board

## 1.1 Connect the cables

Connect:

1. USB-UART cable from host PC to the Kria board;
2. Ethernet cable from host PC to the Kria board;
3. Kria power supply.

The USB-UART connection is used for first access and recovery.
The Ethernet connection is used for SSH, SCP, and Internet sharing.

---

## 1.2 Open the serial console

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
In this case the serial device is /dev/ttyUSB1, meaning we can connect to the board with:

```bash
sudo putty -serial /dev/ttyUSB1 -sercfg 115200,8,n,1,N
```

If your device is different, replace `/dev/ttyUSB0` accordingly.

Log in as:

```text
user: ubuntu
pw: cpsa2026
```

If needed, set or reset the password from the serial console:

```bash
sudo passwd ubuntu
```

---

## 1.3 Configure the direct Ethernet link

### On the host PC

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

### On the board, through serial console

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

### IP subnet note

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


## 1.4 Check that host and board can see each other

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

# 1.1. Set up Internet sharing through the host PC

The board needs Internet access to install Kria packages. The host PC will route the board traffic to the Internet.

This is not a hardware bridge; it is Internet sharing through IP forwarding and NAT.

---

## 1.1.1 Find the host Internet interface

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

## 1.1.2 Enable IPv4 forwarding on the host

On the host PC:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

Optional persistent setting:

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-kv260-ip-forward.conf
sudo sysctl --system
```

---

## 1.1.3 Add NAT forwarding rules on the host

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

## 1.1.4 Configure gateway and DNS on the board

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

# 2. Install the required Kria packages and make the DPU available

The board must have the KV260 `benchmark-b4096` firmware application installed and loaded.

This firmware application provides the DPU needed by the compiled model.

---

## 2.1 Update package metadata

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

If the package is visible, skip to section 2.3.

---

## 2.2 Initialize the Xilinx/Kria package sources if needed

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

## 2.3 Install the B4096 DPU firmware package

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

## 2.4 Load the B4096 DPU application

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

The compiled `.xmodel` in the repository is already prepared for this fingerprint. No manual DPU architecture editing is required.

---

# 3. Copy the tutorial target package to the board

From the host PC, go to the directory containing the generated target archive:

```bash
ls -lh target_kv260.tar
```

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

# 4. Validate the target files before running

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

# 5. Run the application

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

# 6. Useful manual test command

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

# 7. Common checks

## 7.1 Host IP is wrong

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

## 7.2 Board cannot be pinged

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

## 7.3 Board has no Internet

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

## 7.4 `xmutil listapps` shows only `k26-starter-kits`

Install and register the B4096 firmware package:

```bash
sudo apt install -y xlnx-firmware-kv260-benchmark-b4096
sudo systemctl restart dfx-mgrd
sudo xmutil listapps
```

---

## 7.5 `xdputil query` or `show_dpu` segfaults

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

## 7.6 Fingerprint mismatch

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

# 8. Compact command summary

## Host PC

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

## Board

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

## Copy and run

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

