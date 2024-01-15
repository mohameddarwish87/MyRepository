#script that will copy all metadata of folders from source container to target containers and create corresponding folder if not exists. if already exists you have choice either to overwrite its metadata or leave it as is
from azure.storage.filedatalake import DataLakeServiceClient 
from azure.identity import ClientSecretCredential
from azure.storage.blob import BlobServiceClient
from azure.storage.blob import BlobServiceClient
from azure.storage.blob import BlobClient
import os

SourceStorageAccount=os.environ.get('SourceStorageAccount')#"sandbxdevadls"
TargetStorageAccount=os.environ.get('TargetStorageAccount')#"sandbxtestadls"
SourceContainer=os.environ.get('SourceContainer')#"staging"
TargetContainer=os.environ.get('TargetContainer')#"staging"kkkk
Client_id=""
Client_Secret=""
Tenant_id=""
ReplaceMetadataIfFolderExists = 'False'
SourceStorageAccountAccessKey = ""
TargetStorageAccountAccessKey = ""
SourceStorageAccountSaSToken = os.environ.get('SourceStorageAccountSaSToken')#"?sv=2021-06-08&ss=bfqt&srt=sco&sp=rwdlacupx&se=2022-06-28T08:55:22Z&st=2022-06-21T00:54:22Z&spr=https&sig=jNZflxF0ERH5QorBgHKDRDFitmxoZ8h0EdNt4FYSgvU%3D"
TargetStorageAccountSaSToken = os.environ.get('TargetStorageAccountSaSToken')#"?sv=2021-06-08&ss=bfqt&srt=sco&sp=rwdlacupx&se=2022-06-28T08:52:51Z&st=2022-06-21T00:00:51Z&spr=https&sig=YapOBpAHUllDdgKspw%2B60wufk1TSfeQSxQD4Dpopths%3D"

#credential2 = ClientSecretCredential(client_id=Client_id,client_secret=Client_Secret,tenant_id=Tenant_id)


#Reading from Source container
#Source_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(SourceStorageAccount),credential=credential2)
#Source_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(SourceStorageAccount),credential=sas_token)
#Source_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(SourceStorageAccount),credential=SourceStorageAccountAccessKey)
Source_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(SourceStorageAccount),credential=SourceStorageAccountSaSToken)
Source_container_client = Source_blob_service_client.get_container_client(SourceContainer)
Sourceblobs = Source_container_client.list_blobs() #list all blobs in Source Containers




#target_conn_str="DefaultEndpointsProtocol=http;AccountName="+TargetStorageAccount+";AccountKey=" \
#           +TargetStorageAccountAccessKey+ \
#           ";BlobEndpoint=https://{}.dfs.core.windows.net/;".format(TargetStorageAccount)
#Target_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(TargetStorageAccount),credential=credential2)
#Target_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(TargetStorageAccount),credential=TargetStorageAccountAccessKey)
Target_blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(TargetStorageAccount),credential=TargetStorageAccountSaSToken)
Target_container_client = Target_blob_service_client.get_container_client(TargetContainer)
#datalake_service_client = DataLakeServiceClient("https://{}.dfs.core.windows.net".format(TargetStorageAccount),credential=credential2)
#datalake_service_client = DataLakeServiceClient("https://{}.dfs.core.windows.net".format(TargetStorageAccount),credential=TargetStorageAccountAccessKey)
datalake_service_client = DataLakeServiceClient("https://{}.dfs.core.windows.net".format(TargetStorageAccount),credential=TargetStorageAccountSaSToken)
file_system_client = datalake_service_client.get_file_system_client(TargetContainer)  

for blob in Sourceblobs:
    txt = blob.name
    Source_blob_client = Source_blob_service_client.get_blob_client(container=SourceContainer, blob=txt) #create blob client for the blob of where file is landed
    a = Source_blob_client.get_blob_properties()
    if txt.find('.') == -1: # if blob detected is folder check if it is present in target container
        #TargetBlob = BlobClient.from_connection_string(conn_str=target_conn_str, container_name=TargetContainer, blob_name=txt)
        TargetStorageAccountSaSURL ="https://"+TargetStorageAccount+".blob.core.windows.net/"+TargetContainer+"/"+txt+TargetStorageAccountSaSToken
        print(TargetStorageAccountSaSURL)
        TargetBlob = BlobClient.from_blob_url(TargetStorageAccountSaSURL)
        print(TargetBlob)
        if not (TargetBlob.exists()): #if not found in target container create new directory with metadata of source
            directory_client = file_system_client.create_directory(txt,metadata=a.metadata)   
        else:
            if ReplaceMetadataIfFolderExists == 'True': #determine if folder already presents whether to replace its metadata with source metadata or leave it as is
                Target_blob_client = Target_blob_service_client.get_blob_client(container=TargetContainer, blob=txt)
                a.metadata.pop('hdi_isfolder') #removing metadata hid_isfolder as by default it is already there so make sure no duplicates otherwise it will fail
                Target_blob_client.set_blob_metadata(metadata=a.metadata)
