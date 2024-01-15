#***********************************************************************************************************************
#**  Name:                   StagingToCuratedBlob Azure Function
#**  Desc:                   When a Delta Lake upsert is completed to a table folder in the staging zone this Azure function should run. 
#                            The function will trigger a sql serverless stored procedure to identify all dependent SQL artifacts downstream.
#                            The function will then iterate through the dependent sql artifacts, running a Select * on the dependent views 
#                            and executing the dependent stored procs. It will then write the result sets to the curated zone of the lake, 
#                            stored in a folder path based on the name of the sql artifact stated in the ObjName colum, i.e:
#                            /curated/CurrencyRate/
#                            where CurrencyRate was the name of the dependent view returned by the proc.
#                            Files should be saved in parquet format and appended with a UTC timestamp.
#                            Existing files should be replaced.
#
#**  Auth:                   M Darwish
#**  Date:                   03/12/2021
#**
#**  Change History
#**  --------------
#**  No.     Date            Author              Description
#**  ---     ----------      -----------         ---------------------------------------------------------------
#**  1       03/12/2021      M Darwish           Original Version
#**  2       27/05/2022      T Bush              Removed references to version guids on the keyvault calls - it should default to pulling the latest version
import logging
import azure.functions as func
import pyodbc as po
from pyspark import SparkContext, SparkConf, SQLContext
import pandas as pd
from datetime import datetime
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

##def main(myblob: func.InputStream):
def main():
    ##logging.info(f"Python blob trigger function processed blob \n"
    ##             f"Name: {myblob.name}\n"
    ##             f"Blob Size: {myblob.length} bytes")
    KVUri = f"https://intergen-mdp-keyvault.vault.azure.net/" # KV path to read credential of service principal
    credential1 = DefaultAzureCredential() #will use managed identity enabled to authenticate azure function to access KV
    client = SecretClient(vault_url=KVUri, credential=credential1) #creating secret client to access KV to read credential of service principal
    CLIENT_ID = client.get_secret('intergen-adls-clientid') #Reading Client ID of SP 
    CLIENT_SECRET = client.get_secret('intergen-adls-clientsecret')#Reading Client Secret of SP
    TENANT_ID = client.get_secret('intergen-adls-tenantid')#Reading Tenant ID of SP
    storage_account_key = client.get_secret('intergen-adls-accesskey')#fetching account key from KV to be used to access the ADLS

    blob_url2 = 'https://intergendatamdpadlsdev.dfs.core.windows.net/testing/Currency/' #This should be passed as parameter from caller function which will be sourcename or path of landed file in staging zone without filename.ext
    server = 'intergen-data-mdp-synapse-dev-ondemand.sql.azuresynapse.net'
    database = 'intergen-data-mdp-synapse-serverless-sql-dev'  
    driver= '{ODBC Driver 17 for SQL Server}'
    appName = "PySpark SQL Server Example - via ODBC"
    master = "local"
    #initiate the spark session
    conf = SparkConf() \
        .setAppName(appName) \
        .setMaster(master) 
    sc = SparkContext(conf=conf)
    sqlContext = SQLContext(sc)
    spark = sqlContext.sparkSession

    try: 
        #connection string to synapse serverless DB to execute SP
        cnxn = po.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=' +
            server+';DATABASE='+database+';Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;MARS_Connection=Yes;UID='+CLIENT_ID.value+';PWD='+CLIENT_SECRET.value+';Authentication=ActiveDirectoryServicePrincipal;')
        cursor = cnxn.cursor()
        cursor2 = cnxn.cursor()
        storedProc = "Exec [dbo].[lookup_all_lake_sources] @DataLakeStorageBlobURL = ?"
        params = ('{}'.format(blob_url2))

    # Execute Stored Procedure With Parameters
        cursor.execute( storedProc, params ) #assigning the execution result of stored procedure to variable (sql artifacts that need to run)
        utc_date = datetime.utcnow().strftime("%Y_%m_%d_%I_%M_%S_%p")
        conn_str = "DefaultEndpointsProtocol=http;AccountName=intergendatamdpadlsdev;AccountKey="+ \
           storage_account_key.value+ \
           ";BlobEndpoint=https://intergendatamdpadlsdev.blob.core.windows.net/;"
        row = cursor.fetchone() #assigning first row of execution result to the variable
        while row:
            if (str(row[4]) == str('V')): #if object type is view
                qry = "SELECT * FROM " + str(row[0]) + "." + str(row[1]) 
                schemaName = str(row[0])
                tableName = str(row[1])
                pdf = pd.read_sql(qry,cnxn) # execute the view and write its result to curated zone
                pdf.to_parquet('abfs://curated@intergendatamdpadlsdev.dfs.core.windows.net/{}/{}_{}.parquet'.format(tableName,tableName,utc_date), storage_options = {"account_name": "intergendatamdpadlsdev",'account_key' : storage_account_key.value,"connection_string": conn_str})
            elif (str(row[4]) == str('P')): #if object type is stored procedure
                qry = "select sc.name as schema_name, pr.name as proc_name " \
                      "from sys.procedures pr left outer join sys.parameters p " \
                      "on pr.object_id = p.object_id " \
                      "inner join sys.schemas sc on pr.schema_id = sc.schema_id " \
                      "where p.name is null " \
                      "and sc.name = '"+str(row[0])+ \
                      "' and pr.name = '"+str(row[1])+"'" 
                cursor2.execute( qry) #execute stored procedure if it doesnt expect any parameters and write its result to curated zone
                row2 = cursor2.fetchone()
                while row2:
                    strproc = "Exec " + str(row2[0]) + "." + str(row2[1])
                    proc_name = str(row2[1])
                    pdf2 = pd.read_sql(strproc,cnxn)
                    pdf2.to_parquet('abfs://curated@intergendatamdpadlsdev.dfs.core.windows.net/{}/{}_{}.parquet'.format(proc_name,proc_name,utc_date), storage_options = {"account_name": "intergendatamdpadlsdev",'account_key' : storage_account_key.value,"connection_string": conn_str})
                    row2 = cursor2.fetchone()
            row = cursor.fetchone()
 
    # Close the cursor and delete it
        cursor.close()
        del cursor
 
    # Close the database connection
        cnxn.close()
 
    except Exception as e:
        print("Error: %s" % e)

if __name__ == "__main__":
    main()