#script that will generate JSON files with all folders in source container with their metadata
#***********************************************************************************************************************
#**  Name:                   StorageAccountContainerCopy
#**  Desc:                   #script that will generate JSON files with all folders in source container with their metadata
#**  Auth:                   M Darwish
#**  Date:                   03/12/2022
#**
#**  Change History
#**  --------------
#**  No.     Date            Author              Description
#**  ---     ----------      -----------         ---------------------------------------------------------------
#**  1       03/12/2022      M Darwish           Original Version

from azure.storage.filedatalake import DataLakeServiceClient 
from azure.identity import ClientSecretCredential
from azure.storage.blob import BlobServiceClient
from azure.storage.blob import BlobServiceClient
from azure.storage.blob import BlobClient
import os
import json
#####################################VARIABLE INITIALIZATION#########################################################
SourceStorageAccount=os.environ.get('SourceStorageAccount')
SourceContainer=os.environ.get('SourceContainer')
SourceStorageAccountSaSToken = os.environ.get('SourceStorageAccountSaSToken')
print("Source blob is "+SourceStorageAccount)

#Reading from Source container
#Source_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(SourceStorageAccount),credential=credential2)
Source_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(SourceStorageAccount),credential=SourceStorageAccountSaSToken)
Source_container_client = Source_blob_service_client.get_container_client(SourceContainer)
Sourceblobs = Source_container_client.list_blobs() #list all blobs in Source Containers
for Sourceblob in Sourceblobs: 
    print("Source blob is "+Sourceblob.name) 

Sourceblobs = Source_container_client.list_blobs()
new_dict =[]  #final dictionary that wil be written to JSON file
print("new_dict is ",new_dict)
for blob in Sourceblobs: 
    new_dict_stage ={} #dict act as staging to hold current loop run value
    txt = blob.name
    print(txt)
    Source_blob_client = Source_blob_service_client.get_blob_client(container=SourceContainer, blob=txt) #create blob client for the blob of where file is landed
    if txt.find('.') == -1: # if blob detected is folder check if it is present in target container
        a = Source_blob_client.get_blob_properties()
        new_dict_stage["FolderPath"] = blob.name
        new_dict_stage["FolderMetadata"] = a.metadata
        new_dict.append(new_dict_stage)
print(new_dict)
jsonString = json.dumps(new_dict)
jsonFile = open("Metadata.json", "w")
jsonFile.write(jsonString)
jsonFile.close()
