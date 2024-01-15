#script that will generate JSON files with all folders in source container with their metadata
#***********************************************************************************************************************
#**  Name:                   StorageAccountContainerCopy
#**  Desc:                   #script that will read JSON files and create folders with metadata as it is in JSON 
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
import json
import os

#####################################VARIABLE INITIALIZATION#########################################################
TargetStorageAccount=os.environ.get('TargetStorageAccount')
TargetContainer=os.environ.get('TargetContainer')
TargetStorageAccountSaSToken = os.environ.get('TargetStorageAccountSaSToken')
ReplaceMetadataIfFolderExists = os.environ.get('ReplaceMetadataIfFolderExists')

f = open('WS-DT-ADLS-Dev-Build/drop/Metadata.json')
  
# returns JSON object as 
# a dictionary
data = json.load(f)
  
# Iterating through the json
# list
#Target_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(TargetStorageAccount),credential=credential2)
Target_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(TargetStorageAccount),credential=TargetStorageAccountSaSToken)
datalake_service_client = DataLakeServiceClient("https://{}.dfs.core.windows.net".format(TargetStorageAccount),
                                                   credential=TargetStorageAccountSaSToken)
file_system_client = datalake_service_client.get_file_system_client(TargetContainer) 


target_conn_str="DefaultEndpointsProtocol=http;SharedAccessSignature="+TargetStorageAccountSaSToken+";BlobEndpoint=https://{}.dfs.core.windows.net/;".format(TargetStorageAccount)

for x in range(len(data)):
    #a = Source_blob_client.get_blob_properties()
    FolderMetadataDict = data[x]['FolderMetadata']
    print(data[x]['FolderPath'])
    TargetBlob = BlobClient.from_connection_string(conn_str=target_conn_str, container_name=TargetContainer, blob_name=data[x]['FolderPath'])
    if not (TargetBlob.exists()): #if not found in target container create new directory with metadata of source
        #directory_client = file_system_client.create_directory(data[x]['FolderPath'],metadata=data[x]['FolderMetadata'])  
        directory_client = file_system_client.create_directory(data[x]['FolderPath'],metadata=FolderMetadataDict)  
    else:
        if ReplaceMetadataIfFolderExists == 'True': 
            Target_blob_client = Target_blob_service_client.get_blob_client(container=TargetContainer, blob=data[x]['FolderPath'])
            #Target_blob_client.get_blob_properties().metadata.pop('hdi_isfolder')
            FolderMetadataDict.pop('hdi_isfolder')
            Target_blob_client.set_blob_metadata(metadata=FolderMetadataDict)
f.close()