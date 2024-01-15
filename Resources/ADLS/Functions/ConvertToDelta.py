#***********************************************************************************************************************
#**  Name:                   ConvertToDelta python Function
#**  Desc:                   This function is responsible to read the parameters.json parameter file (metadata of folder of landed file) and move data of the landed file to the staging zone in delta format. 
#**                          It does upsert SCD type 1 to staging
#**  Auth:                   M Darwish
#**  Date:                   03/12/2021
#**
#**  Change History
#**  --------------
#**  No.     Date            Author              Description
#**  ---     ----------      -----------         ---------------------------------------------------------------
#**  1       03/12/2021      M Darwish           Original Version
#**  2       07/12/2021      M Darwish           Reading metadata JSON file dynamically with file associated during spark job call
#**  3       12/12/2021      M Darwish           Adding feature of writing partitions based on partitionkey metadata parameter
#**  4       16/12/2021      M Darwish           Adding feature of Incremental/Full Load based on incrementalload metadata parameter
#**  5       21/12/2021      M Darwish           Implementing SCD Type 2
#**  6       18/03/2022      M Darwish           adding code of moving dim and fact from landing to curated
#**  7       27/05/2022      M Darwish           Fixing SCD2 issue + Adding Timestamp + Adding new metadata variables
#**  8       03/06/2022      M Darwish           Constraining timestamp millisecond to 6 digits
#**  9       09/06/2022      M Darwish           Adding Failure if business key columns has null in source file
#**  10      05/10/2022      M Darwish           Considering time travel columns as reserved words from Source+Adding Surrogate Key
import os
os.environ["PYARROW_IGNORE_TIMEZONE"]="1"
import pandas as pd
import pyspark
from pyspark.sql import SparkSession                 
from delta.tables import *
import delta
import sys
import unicodedata
import re
from pyspark.sql.functions import udf, lit, monotonically_increasing_id, sha2, concat_ws, col
from datetime import datetime           
import logging
import urllib.request                  
import dateutil.parser
from datetime import date
from datetime import datetime
import datetime
from pyspark.sql.types import StringType, DateType
import uuid             




def normalize(column: str) -> str:
    #"""
    #Normalize column name by removing invalid characters
    #:param column: column name
    #:return: normalized column name
    #"""
    
    #Below 2 lines were original code to be restored later 
    ##n = re.sub(r"[ ,;{}()\n\t=]+", '', column)
    ##return unicodedata.normalize('NFKD', n).encode('ASCII', 'ignore').decode()
    
    #Below code is temporary to fail if special character is found in column names of parquet file landed otherwise staging will be corrupted
    #This is temporary until synapse use Spark 3.2 that will support pandas distributed with parallelism. we will use pandas parquet reader instead of buggy spark reader that cause issues with special character of column names #even after renaming files
    
    pattern = re.compile(r"[ ,;{}()\n\t=]+")
    x = re.findall(pattern,column)
    if x:
        logging.error('File column names have special character. Please fix that')
        raise RuntimeError(f'File column names have special character. Please fix that')
    else:
        return column

def check_if_exists(filepath: str):

    try:
        spark=SparkSession.builder.appName("ConvertToDelta").config("spark.databricks.delta.schema.autoMerge.enabled","true").getOrCreate()
################################# Accessing ADLS through Linked Service#######################################################################
#        linkedServiceName_var = "ls_adls"
#        spark.conf.set("fs.azure.account.auth.type", "SAS")
#        spark.conf.set("fs.azure.sas.token.provider.type", "com.microsoft.azure.synapse.tokenlibrary.LinkedServiceBasedSASProvider")
#        spark.conf.set("spark.storage.synapse.linkedServiceName", linkedServiceName_var)
#############################################################################################################################################
    
        spark.read.parquet(filepath)
    except:
        logging.info(f'filepath not found')
        return False
    else:
        logging.info(f'filepath successfully read')
        return True                                

def main():
    #initiate spark session and configuring it to auto update the schema if new files has different schema (new columns for ex.)
    spark=SparkSession.builder.appName("ConvertToDelta").config("spark.databricks.delta.schema.autoMerge.enabled","true").getOrCreate()#iniate spark session
################################# Accessing ADLS through Linked Service#######################################################################
#    linkedServiceName_var = "ls_adls"
#    spark.conf.set("fs.azure.account.auth.type", "SAS")
#    spark.conf.set("fs.azure.sas.token.provider.type", "com.microsoft.azure.synapse.tokenlibrary.LinkedServiceBasedSASProvider")
#    spark.conf.set("spark.storage.synapse.linkedServiceName", linkedServiceName_var)
#############################################################################################################################################
    
    #config spark to bypass issue of org.apache.spark.SparkUpgradeException: You may get a different result due to the upgrading of Spark 3.0: reading dates before 1582-10-15 or timestamps before 1900-01-01T00:00:00Z from Parquet INT96 files can be ambiguous, as the files may be written by Spark 2.x or legacy versions
    spark.conf.set("spark.sql.legacy.parquet.int96RebaseModeInRead", "CORRECTED")
    spark.conf.set("spark.sql.legacy.parquet.int96RebaseModeInWrite", "CORRECTED")
    spark.conf.set("spark.sql.legacy.parquet.datetimeRebaseModeInRead", "CORRECTED")
    spark.conf.set("spark.sql.legacy.parquet.datetimeRebaseModeInWrite", "CORRECTED")
    
    df = spark.read.option("multiline","true").json(sys.argv[1]) #sys.argv[1] will be translated to abfss://system@intergendatamdpadlsdev.dfs.core.windows.net/Parameters/AdventureWorks_Person_Person_Metadata_2021_12_07_05_52_04.json which is metadata json file that will be read into spark data frame
    logging.info(f'succesfully read JSON parameter file')
    pandasDF = df.toPandas()#convert spark data frame to panda data frame
#############################################################    VARIABLE INITIALIZATION    ##################################################################################################################
    storage_account = pandasDF._get_value(3,'Metadata_value') #"intergendatamdpadlsdev"
    DataLakeLanding = pandasDF._get_value(2,'Metadata_value')#'abfss://landing@{}.dfs.core.windows.net'.format(storage_account)
    DataLakeLandingURL = 'abfss://'+ DataLakeLanding + '@' + storage_account + '.dfs.core.windows.net'
    DataLakeStaging = pandasDF._get_value(5,'Metadata_value')#'abfss://staging@{}.dfs.core.windows.net'.format(storage_account)
    DataLakeStagingURL = 'abfss://'+ DataLakeStaging + '@' + storage_account + '.dfs.core.windows.net'
    DataLakeCurated = pandasDF._get_value(1,'Metadata_value')#'abfss://curated@{}.dfs.core.windows.net'.format(storage_account)
    DataLakeCuratedURL = 'abfss://'+ DataLakeCurated + '@' + storage_account + '.dfs.core.windows.net'
    DataLakeRaw = pandasDF._get_value(4,'Metadata_value')#'abfss://raw@{}.dfs.core.windows.net'.format(storage_account)
    DataLakeRawURL = 'abfss://'+ DataLakeRaw + '@' + storage_account + '.dfs.core.windows.net'
    DataLakeSystemURL = 'abfss://system@{}.dfs.core.windows.net'.format(storage_account)
    DatabaseName = 'default'
    azure_function = pandasDF._get_value(0,'Metadata_value')#"intergen-data-mdp-function-dev"
#############################################################    END VARIABLE INITIALIZATION    ##############################################################################################################

#############################################################    VARIABLE INITIALIZATION    ###################################################################################################################

    SourceName = pandasDF._get_value(25,'Metadata_value') #fetching SourceName from pandas data frame
    SourceNameList = SourceName.rsplit('/')
    TableName = 'DL'+SourceNameList[-1]+'Key'
    FileName = pandasDF._get_value(15,'Metadata_value')#fetching FileName from pandas data frame
    PartitionKey = pandasDF._get_value(18,'Metadata_value')
    #IncrementalLoad = pandasDF._get_value(26,'Metadata_value')
    upsert = pandasDF._get_value(26,'Metadata_value')
    RunId1 = pandasDF._get_value(23,'Metadata_value')
    Scd2Flag = pandasDF._get_value(24,'Metadata_value')
    pushtocuratedzone = pandasDF._get_value(19,'Metadata_value')
    pushtostagingzone = pandasDF._get_value(22,'Metadata_value')
    pushtoexplorationzone = pandasDF._get_value(21,'Metadata_value')
    pushtodw = pandasDF._get_value(20,'Metadata_value')
    explorationzonepath = pandasDF._get_value(14,'Metadata_value')
    lastwatermark = pandasDF._get_value(17,'Metadata_value')
    NonBusinessKeyHash = 'NonBusinessKeyHash' #name of hashkey column in delta lake
    BusinessKeyHash = "BusinessKeyHash"
#############################################################  END VARIABLE INITIALIZATION    #################################################################################################################

#############################################################    VARIABLE INITIALIZATION    ###################################################################################################################
    BusinessKey1 = pandasDF._get_value(6,'Metadata_value')
    BusinessKey2 = pandasDF._get_value(7,'Metadata_value')
    BusinessKey3 = pandasDF._get_value(8,'Metadata_value')
    BusinessKey4 = pandasDF._get_value(9,'Metadata_value')
    BusinessKey5 = pandasDF._get_value(10,'Metadata_value')
    BusinessKey6 = pandasDF._get_value(11,'Metadata_value')
    BusinessKey7 = pandasDF._get_value(12,'Metadata_value')
#############################################################  END VARIABLE INITIALIZATION    ##################################################################################################################
    StagingPath = DataLakeStagingURL + '/' + SourceName
    CuratedPath = DataLakeCuratedURL + '/' + SourceName
    SourcePath = DataLakeLandingURL + '/' + SourceName + '/' + FileName
    filename2 = FileName.rsplit('.') #Convert Filename into list of elements with delimiter .
    filename2 = filename2[:-1] #Remove 'parquet' element from the list
    ######################This Sections deals whether timestamp is added as suffic to filename######################################################################################
    Istimesuffix = 0
    if len(filename2) > 1: #check if there is other suffix attached with file name to be removed such as timestamp
        Istimesuffix = 1
        filename2 = ".".join(filename2)    
        filename2 = filename2.rsplit('_')    
        timesuffix = filename2[-1] #Fetching time suffix from filename
        #filename2 = filename2[:-1] #Remove milliseconds and 'Z' from the list
    #if len(filename2) > 1:
        #filename2.pop(0) #Remove schema name from the list if schema name is present
    #filename2 = filename2[0] #Taking the remaining element in list and assign it as string to filenam2
    #filename2 = filename2.rsplit('_') #Convert the string into list delimited by _
    if Istimesuffix == 1:
        #filename2 = filename2[-1] #Taking the last element of the list which is datetime suffix of the file
        #d = dateutil.parser.parse(filename2) #Converting the datetime element into date data type
        d = dateutil.parser.parse(str(timesuffix))          
        day = d.day
        month = d.month
        year = d.year
        ArchivePath = DataLakeRawURL + '/' + SourceName + '/' + str(year) + '/' + str(month) + '/' + str(day) + '/' + FileName    
        #timesuffix = datetime.datetime.strptime(timesuffix, '%Y-%m-%dT%H:%M:%S.%fZ')
        timesuffix = datetime.datetime.strptime((timesuffix[:26]).strip()+'Z', '%Y-%m-%dT%H:%M:%S.%fZ')
    else:
        today = date.today()
        d = dateutil.parser.parse(str(today)) #Converting the datetime element into date data type
        day = d.day
        month = d.month
        year = d.year
        ArchivePath = DataLakeRawURL + '/' + SourceName + '/' + str(year) + '/' + str(month) + '/' + str(day) + '/' + FileName    
#####################End of this section############################################################################################################################################

    SourceData  = spark.read.parquet(SourcePath)
    SourceData = SourceData.toDF(*map(normalize, SourceData.columns)) # function normalize that removes all invalid characters which is present in the top   
    SourceDataWithoutBusinessKey = SourceData.columns #creating a new list of data frame columns
    SourceDataWithoutBusinessKey = list(map(lambda x: x.upper(), SourceDataWithoutBusinessKey)) #Convert business key to upper case to avoid any error of mixed upper and lowercase with input metadata businss key
    MainBusinessKey=[]
    #Removing business key columns from SourceDataWithoutBusinessKey list
    #Adding business key columns to MainBusinessKey list
    if not (BusinessKey1 is None or BusinessKey1==''):
        SourceDataWithoutBusinessKey.remove(BusinessKey1.upper())
        MainBusinessKey.append(BusinessKey1.upper())
    if not (BusinessKey2 is None or BusinessKey2==''):
        SourceDataWithoutBusinessKey.remove(BusinessKey2.upper())
        MainBusinessKey.append(BusinessKey2.upper())
    if not (BusinessKey3 is None or BusinessKey3==''):
        SourceDataWithoutBusinessKey.remove(BusinessKey3.upper())
        MainBusinessKey.append(BusinessKey3.upper())
    if not (BusinessKey4 is None or BusinessKey4==''):
        SourceDataWithoutBusinessKey.remove(BusinessKey4.upper())
        MainBusinessKey.append(BusinessKey4.upper())
    if not (BusinessKey5 is None or BusinessKey5==''):
        SourceDataWithoutBusinessKey.remove(BusinessKey5.upper())
        MainBusinessKey.append(BusinessKey5.upper())
    if not (BusinessKey6 is None or BusinessKey6==''):
        SourceDataWithoutBusinessKey.remove(BusinessKey6.upper())
        MainBusinessKey.append(BusinessKey6.upper())
    if not (BusinessKey7 is None or BusinessKey7==''):
        SourceDataWithoutBusinessKey.remove(BusinessKey7.upper())
        MainBusinessKey.append(BusinessKey7.upper())
########Checking if Business Key columns has null to fail and return error message###############################################
    for businesskeycol in MainBusinessKey:   
     null_count = SourceData.filter(businesskeycol+" is null").count()
     if null_count > 0:
        raise Exception("There is null in business key column, please fix This")
################################################################################################################################
# Remove time travel columns from non business hash key calculation if present
################################################################################################################################
    RowValidFromPresent = SourceData.schema.simpleString().find("RowValidFrom")
    RowValidToPresent = SourceData.schema.simpleString().find("RowValidTo")
    RowIsCurrentPresent = SourceData.schema.simpleString().find("RowIsCurrent")
    RunIDPresent = SourceData.schema.simpleString().find("RunID")
    NonBusinessKeyHashPresent = SourceData.schema.simpleString().find("NonBusinessKeyHash")
    BusinessKeyHashPresent = SourceData.schema.simpleString().find("BusinessKeyHash")
    SurrogateKeyPresent = SourceData.schema.simpleString().find(TableName)
    if RowValidFromPresent != -1:
        SourceDataWithoutBusinessKey.remove("ROWVALIDFROM")
    if RowValidToPresent != -1:
        SourceDataWithoutBusinessKey.remove("ROWVALIDTO")
    if RowIsCurrentPresent != -1:
        SourceDataWithoutBusinessKey.remove("ROWISCURRENT")
    if RunIDPresent != -1:
        SourceDataWithoutBusinessKey.remove("RUNID")
    if NonBusinessKeyHashPresent != -1:
        SourceDataWithoutBusinessKey.remove("NONBUSINESSKEYHASH")    
    if BusinessKeyHashPresent != -1:
        SourceDataWithoutBusinessKey.remove("BUSINESSKEYHASH")
    if SurrogateKeyPresent != -1:
        SourceDataWithoutBusinessKey.remove(TableName.upper())

    SourceData = SourceData.withColumn("NonBusinessKeyHash", sha2(concat_ws("||", *SourceDataWithoutBusinessKey), 256)) #adding a new column NonBusinessKeyHash to the dataframe that hold hash key of
                                                                                                                        #non business key columns
    SourceData = SourceData.withColumn("BusinessKeyHash", sha2(concat_ws("||", *MainBusinessKey), 256)) #adding a new column NonBusinessKeyHash to the dataframe that hold hash key of
                                                                                                        # business key columns                                                                                                                                                                                  
    uuidUdf= udf(lambda : str(uuid.uuid4()),StringType())
    SourceData1 = SourceData.withColumn(TableName,uuidUdf())
    SourceData = SourceData1
    SourceData = SourceData.select([SourceData.columns[-1]] + SourceData.columns[:-1]) #Moving Surrogate Key column from being last column in the data frame to be first column
    #SourceData = SourceData.withColumn("SurrogateKey",lit(str(uuid.uuid4())))
#Defining Business Key condition using for upsert
    BusinessKeyCondition = 'original.'+BusinessKey1.upper()+' == changed.'+BusinessKey1.upper()
    if BusinessKey2:
        BusinessKeyCondition += ' AND original.'+BusinessKey2.upper()+' == changed.'+BusinessKey2.upper()
    if BusinessKey3:
        BusinessKeyCondition += ' AND original.'+BusinessKey3.upper()+' == changed.'+BusinessKey3.upper()
    if BusinessKey4:
        BusinessKeyCondition += ' AND original.'+BusinessKey4.upper()+' == changed.'+BusinessKey4.upper()
    if BusinessKey5:
        BusinessKeyCondition += ' AND original.'+BusinessKey5.upper()+' == changed.'+BusinessKey5.upper()
    if BusinessKey6:
        BusinessKeyCondition += ' AND original.'+BusinessKey6.upper()+' == changed.'+BusinessKey6.upper()
    if BusinessKey7:
        BusinessKeyCondition += ' AND original.'+BusinessKey7.upper()+' == changed.'+BusinessKey7.upper()
#Defining Hash Key condition using for upsert
    NonBusinessKeyCondition = 'original.'+NonBusinessKeyHash+' != changed.'+NonBusinessKeyHash
    #RowValidFrom = str(datetime.utcnow().strftime("%Y-%m-%d"))



    if RowValidFromPresent == -1 and RowValidToPresent == -1 and RowIsCurrentPresent == -1:
        RowValidFrom = str(timesuffix)
        RowValidTo = str("9999-12-31 00:00:00.000000")
        SCD_Columns_Present = 0
    elif RowValidFromPresent != -1 and RowValidToPresent != -1 and RowIsCurrentPresent != -1 and Scd2Flag.upper() == 'FALSE':
        RowValidFrom = SourceData["RowValidFrom"]
        RowValidTo = SourceData["RowValidTo"]
        RowIsCurrent = SourceData["RowIsCurrent"]
        SCD_Columns_Present = 1
    elif RowValidFromPresent != -1 and RowValidToPresent != -1 and RowIsCurrentPresent != -1 and Scd2Flag.upper() == 'TRUE':
        raise Exception("Time travel columns already exist in the source, SCD2 is not possible!")    
    else:
        raise Exception("One or more time travel columns are absent in the source file. please fix this!")              
    #RowValidTo = str("9999-12-31")
    if RunIDPresent == -1:
        SourceData = SourceData.withColumn("RunID",lit(RunId1)) #Adding RunID column to the data frame
    if SCD_Columns_Present == 0:
        SourceData = SourceData.withColumn("RowIsCurrent",lit('true'))
        SourceData = SourceData.withColumn("RowValidFrom",lit(RowValidFrom)).withColumn("RowValidTo",lit(RowValidTo))
        SourceData = SourceData.withColumn("RowValidFrom",SourceData.RowValidFrom.cast(DateType()))
        #SourceData = SourceData.withColumn("RowValidFrom",SourceData.RowValidFrom.cast(DateType()))
        #SourceData = SourceData.withColumn("RowValidTo",SourceData.RowValidTo.cast(DateType()))
        SourceData = SourceData.withColumn("RowValidTo",SourceData.RowValidTo.cast(DateType()))
    SourceData = SourceData.withColumn("RawFilePath",lit(ArchivePath))
    try: 
    
        if pushtocuratedzone.upper() == 'TRUE':
          if upsert.upper() == 'FALSE':
            if PartitionKey is None or PartitionKey == '':
                SourceData.write.format('delta').option('mergeSchema', 'true').mode('overwrite').save(CuratedPath)# writing spark data frame as delta format in staging zone  
            else:
                logging.info(f"will do partitioning")
                spark.conf.set("spark.databricks.optimizer.dynamicPartitionPruning","true")
                SourceData.write.format('delta').partitionBy(PartitionKey).option('mergeSchema', 'true').mode('overwrite').save(CuratedPath)# writing spark data frame as delta format in staging zone  
          elif upsert.upper() == 'TRUE':
           exists = check_if_exists(CuratedPath)
           if not exists:
                logging.info(f"Running for the first time, creating delta table")                
                SourceData.write.format('delta').option('mergeSchema', 'true').mode('overwrite').save(CuratedPath)# writing spark data frame as delta format in staging zone   
           else:
            SourceData2 = spark.read.parquet(CuratedPath)
            if Scd2Flag.upper() == 'TRUE':
                logging.info(f"SCD Flag is set to True")
                ##################################### SCD code#################################
                deltaTable = DeltaTable.forPath(spark, CuratedPath) #Reading original data from staging data lake
                collist = deltaTable.toDF().columns #converting dataframe to list of column
                merge_insert_dict = {} #creating the dictionary used for merge-insert
                for col in collist:
                    if col == 'RowIsCurrent':
                        merge_insert_dict[col]='true'
                    else:#
                        merge_insert_dict[col]="staged_updates."+str(col)
                #SourceData1 = SourceData #
                #SourceData1.drop("SurrogateKey")#
                #DeltaTableDF = deltaTable.toDF()#
                #DeltaTableDF.drop("SurrogateKey")#
                SourceData_updates = SourceData.alias("updates")
                DeltaTable_DF = deltaTable.toDF().alias("original")
                newValueToInsertDF = SourceData_updates.join(DeltaTable_DF ,SourceData_updates.BusinessKeyHash == DeltaTable_DF.BusinessKeyHash).where("original.RowIsCurrent = 'true' AND updates.NonBusinessKeyHash != original.NonBusinessKeyHash")#
                stagedUpdates_part1 = newValueToInsertDF.selectExpr("NULL as mergeKey","updates.*")
                stagedUpdates_part2 = SourceData.alias("updates").selectExpr("updates.BusinessKeyHash as mergeKey","*")#
                stagedUpdates_part3 = stagedUpdates_part2.union(stagedUpdates_part1)
                #current_utc = str(datetime.utcnow().strftime("%Y-%m-%d"))
                #ValidTo = str("9999-21-31")
                timesuffix = str(timesuffix)
                current_utc = datetime.datetime.strptime((timesuffix[:26]).strip(), '%Y-%m-%d %H:%M:%S.%f')
                current_utc_minus_1 = current_utc - datetime.timedelta(seconds=1)
                ValidTo = str("9999-12-31 00:00:00.000000")                    
                #stagedUpdates_part3 = stagedUpdates_part3.withColumn("RowValidFrom",lit(current_utc)).withColumn("RowValidTo",lit(ValidTo))#workaround as
                stagedUpdates_part3 = stagedUpdates_part3.withColumn("RowValidFrom",lit(current_utc)).withColumn("RowValidTo",lit(ValidTo))
                #stagedUpdates_part3 = stagedUpdates_part3.withColumn("RowValidFrom",SourceData.RowValidFrom.cast(DateType()))
                #stagedUpdates_part3 = stagedUpdates_part3.withColumn("RowValidTo",SourceData.RowValidTo.cast(DateType()))
                deltaTable.alias("original").merge(
                    stagedUpdates_part3.alias("staged_updates"),
                    "original."+BusinessKeyHash+" = mergeKey") \
                    .whenMatchedUpdate(condition ="original.RowIsCurrent = 'true' AND original.NonBusinessKeyHash != staged_updates.NonBusinessKeyHash" , set =
                        {   
                            #"RowValidTo": "staged_updates.RowValidFrom",
                            #"RowIsCurrent":"false"
                            "RowValidTo": lit(current_utc_minus_1),
                            "RowIsCurrent":"false"
                        }
                    ).whenNotMatchedInsert( values = merge_insert_dict).execute()
            else:
                logging.info(f"Scd not found")
                deltaTable = DeltaTable.forPath(spark, CuratedPath)#creating delta instance
    #Doing upsert of SCd type 1 in staging zone
                if PartitionKey is None or PartitionKey == '':
                    deltaTable.alias("original").merge(
                    SourceData.alias("changed"),BusinessKeyCondition) \
                    .whenNotMatchedInsertAll() \
                    .whenMatchedUpdateAll(condition= NonBusinessKeyCondition) \
                    .execute()
                else:
                    spark.conf.set("spark.databricks.optimizer.dynamicPartitionPruning","true")
                    deltaTable.alias("original").merge(
                    SourceData.alias("changed"),BusinessKeyCondition + ' AND changed.'+PartitionKey+' = '+'original.'+PartitionKey) \
                    .whenNotMatchedInsertAll() \
                    .whenMatchedUpdateAll(condition= NonBusinessKeyCondition) \
                    .execute()
 
        elif pushtostagingzone.upper() == 'TRUE':
          if upsert.upper() == 'FALSE':
            if PartitionKey is None or PartitionKey == '':
                SourceData.write.format('delta').option('mergeSchema', 'true').mode('overwrite').save(StagingPath)# writing spark data frame as delta format in staging zone  
            else:
                logging.info(f"will do partitioning")
                spark.conf.set("spark.databricks.optimizer.dynamicPartitionPruning","true")
                SourceData.write.format('delta').partitionBy(PartitionKey).option('mergeSchema', 'true').mode('overwrite').save(StagingPath)# writing spark data frame as delta format in staging zone  
          elif upsert.upper() == 'TRUE':     
            exists = check_if_exists(StagingPath)
            if not exists:
                logging.info(f"Running for the first time, creating delta table")                
                SourceData.write.format('delta').option('mergeSchema', 'true').mode('overwrite').save(StagingPath)# writing spark data frame as delta format in staging zone 
            else:
                SourceData2 = spark.read.parquet(StagingPath)
                if Scd2Flag.upper() == 'TRUE':
                    logging.info(f"SCD Flag is set to True")
                ##################################### SCD code#################################
                    deltaTable = DeltaTable.forPath(spark, StagingPath) #Reading original data from staging data lake
                    collist = deltaTable.toDF().columns #converting dataframe to list of column
                    merge_insert_dict = {} #creating the dictionary used for merge-insert
                    for col in collist:
                        if col == 'RowIsCurrent':
                            merge_insert_dict[col]='true'
                        else:#
                            merge_insert_dict[col]="staged_updates."+str(col)

                    SourceData_updates = SourceData.alias("updates")
                    DeltaTable_DF = deltaTable.toDF().alias("original")
                    #newValueToInsertDF = SourceData.alias("updates").join(deltaTable.toDF().alias("original"),BusinessKeyHash).where("original.RowIsCurrent = 'true' AND updates.NonBusinessKeyHash != original.NonBusinessKeyHash")
                    newValueToInsertDF = SourceData_updates.join(DeltaTable_DF ,SourceData_updates.BusinessKeyHash == DeltaTable_DF.BusinessKeyHash).where("original.RowIsCurrent = 'true' AND updates.NonBusinessKeyHash != original.NonBusinessKeyHash")#
                    stagedUpdates_part1 = newValueToInsertDF.selectExpr("NULL as mergeKey","updates.*")
                    #stagedUpdates_part2 = SourceData.alias("updates").selectExpr("updates.BusinessKeyHash as mergeKey","*")
                    stagedUpdates_part2 = SourceData.alias("updates").selectExpr("updates.BusinessKeyHash as mergeKey","*")#
                    stagedUpdates_part3 = stagedUpdates_part2.union(stagedUpdates_part1)
                    #current_utc = str(datetime.utcnow().strftime("%Y-%m-%d"))
                    #ValidTo = str("9999-21-31")
                    timesuffix = str(timesuffix)
                    current_utc = datetime.datetime.strptime((timesuffix[:26]).strip(), '%Y-%m-%d %H:%M:%S.%f')    
                    #current_utc = datetime.datetime.strptime(str(timesuffix), '%Y-%m-%d %H:%M:%S.%f') #str(timesuffix)             
                    current_utc_minus_1 = current_utc - datetime.timedelta(seconds=1)
                    ValidTo = str("9999-12-31 00:00:00.000000")        
#                    stagedUpdates_part3 = stagedUpdates_part3.withColumn("RowValidFrom",lit(current_utc)).withColumn("RowValidTo",lit(ValidTo))#workaround as
                    stagedUpdates_part3 = stagedUpdates_part3.withColumn("RowValidFrom",lit(current_utc)).withColumn("RowValidTo",lit(ValidTo))
                    #stagedUpdates_part3 = stagedUpdates_part3.withColumn("RowValidFrom",SourceData.RowValidFrom.cast(DateType()))
                    #stagedUpdates_part3 = stagedUpdates_part3.withColumn("RowValidTo",SourceData.RowValidTo.cast(DateType()))
                    deltaTable.alias("original").merge(
                    stagedUpdates_part3.alias("staged_updates"),
                    "original."+BusinessKeyHash+" = mergeKey") \
                    .whenMatchedUpdate(condition ="original.RowIsCurrent = 'true' AND original.NonBusinessKeyHash != staged_updates.NonBusinessKeyHash" , set =
                        {   
                            #"RowValidTo": "staged_updates.RowValidFrom",
                            "RowValidTo": lit(current_utc_minus_1),
                            "RowIsCurrent":"false"
                        }
                    ).whenNotMatchedInsert( values = merge_insert_dict).execute()
                else:
                    logging.info(f"Scd not found")           
                    deltaTable = DeltaTable.forPath(spark, StagingPath)#creating delta instance
    #Doing upsert of SCd type 1 in staging zone
                    if PartitionKey is None or PartitionKey == '':
                        deltaTable.alias("original").merge(
                        SourceData.alias("changed"),BusinessKeyCondition) \
                        .whenNotMatchedInsertAll() \
                        .whenMatchedUpdateAll(condition= NonBusinessKeyCondition) \
                        .execute()
                    else:
                        spark.conf.set("spark.databricks.optimizer.dynamicPartitionPruning","true")
                        deltaTable.alias("original").merge(
                        SourceData.alias("changed"),BusinessKeyCondition + ' AND changed.'+PartitionKey+' = '+'original.'+PartitionKey) \
                        .whenNotMatchedInsertAll() \
                        .whenMatchedUpdateAll(condition= NonBusinessKeyCondition) \
                        .execute()
                    
    except Exception as e:
        print(e)
        logging.error(e)
     #   raise RuntimeError(f'invocation_id {context.invocation_id}')
            
    logging.info(f'succesfully written data into staging zone')
    
 #Below calling HTTP azure function that will archive file and move it from landing to raw. for example #intergen-data-mdp-function-dev.azurewebsites.net/api/archive-processed-file?filename=AdventureWorks/Person/Person/Person1.parquet&storage_account=intergendatamdpadlsdev
    contents = urllib.request.urlopen("https://{}.azurewebsites.net/api/archive-processed-file?filename={}/{}&storage_account={}".format(azure_function,SourceName,FileName,storage_account)).read()
if __name__ == "__main__":
        main()