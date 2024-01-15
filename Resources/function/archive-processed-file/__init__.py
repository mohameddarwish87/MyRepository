#***********************************************************************************************************************
#**  Name:                   archive-processed-file Azure Function
#**  Desc:                   This function is responsible to move file from landing to corresponding path in raw zone with date partition
#**                          filename with its path and account name is passed as HTTP get request to the function
#**                          Ex: https://intergen-data-mdp-function-dev.azurewebsites.net/api/archive-processed-file?filename=AdventureWorks/Person/Person/Person1.parquet&storage_account=intergendatamdpadlsdev
#**  Auth:                   J Grata
#**  Date:                   02/11/2021
#**
#**  Change History
#**  --------------
#**  No.     Date            Author              Description
#**  ---     ----------      -----------         ---------------------------------------------------------------
#**  1       01/11/2021      J Grata             Original Version
#**  2       09/12/2021      M Darwish           using KV to access accountkey, remove archived from raw landing path, changing format of UTC for filename, removing for loop to get metadata
#**  3       09/02/2022      M Darwish           Using Variables of app settings instead of local variables
#**  4       05/04/2022      M Darwish           Remove date timestamp from file suffix of raw zone as ADS go fast is already adding its date timestamp to the file landed
#**  5       13/05/2022      W Viviers           Change the arcive folders so the month and day sub folders will always be 2 digits.
import logging
import azure.functions as func
import pandas as pd
import os
from datetime import datetime
from azure.storage.blob import BlobServiceClient, ContainerClient
from azure.storage.filedatalake import (
DataLakeServiceClient,
)
import os, uuid, sys
from azure.storage.filedatalake import DataLakeServiceClient
from azure.core._match_conditions import MatchConditions
from azure.storage.filedatalake._models import ContentSettings
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
from azure.identity import ClientSecretCredential , ManagedIdentityCredential

def main(req: func.HttpRequest) -> func.HttpResponse:
    #KeyVault_Name = os.environ["KeyVault_Name"]
    StorageAccount_LandingContainer = os.environ["StorageAccount_LandingContainer"]
    StorageAccount_RawContainer = os.environ["StorageAccount_RawContainer"]
    StorageAccount_Name = os.environ["StorageAccount_Name"]
    #StorageAccount_AccessKey = os.environ["KeyVault_StorageAccount_AccessKey"]
    #KVUri = "https://{}.vault.azure.net/".format(KeyVault_Name)
    #credential1 = DefaultAzureCredential() #will use managed identity enabled to authenticate azure function to access KV
    managed_identity_credential = ManagedIdentityCredential()
    #client = SecretClient(vault_url=KVUri, credential=credential1)#creating secret client to access KV to read credential of service principal

    #GET PASSED  PARAMETERS

    filename = req.params.get('filename')

    if not filename:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            filename = req_body.get('filename')
    storage_account = req.params.get('storage_account') 
    if not storage_account:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
           
        else:
            storage_account = req_body.get('storage_account')

    account_url=f"https://{storage_account}.dfs.core.windows.net"
    blob_url=f"https://{storage_account}.blob.core.windows.net"
        
    #ACCESS BL
    ##conn_str="DefaultEndpointsProtocol=http;AccountName={};AccountKey={};BlobEndpoint={}/;".format(storage_account,StorageAccount_AccessKey,blob_url)
 
    #GET METADATA FROM FILENAME
    ##date_partition = get_metadata(conn_str,StorageAccount_LandingContainer,filename)
    date_partition = get_metadata(StorageAccount_LandingContainer,filename,managed_identity_credential,StorageAccount_Name)

    #Access storage account to move files
    ##initialize_datalakeservice(account_url, StorageAccount_AccessKey)
    initialize_datalakeservice(account_url, managed_identity_credential)
    move_directory(filename, StorageAccount_LandingContainer, date_partition,StorageAccount_RawContainer)

    if filename and storage_account:
        return func.HttpResponse(f"Successfully archived {filename}. This HTTP triggered function executed successfully.")
    else:
        return func.HttpResponse(
             "This HTTP triggered function execution failed. Please pass a \'filename\' and a \'storage_account\' name in the query string or in the request body.",
             status_code=404)

#def get_metadata(conn_str,container_name,filename):
def get_metadata(container_name,filename,managed_identity_credential,StorageAccount_Name):
    #container_client=ContainerClient.from_connection_string(conn_str,container_name)
    ##container_client=ContainerClient.from_connection_string("https://{}.blob.core.windows.net".format(StorageAccount_Name),container_name,credential=managed_identity_credential)
    #blob_service_client = BlobServiceClient.from_connection_string(conn_str)
    blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(StorageAccount_Name),credential=managed_identity_credential)
    SourceName1 = filename.rsplit('/')
    SourceName1 = SourceName1[:-1]
    SourceName1 = "/".join(SourceName1)

    blob_metadata = {}
    blob_client = blob_service_client.get_blob_client(container=container_name, blob=SourceName1)
    a = blob_client.get_blob_properties()
    
    if 'datepartitionpath' in a.metadata:
        blob_metadata = a.metadata
    return blob_metadata['datepartitionpath']

#def initialize_datalakeservice(account_url, storage_account_key):
def initialize_datalakeservice(account_url, managed_identity_credential):
    
    try:  
        global service_client

        service_client = DataLakeServiceClient(account_url, credential=managed_identity_credential)
        logging.info('Successfully connected')
    
    except Exception as e:
        print(e)

def move_directory(filename, container_name, date_partition,StorageAccount_RawContainer):
    current_datetime = datetime.utcnow()
    output_date = current_datetime
    output_date = str(output_date).replace(' ', 'T')
    output_date = output_date + 'Z'
    filename2 = filename.rsplit('/')
    filename2 = filename2[-1]
    filename2 = filename2.rsplit('.')
    ext = '.'+filename2[-1]
    filename3 = filename2[:-1]
    filename2 = ".".join(filename3) 


    try:
        file_system_client = service_client.get_file_system_client(container_name)
        directory_client = file_system_client.get_directory_client(filename)
        new_dir_name = StorageAccount_RawContainer+'/'
        new_dir_name += create_directory(filename, date_partition, current_datetime,StorageAccount_RawContainer)
        logging.info(f'New Directory Name is: {new_dir_name}')
        logging.info(f'filename is: {filename}')
        #new_dir_name += filename2+'_'+output_date+ext #Uncomment this line and comment line below if you want add utc timestamp as suffix
        new_dir_name += filename2+ext   
        logging.info(f'fullname is: {new_dir_name}')
        directory_client.rename_directory(new_dir_name)
        logging.info(f'succesfully moved file: {new_dir_name}')
    except Exception as e:
     print(e)
     raise

def create_directory(filename, date_partition, current_datetime,StorageAccount_RawContainer):
    file_system_client = service_client.get_file_system_client(StorageAccount_RawContainer)
    new_directory = ''
    
    #CREATE DIRECTORY FOR SUBFOLDER IF NOT EXIST
    try:
        logging.info('creating new directory!')
        new_directory += filename[0:filename.rindex('/')] + '/'
        file_system_client.create_directory(new_directory)
        logging.info('successfully created new directory!')
    except:
        logging.info('no directory created')

    #CREATE DATE PARTITIONS
    partitions = date_partition.split('/')

    for partition in partitions:
        if('Y' in partition):
            new_directory += str(current_datetime.year) +'/'
        if('M' in partition):
            new_directory += str(current_datetime.month) + '/' if len(str(current_datetime.month)) == 2 else '0' + str(current_datetime.month) +'/'
        if('D' in partition):
            new_directory += str(current_datetime.day) + '/' if len(str(current_datetime.day)) == 2 else '0' + str(current_datetime.day) +'/'
        if('T' in partition):
            new_directory += str(current_datetime.strftime('%H%M%S'))+'/'

    file_system_client.create_directory(new_directory)
    logging.info(f'succesfully created directory partition: {new_directory}')
    return new_directory
