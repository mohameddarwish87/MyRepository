#***********************************************************************************************************************
#**  Name:                   LandingToStagingBlob Azure Function
#**  Desc:                   This function is responsible to listen to any file arrive in landing zone, capture its parent folder metadata and 
#**                          call another function that will generate spark job that will run another python file which is responsible to write 
#**                          the file data to its corresponding path in staging zone in delta format
#**  Auth:                   M Darwish
#**  Date:                   03/12/2021
#**
#**  Change History
#**  --------------
#**  No.     Date            Author              Description
#**  ---     ----------      -----------         ---------------------------------------------------------------
#**  1       03/12/2021      M Darwish           Original Version
#**  2       06/12/2021      M Darwish           Removing the for loop that goes through list of blob of landing and pass directly blob based on myblob.name
#**  3       07/12/2021      M Darwish           generating metadata_file with name of file sourcename, schema name and utc timestamp
#**  4       13/12/2021      M Darwish           Sort the metadata by name for index
#**  5       09/02/2022      M Darwish           Changing variables to read from App setting variables
#**  6       28/02/2022      M Darwish           adding business key 5,6,7
#**  7       18/03/2022      M Darwish           adding code of moving dim and fact from landing to curated
#**  8       06/05/2022      W Viviers           changed the job name to include the container and file name for better clarity in the Synapse Logs.
#**  9       27/05/2022      M Darwish           Adding extra metadata variables
#**  10      27/05/2022      M Darwish           Changed function app to run as the managed identity of the function. Renamed variables to better reflect what was in each credential. Removed echoing of storage account key to logs. Renamed 'incrementalload' metadata parameter to 'upsert'
#**  11      03/06/2022      M Darwish           Removed Storage Account Access Key variable & Uploading Json file using blob client upload_blob instead of pandas to_json
import logging
import azure.functions as func
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
from azure.identity import ClientSecretCredential , ManagedIdentityCredential
import pandas as pd
from azure.synapse import SynapseClient
from azure.synapse.models import ExtendedLivyBatchRequest
from datetime import datetime
from opencensus.trace import execution_context, tracer
import os,sys

# Declare general job name here, we will redefine further down
global job_name
job_name = "ConvertToDelta"
##

def main(myblob: func.InputStream,context: func.Context):# Main function that will read the parent folder metadata of arrived file and generate it to JSON file then call another function that will start the spark job
 logging.info(f"Python blob trigger function processed blob \n"
                 f"Name: {myblob.name}\n"
                 f"Blob Size: {myblob.length} bytes")
 logging.info(f'Started Execution of Function Id:{context.invocation_id} , Function Name: {context.function_name}')
 try:
#############################################################    VARIABLE INITIALIZATION    ###############################################################################################################
    ##KeyVault_Name = os.environ["KeyVault_Name"]
    ##KeyVault_SP_ClientId = os.environ["AZURE_CLIENT_ID"]
    ##KeyVault_SP_ClientSecret = os.environ["AZURE_CLIENT_SECRET"]
    ##KeyVault_SP_TenantId = os.environ["AZURE_TENANT_ID"]
    #StorageAccount_AccessKey = os.environ["KeyVault_StorageAccount_AccessKey"]
    StorageAccount_LandingContainer = os.environ["StorageAccount_LandingContainer"]
    StorageAccount_Name = os.environ["StorageAccount_Name"]
    StorageAccount_CuratedContainer = os.environ["StorageAccount_CuratedContainer"]
    StorageAccount_StagingContainer = os.environ["StorageAccount_StagingContainer"]
    StorageAccount_RawContainer = os.environ["StorageAccount_RawContainer"]
    Function_AppName = os.environ["FunctionApp_Name"]
    ##KVUri = "https://{}.vault.azure.net/".format(KeyVault_Name) # KV path to read credential of service principal
    #credential1 ManagedIdentityCredential()
    #managed_identity_credential = DefaultAzureCredential(exclude_visual_studio_code_credential=True) #will use managed identity enabled to authenticate azure function to access KV
    managed_identity_credential = ManagedIdentityCredential()
    #client = SecretClient(vault_url=KVUri, credential=managed_identity_credential)#creating secret client to access KV to read credential of service principal
    #credential2 = ClientSecretCredential(client_id=KeyVault_SP_ClientId,client_secret=KeyVault_SP_ClientSecret,tenant_id=KeyVault_SP_TenantId)
#############################################################   END VARIABLE INITIALIZATION    ###############################################################################################################
    blob_service_client = BlobServiceClient("https://{}.blob.core.windows.net".format(StorageAccount_Name),credential=managed_identity_credential)
    ##container_client = blob_service_client.get_container_client(StorageAccount_LandingContainer)
    execution_context.set_opencensus_tracer(tracer)
    context = tracer.Tracer().span_context
    trace_id = context.trace_id
    logging.info(f'Function Run ID: {trace_id}')

    blob_name = myblob.name
    if blob_name.find('.') != -1: # if blob detected has no file in its path then exit
        blob_name = blob_name.rsplit('/')#convert the path into list with each folder as element in list and using / as separator (delimiter)
        FileName = blob_name[-1]#assigning last element of the list which is file name to the variable
        ext = FileName.rsplit('.')#converting filename with its extension into list
        ext = ext[-1]# saving the filename extension into variable
        blob_name = blob_name[:-1] #delete the the filename.ext from folder path to get the parent folder so that we can fetch its metadata
        blob_name.pop(0) #delete 'landing' from the folder path as it is not required
        blob_name2 = blob_name #txt2 will hold source name in form of AdventureWorks_Person_Person to be used as name for metadata file
        blob_name = "/".join(blob_name)#creating path again without filename and 'landing using / as delimiter
        blob_name2 = "_".join(blob_name2)
    
        dat_txt = str(datetime.utcnow()) #dat_txt will hold the timestamp of metadata file creation that will be added to metadata file name
        dat_txt = dat_txt.rsplit('-')
        dat_txt = "_".join(dat_txt)
        dat_txt = dat_txt.rsplit(' ')
        dat_txt = "_".join(dat_txt)
        dat_txt = dat_txt.rsplit(':')
        dat_txt = "_".join(dat_txt)
        dat_txt = dat_txt.rsplit('.')
        dat_txt = dat_txt[:-1]
        dat_txt = "_".join(dat_txt)
        #txt3 = txt2+'_'+'Metadata_'+dat_txt+'.json'
        MetaDataFileName = blob_name2+'_'+'Metadata_'+dat_txt+'.json'

        #storage_account_key.value
        #conn_str="DefaultEndpointsProtocol=http;AccountName="+StorageAccount_Name+";AccountKey=" \
        #   +StorageAccount_AccessKey+ \
        #   ";BlobEndpoint=https://{}.blob.core.windows.net/;".format(StorageAccount_Name)
        ##DataLakeCuratedURL = 'abfss://{}@{}.dfs.core.windows.net'.format(StorageAccount_CuratedContainer,StorageAccount_Name)
        DataLakeSystemURL = 'abfss://system@{}.dfs.core.windows.net'.format(StorageAccount_Name)
 
        blob_client = blob_service_client.get_blob_client(container=StorageAccount_LandingContainer, blob=blob_name) #create blob client for the blob of where file is landed
        blob_client_system = blob_service_client.get_blob_client(container='system/Parameters', blob=MetaDataFileName)
        a = blob_client.get_blob_properties() #fetch the blob properties
        
        # Create first part of job name ######
        global job_name
        if(a.metadata['pushtocuratedzone'].lower() == 'true'):
            job_name = 'ConvertToDeltaInCurated'
        if(a.metadata['pushtostagingzone'].lower() == 'true'):
            job_name = 'ConvertToDeltaInStaging'
        #######################################

        if not ('pushtostagingzone' in a.metadata.keys()):
            blob_client.set_blob_metadata(metadata={"businesskey1":"","businesskey2":"","businesskey3":"","businesskey4":"","businesskey5":"","businesskey6":"","businesskey7":"","datepartitionpath":"YYYY\MM\DD","upsert":"True","partitionkey":"","pushtostagingzone":"False","pushtocuratedzone":"False","scd2flag":"False","watermarkcol":"","ExplorationZonePath":"","PushToExplorationZone":"False","PushToDW":"False","LastWatermark":"1900-01-01"})
        elif ( (a.metadata['pushtocuratedzone'].lower() == 'true' or a.metadata['pushtostagingzone'].lower() == 'true') and ext == 'parquet'): #if metadata 'pushtostagingzone' is present and true and file landed is parquet file
            if(a.metadata['pushtocuratedzone'].lower() == 'true' and a.metadata['pushtostagingzone'].lower() == 'true'):
                logging.error("You can't have both pushtocuratedzone and pushtostagingzone true at the same time! Please fix this")
                raise
            if(a.metadata['businesskey1'] == "" and a.metadata['businesskey2'] == "" and a.metadata['businesskey3'] == "" and a.metadata['businesskey4'] == "" and a.metadata['businesskey5'] == "" and a.metadata['businesskey6'] == "" and a.metadata['businesskey7'] == ""):
                logging.error("You must have at least one business key defined ! Please fix this")
                raise   
            else:
                new_dict ={} #creating new empty dictionary
                new_dict["sourcename1"] = blob_name #appending to empty dictionary source name (path of file landed without filename and 'landing')
                new_dict["filename1"] = FileName
                new_dict["runid1"] = trace_id
                new_dict["Function_AppName"] = Function_AppName
                new_dict["StorageAccount_LandingContainer"] = StorageAccount_LandingContainer
                new_dict["StorageAccount_StagingContainer"] = StorageAccount_StagingContainer
                new_dict["StorageAccount_CuratedContainer"] = StorageAccount_CuratedContainer
                new_dict["StorageAccount_RawContainer"] = StorageAccount_RawContainer
                new_dict["StorageAccount_Name"] = StorageAccount_Name
                new_dict.update(a.metadata) #appending metadata dictionary to new_dict dictionary
                new_dict = dict(sorted(new_dict.items(),key=lambda x : x[0], reverse = False)) #sort metadata by name for index
                pdf = pd.DataFrame(new_dict.items()) #1)read metadata dict and create data frame from it and assign it to dataframe variable
                pdf = pdf.rename(columns={0: 'Metadata_title',1:'Metadata_value'})#renaming columns of DataFrame
                logging.info(f'Generating JSON file for the metadata of the folder..')
                logging.info(f'Storage Account Name is'+StorageAccount_Name)
                #logging.info(f'Connection String is'+conn_str)
                logging.info(f'MetaDataFileName is'+MetaDataFileName)
                logging.info(f'DataLakeSystemURL is'+DataLakeSystemURL)
                #pdf.to_json(orient="records",path_or_buf = DataLakeSystemURL + '/' + 'Parameters/'+MetaDataFileName, storage_options = {"account_name": StorageAccount_Name,'account_key' : StorageAccount_AccessKey,"connection_string": conn_str})#writing the metadata of parent folder in the JSON file in curated zone
                #pdf.to_json(orient="records",path_or_buf = DataLakeSystemURL + '/' + 'Parameters/'+MetaDataFileName)#writing the metadata of parent folder in the JSON file in curated zone
                json_lines_data = pdf.to_json(orient='records')
                blob_client_system.upload_blob(json_lines_data)
                logging.info(f'succesfully written JSON metadata file')
                #RunSparkJob(credential2,txt3)#calling the fucntion that will start the spark job managed_identity_credential
                RunSparkJob(managed_identity_credential,MetaDataFileName)
        else:
           logging.info(f'Blob landed is not parquet file or pushtostagingzone is set to false')

    else:
        logging.info(f'Folder found with no metadata..')
        logging.info(f'Adding metadata to the folder..')
        blob_name = blob_name.rsplit('/') #converting blob path into list
        blob_name.pop(0) #removing container name from the list
        blob_name = "/".join(blob_name) #convert list back to string
        blob_client = blob_service_client.get_blob_client(container=StorageAccount_LandingContainer, blob=blob_name) #create blob client for the blob of where file is landed
        a = blob_client.get_blob_properties() 
        if not ('pushtostagingzone' in a.metadata.keys()):
          blob_client.set_blob_metadata(metadata={"businesskey1":"","businesskey2":"","businesskey3":"","businesskey4":"","businesskey5":"","businesskey6":"","businesskey7":"","datepartitionpath":"YYYY\MM\DD","upsert":"True","partitionkey":"","pushtostagingzone":"False","pushtocuratedzone":"False","scd2flag":"False","watermarkcol":"","ExplorationZonePath":"","PushToExplorationZone":"False","PushToDW":"False","LastWatermark":"1900-01-01"})

 except Exception as e:
        print(e)
        logging.error(e)
        raise        
    
def RunSparkJob(credential: func.InputStream,metadata_file: func.InputStream):#wayne
  try:  
#function that will create spark job that will call Python File that will move data of landing file into delta fomat in staging zone
#############################################################    VARIABLE INITIALIZATION    ###############################################################################################################
    StorageAccount_Name = os.environ["StorageAccount_Name"]
    Synapse_Name = os.environ["Synapse_Name"]
    Synapse_PoolName = os.environ["Synapse_PoolName"]
    #workspace_name = "intergen-data-mdp-synapse-dev"
    #spark_pool_name = "Spark3MDF"
    #ACCOUNT_NAME = "intergendatamdpadlsdev"
#############################################################    END VARIABLE INITIALIZATION    ###########################################################################################################
    batch_id = 1

    global job_name
    if (metadata_file.find("_Metadata_")) == -1:
        job_suffix = metadata_file
    else:
        job_suffix = metadata_file[0:metadata_file.find("_Metadata_")]

    if not job_name == "":
        job_name = job_name + ": " + job_suffix
    else:
        job_name = "ConvertToDelta" + ":= " + job_suffix

    file = "abfss://system@{}.dfs.core.windows.net/Functions/ConvertToDelta.py".format(StorageAccount_Name)
    class_name = "Hello"
    args = ["abfss://system@{}.dfs.core.windows.net/Parameters/{}".format(StorageAccount_Name,metadata_file)]
    driver_memory = "4g"
    #driver_cores = 4
    driver_cores = 1
    executor_memory = "4g"
    #executor_cores = 4
    #num_executors = 2
    executor_cores = 1
    num_executors = 1
    synapse_client = SynapseClient(credential)
    spark_batch_operation = synapse_client.spark_batch
    livy_batch_request = ExtendedLivyBatchRequest(name=job_name, file=file, class_name=class_name, args=args, 
             driver_memory=driver_memory, driver_cores=driver_cores, executor_memory=executor_memory,
            executor_cores=executor_cores, num_executors=num_executors)

    spark_batch_operation.create(Synapse_Name, Synapse_PoolName, livy_batch_request) #creating spark job and passing to it job parameters
  except Exception as e:
        print(e)
        logging.error(e)
        raise      
    
if __name__ == "__main__":
    main(func.Context)

