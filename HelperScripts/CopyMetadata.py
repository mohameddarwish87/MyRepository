#script that will copy all metadata of folders from source container to target containers and create corresponding folder if not exists. if already exists you have choice either to overwrite its metadata or leave it as is
from azure.storage.filedatalake import DataLakeServiceClient 
from azure.identity import ClientSecretCredential
from azure.storage.blob import BlobServiceClient
from azure.storage.blob import BlobServiceClient
from azure.storage.blob import BlobClient

SourceStorageAccount="[Your source account name]"
TargetStorageAccount="[Your target account name]"
SourceContainer="datalakelanding"
TargetContainer="landing"
Client_id=""
Client_Secret=""
Tenant_id=""
ReplaceMetadataIfFolderExists = 'False'
credential2 = ClientSecretCredential(client_id=Client_id,client_secret=Client_Secret,tenant_id=Tenant_id)


#Reading from Source container
Source_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(SourceStorageAccount),credential=credential2)
Source_container_client = Source_blob_service_client.get_container_client(SourceContainer)
Sourceblobs = Source_container_client.list_blobs() #list all blobs in Source Containers



TargetStorageAccountAccessKey =""
target_conn_str="DefaultEndpointsProtocol=http;AccountName="+TargetStorageAccount+";AccountKey=" \
           +TargetStorageAccountAccessKey+ \
           ";BlobEndpoint=https://{}.dfs.core.windows.net/;".format(TargetStorageAccount)
Target_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(TargetStorageAccount),credential=credential2)
Target_container_client = Target_blob_service_client.get_container_client(TargetContainer)
datalake_service_client = DataLakeServiceClient("https://{}.dfs.core.windows.net".format(TargetStorageAccount),
                                                   credential=credential2)
file_system_client = datalake_service_client.get_file_system_client(TargetContainer)  

for blob in Sourceblobs:
    txt = blob.name
    Source_blob_client = Source_blob_service_client.get_blob_client(container=SourceContainer, blob=txt) #create blob client for the blob of where file is landed
    a = Source_blob_client.get_blob_properties()
    if txt.find('.') == -1: # if blob detected is folder check if it is present in target container
        TargetBlob = BlobClient.from_connection_string(conn_str=target_conn_str, container_name=TargetContainer, blob_name=txt)
        if not (TargetBlob.exists()): #if not found in target container create new directory with metadata of source
            directory_client = file_system_client.create_directory(txt,metadata=a.metadata)   
        else:
            if ReplaceMetadataIfFolderExists == 'True': #determine if folder already presents whether to replace its metadata with source metadata or leave it as is
                Target_blob_client = Target_blob_service_client.get_blob_client(container=TargetContainer, blob=txt)
                a.metadata.pop('hdi_isfolder') #removing metadata hid_isfolder as by default it is already there so make sure no duplicates otherwise it will fail
                Target_blob_client.set_blob_metadata(metadata=a.metadata)
