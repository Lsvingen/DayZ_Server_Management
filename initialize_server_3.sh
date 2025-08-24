#!/bin/bash

# Enable SSH, restrictions for management are done via NSG from the Terraform deployment
# Install dependencies
sudo apt install openssh-server -y
sudo apt install lib32gcc-s1 -y
sudo snap install powershell --classic

# Install PowerShell modules for administration
sudo powershell -command "Install-Module Az -Force"
sudo powershell -command "Install-Module Graph.Beta -Force"
sudo powershell -command "Install-Module ExchangeOnlineManagement -Force"
sudo powershell -command "Install-Module MicrosoftTeams -Force"