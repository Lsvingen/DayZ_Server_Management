#!/bin/bash

# Enable SSH, restrictions for management are done via NSG from the Terraform deployment
# Install dependencies
sudo apt install openssh-server -y
sudo apt install lib32gcc-s1 -y
sudo apt install powershell -y