Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
Install-Module -Name Az -AllowClobber
#Install-Module -Name Az.Accounts -AllowClobber
#Install-Module -Name Az.Resources -AllowClobber
Install-Module sqlserver 
#Install-Module -Name Az.KeyVault -AllowClobber
#Install-Module -Name Az.Storage -AllowClobber
#Install-Module -Name Az.Functions -AllowClobber
#Install-Module -Name Az.Synapse -AllowClobber
#Install-Module -Name AzureAD -AllowClobber
#Install-Module Az.PrivateDns -Force
#Install-Module Az.Network
