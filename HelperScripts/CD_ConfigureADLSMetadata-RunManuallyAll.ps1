#script that will go to all folders in landing and add metadata variables to all folders and subfolders inside
$ADLSMetadata_Enable = "True"
$ADLSMetadata_Container = "landing"
$StorageAccount_Name = "[Your Data lake name]"
Write-Host "Configure ADLS Metadata"
if($ADLSMetadata_Enable -eq "True")
{
    Write-Host "Setting up metadata variables for the ADLS container folders.."
    $containerName = $ADLSMetadata_Container

    #Create a context object using Azure AD credentials
    $ctx = New-AzStorageContext -StorageAccountName $StorageAccount_Name -UseConnectedAccount
    #list all folders in the container
    $folder = Get-AzStorageBlob -Container $containerName -Context $ctx | Where-Object {($_.Length -like 0)}
    #$folder = Get-AzStorageBlob -Container $containerName -Context $ctx | Where-Object {($_.ContentType -like '*octet-stream')}


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
 
