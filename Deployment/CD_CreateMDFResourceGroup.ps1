
#Write-Host "Running Deploy MDDF RG...."
if($env:ResourceGroup_Enable -eq "True")
{
    $RG = Get-AzResourceGroup  -Name $env:ResouceGroup_Name
    if ($null -eq $RG) 
    {
        Write-Host "Creating Resource Group.."
        az group create --name $env:ResouceGroup_Name --location $env:ResourceGroup_Location
        Write-Host "Creating Resource Group - completed"
    }
    else
    {
        Write-Host "$env:ResouceGroup_Name exists"
    }
}
