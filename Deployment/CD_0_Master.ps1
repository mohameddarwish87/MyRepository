#$a = pwsh --version
$b = get-command Invoke-Sqlcmd | Select Version
Write-Host "Powershell Version: $a" 
Write-Host "Invoke-Sqlcmd Version: $b"
Write-Host "SP_Client_ID: ${env:SP_CLIENT_ID}"
Write-Host "SP_Client_Secret: ${env:SP_CLIENT_SECRET}"
Write-Host "SP_Tenant_ID: ${env:SP_TENANT_ID}"
# Before running you must create service principal and add it as owner to the resource group
# Password of sqladminuser of synapse serverless DB must be more than 8 characters with numbers and alph and special character
# after synapse creation make sure SP is synapse administrator of synapse
# Make sure names of azure resources are uniques and havent used before
az login --service-principal -u ${env:SP_CLIENT_ID} -p ${env:SP_CLIENT_SECRET} --tenant ${env:SP_TENANT_ID}
#Install-Module -Name Az.Accounts -RequiredVersion 1.6.2 -Force
#Import-Module -Name Az -AllowClobber -Force
#Install-Module -Name Az.Resources -AllowClobber -Force
#Install-Module sqlserver
#Import-Module -Name AzureAD -Force
#Import-Module -Name Az -AllowClobber -Force
#Install-Module -Name Az.Accounts -AllowClobber -Force
#Install-Module -Name Az.Resources -AllowClobber -Force
#Install-Module Az.PrivateDns -Force
#Connect-AzAccount -TenantId ${env:SP_TENANT_ID}
Write-Host "Connected to Tenant: ${env:SP_TENANT_ID}"
#Install-Module -Name Az -AllowClobber -Force#-Scope CurrentUser -Repository PSGallery -Force -SkipPublisherCheck
$azurePassword = ConvertTo-SecureString ${env:SP_CLIENT_SECRET} -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ${env:SP_CLIENT_ID}, $azurePassword
Connect-AzAccount -ServicePrincipal -TenantId ${env:SP_TENANT_ID} -Credential $Credential
Write-Host "Connected to Tenant: ${env:SP_TENANT_ID}"
Invoke-Expression -Command  "Deployment/CD_CreateMDFResourceGroup.ps1"
Write-Host "1.."
Invoke-Expression -Command  "Deployment/CD_CreateMDFVNET_NSG_VM.ps1"
Write-Host "1.1.."
Invoke-Expression -Command  "Deployment/CD_CreateMDFKeyVault.ps1"
Invoke-Expression -Command  "Deployment/CD_CreateMDFKeyVault_VNET.ps1"
Write-Host "2.."
Invoke-Expression -Command  "Deployment/CD_CreateMDFStorageBlob.ps1"
Invoke-Expression -Command  "Deployment/CD_CreateMDFStorageBlob_VNET.ps1"
Write-Host "3.."
Invoke-Expression -Command  "Deployment/CD_CreateMDFFunctionApp.ps1"
Invoke-Expression -Command  "Deployment/CD_CreateMDFFunctionApp_VNET.ps1"
Write-Host "4.."
Invoke-Expression -Command  "Deployment/CD_CreateMDFSynapseApp.ps1"
Invoke-Expression -Command  "Deployment/CD_CreateMDFSynapseApp_VNET.ps1"
Write-Host "5.."
Invoke-Expression -Command  "Deployment/CD_CreateMDFVNET_ManagedPrivateEndPoint.ps1"
Write-Host "6.."
Invoke-Expression -Command  "Deployment/CD_ConfigureMDFFunctionApp.ps1"
Write-Host "7.."
Invoke-Expression -Command  "Deployment/CD_CreateMDFVNET_FunctionappPrivateEndPoint.ps1"
Write-Host "8.."
#Invoke-Expression -Command  "Deployment/CD_ConfigureADLSMetadata.ps1"
Invoke-Expression -Command  "Deployment/CD_GrantRBAC.ps1"
Write-Host "9.."
Invoke-Expression -Command  "Deployment/CD_CreateDataverseLandingZone_VNET.ps1"
Write-Host "10.."
#**
