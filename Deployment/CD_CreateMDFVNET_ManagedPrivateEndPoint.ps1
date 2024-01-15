
if($env:SynapseFunctionMPE_Create -eq "True")
{

$synapseWorkspaceVar= "${env:resource_prefix}syn${env:resource_suffix}"

$FunctionApp = Get-AzFunctionApp -ResourceGroupName $env:ResouceGroup_Name -Name "${env:resource_prefix}functionapp${env:resource_suffix}"
$FunctionAppId = $FunctionApp.Id
Write-Host "Creating managed private end point to Azure function"
$createPrivateEndpointJsonString = @"
{    
    "properties": {
        "privateLinkResourceId": "$FunctionAppId",
        "groupId": "sites"
    }
}
"@


Write-Host $createPrivateEndpointJsonString

$tempFolderPath = ".\temp"

if (!(Test-path -path $tempFolderPath)) { 
    Write-Host "new file"
    New-Item -ItemType directory -path $tempFolderPath
}

Write-Host "creating the PrivateEndpoint Definition Json file...."
$jsonpath = ".\$tempFolderPath\createprivateendpoint.json"

Set-Content -Path $jsonpath -value $createPrivateEndpointJsonString

Write-Host "Creating new Managed Private Endpoint from Synapse to Azure function..."
New-AzSynapseManagedPrivateEndpoint `
-WorkspaceName $synapseWorkspaceVar `
-Name "managedPrivateEndpointAzureFunction" `
-DefinitionFile $jsonpath
    

$FunctionApp = Get-AzFunctionApp -ResourceGroupName $env:ResouceGroup_Name -Name $env:FunctionApp_Name
Write-Host "Function App is $FunctionApp"
$FunctionAppId = $FunctionApp.Id
Write-Host "Function App id is $FunctionAppId"
$FunctionApp_epc = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $FunctionAppId | Where-Object {($_.PrivateLinkServiceConnectionState.Status -like "Pending")}
Write-Host "Function App EPC is $FunctionApp_epc"
Write-Host "Waiting for 90 seconds"
sleep 90
$FunctionApp_epc = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $FunctionAppId | Where-Object {($_.PrivateLinkServiceConnectionState.Status -like "Pending")}
Write-Host "Function App EPC is $FunctionApp_epc"
if($FunctionApp_epc)
{
Write-Host "Approve managed private end point connection from Synapse to the Azure functions"
Approve-AzPrivateEndpointConnection -ResourceId $FunctionApp_epc.Id
}
$subid = (az account show -s $env:ResourceGroup_Subscription | ConvertFrom-Json).id
Write-Host "Creating managed private end point to blob storage account"

$StoragePrivateLinkResource = Get-AzStorageAccount -ResourceGroupName $env:ResouceGroup_Name -Name $env:StorageAccount_Name
$StoragePrivateLinkResourceId = $StoragePrivateLinkResource.Id
$createPrivateEndpointJsonString = @"
{    
    "properties": {
        "privateLinkResourceId": "$StoragePrivateLinkResourceId",
        "groupId": "blob"
    }
}
"@

Write-Host $createPrivateEndpointJsonString

$tempFolderPath = ".\temp"

if (!(Test-path -path $tempFolderPath)) { 
    Write-Host "new file"
    New-Item -ItemType directory -path $tempFolderPath
}

Write-Host "creating the PrivateEndpoint Definition Json file...."
$jsonpath = ".\$tempFolderPath\createprivateendpoint.json"

Set-Content -Path $jsonpath -value $createPrivateEndpointJsonString

Write-Host "Creating new Managed Private Endpoint from Synapse to blob storage account..."
New-AzSynapseManagedPrivateEndpoint `
-WorkspaceName $synapseWorkspaceVar `
-Name "${env:StorageAccount_Name}-blob" ` `
-DefinitionFile $jsonpath
Write-Host "Waiting for 90 seconds"
sleep 90

$StorageAcc_epc = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $StoragePrivateLinkResourceId | Where-Object {($_.PrivateLinkServiceConnectionState.Status -like "Pending")}
if($StorageAcc_epc)
{
Write-Host "Storage Account EPC is $StorageAcc_epc"
Write-Host "Approve managed private end point connection from Synapse to the blob storage account"
Approve-AzPrivateEndpointConnection -ResourceId $StorageAcc_epc.Id
}
}
