#Write-Host "Running Configure ADLS Metadata script..."
if($env:ADLSMetadata_Enable -eq "True")
{
    Write-Host "Setting up metadata variables for the ADLS container folders.."
    $containerName = $env:ADLSMetadata_Container
    Write-Host "Enable?: $env:ADLSMetadata_Enable"
    Write-Host "ContainerName: $containerName"
    Write-Host "StorageAccountName: $env:StorageAccount_Name"
    $ctx = New-AzStorageContext -StorageAccountName $env:StorageAccount_Name -UseConnectedAccount
    Write-Host "ctx: $ctx"
    #list all folders in the container
    $folder = Get-AzStorageBlob -Container $containerName -Context $ctx | Where-Object {($_.Length -like 0)}
    Write-Host "folders: $folder"

    #Create IDictionary, add key-value metadata pairs to IDictionary
    $metadata = New-Object System.Collections.Generic.Dictionary"[String,String]"
    $metadata.Add("businesskey1","")
    $metadata.Add("businesskey2","")
    $metadata.Add("businesskey3","")
    $metadata.Add("businesskey4","")
    $metadata.Add("businesskey5","")
    $metadata.Add("businesskey6","")
    $metadata.Add("businesskey7","")
    $metadata.Add("datepartitionpath","YYYY\MM\DD")
    $metadata.Add("incrementalload","False")
    $metadata.Add("partitionkey","")
    $metadata.Add("pushtostagingzone","False")
    $metadata.Add("pushtocuratedzone","False")
    $metadata.Add("scd2flag","False")
    $metadata.Add("watermarkcol","")

    #Update metadata
    $folder.BlobClient.SetMetadata($metadata, $null)

    $folder = $null
    $folder = Get-AzStorageBlob -Container $containerName -Context $ctx

}
 
