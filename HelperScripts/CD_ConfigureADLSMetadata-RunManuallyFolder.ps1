#script that will go to a specific folder in landing and add metadata variables to it
$ADLSMetadata_Enable = "True"
$ADLSMetadata_Container = "datalakelanding"
$StorageAccount_Name = "[Your Data lake name]"
$ADLSMetadata_Path = "[Your Data Lake]/SalesLT/ProductModel"
$CLIENT_ID = ""
#$CLIENT_SECRET = ""
#$TENANT_ID = ""
$Access_Key = ""
$ResourceGroup_Subscription = "rg-syd-dev-adp"
$subid = (az account show -s $ResourceGroup_Subscription | ConvertFrom-Json).id
$azureAppCred = (New-Object System.Management.Automation.PSCredential $CLIENT_ID,  ($CLIENT_SECRET | ConvertTo-SecureString -AsPlainText -Force))
Write-Host $azureAppCred


if($ADLSMetadata_Enable -eq "True")
{
    Write-Host "Setting up metadata variables for the ADLS container folders.."
    $containerName = $ADLSMetadata_Container

    $ctx = New-AzStorageContext -StorageAccountName $StorageAccount_Name -StorageAccountKey $Access_Key #$StorageAccount_Name -UseConnectedAccount
    #list all folders in the container
    $folder = Get-AzStorageBlob -Container $containerName -Context $ctx | Where-Object {($_.Name -like $ADLSMetadata_Path)}


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
 
