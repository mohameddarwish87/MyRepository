[CmdletBinding()]
param (
    $DefaultDirectory,
    $SqlServer,
    $Database,
##    $DatabaseSchema,
##    $DatabaseScopedCredential,
##   $DatabaseMasterKey,
    $ClientId,
    $ClientSecret,
    $TenantId
)

$currentDirectory = $DefaultDirectory
$sqlServerInstance = $SqlServer
$sqlDatabase = $Database
##$schema = $DatabaseSchema
##$scopedCredential = $DatabaseScopedCredential
##$masterKey = $DatabaseMasterKey
$clientid = $ClientId
$tenantid = $TenantId
$secret = $ClientSecret

#Generate Access Token
$request = Invoke-RestMethod -Method POST `
           -Uri "https://login.microsoftonline.com/$tenantid/oauth2/token"`
           -Body @{ resource="https://database.windows.net/"; grant_type="client_credentials"; client_id=$clientid; client_secret=$secret }`
           -ContentType "application/x-www-form-urlencoded"
$access_token = $request.access_token


cd "$currentDirectory/SynapseSQLObjectsArtifacts/Resources/Synapse/sqlscript"

#Function to execute SQL Scripts
function ExecuteSqlScripts([string] $query, [string] $database){
        
        try
        {
            #Execute SQL Scripts
            if($query)
            {
                Invoke-Sqlcmd -Query $query -ServerInstance $sqlServerInstance -Database $database -AccessToken $access_token -QueryTimeout 36000 -ErrorAction 'Stop'
            }
            else 
            {
                Write-Host "No SQL Scripts Found."
            }
        }
        catch
        {
            #Error Logging
            Write-Host "##vso[task.LogIssue type=error;]Error message : $error"
            throw
        }
        finally
        {
            #Close the DB connections
            [System.Data.SqlClient.SqlConnection]::ClearAllPools()
        }

}

#Create Database
##$createDatabase = "IF NOT EXISTS(SELECT [name] FROM sys.databases WHERE [name] = '$sqlDatabase')`n BEGIN `n CREATE DATABASE $sqlDatabase `n END `n GO"
##ExecuteSqlScripts $createDatabase "MASTER"

#Create Database Master Key
##$createMasterKeyEncryption = "IF NOT EXISTS(SELECT [name] from sys.symmetric_keys WHERE [name] = '##MS_DatabaseMasterKey##')`n BEGIN `n CREATE MASTER KEY ENCRYPTION BY PASSWORD = '$masterKey' `n END `n GO"
##ExecuteSqlScripts $createMasterKeyEncryption $sqlDatabase

#Create Database Scoped Credential
##$createScopedCredential = "IF NOT EXISTS(SELECT [name] from sys.database_scoped_credentials WHERE [name] = '$scopedCredential')`n BEGIN `n CREATE DATABASE SCOPED CREDENTIAL $scopedCredential WITH IDENTITY = 'Managed Identity' `n END `n GO"
##ExecuteSqlScripts $createScopedCredential $sqlDatabase

#Create Database Schema
##$createSchema = "IF NOT EXISTS(SELECT [name] FROM sys.schemas WHERE [name] = '$schema')`n BEGIN `n EXEC('CREATE SCHEMA $schema') `n END `n GO"
##ExecuteSqlScripts $createSchema $sqlDatabase

#Read all the SQL Scripts
#Get-ChildItem "$currentDirectory/SynapseSQLScripts/synapse/sqlscript" |
Get-ChildItem "$currentDirectory/SynapseSQLObjectsArtifacts/Resources/Synapse/sqlscript" |
Foreach-Object {

    $fileName = $_.BaseName + '.json'
    Write-Host $fileName
    #Get the SQL Script type
    $scriptType = (Get-Content $fileName | ConvertFrom-Json)
	Write-Host "Script type0 is " $scriptType
    $scriptType = (Get-Content $fileName | ConvertFrom-Json).properties
	Write-Host "Script type1 is " $scriptType
	$scriptType = (Get-Content $fileName | ConvertFrom-Json).properties.folder
	Write-Host "Script type2 is " $scriptType
	$scriptType = (Get-Content $fileName | ConvertFrom-Json).properties.folder.name
	Write-Host "Script type3 is " $scriptType

        $query = (Get-Content $fileName | ConvertFrom-Json).properties.content.query
		Write-Host "Query is " $query
        $storedProcedures = $storedProcedures + $query + "`n"  
		Write-Host "stored proc is " $storedProcedures

 
}

#Execute SQL Scripts
#$sqlScript = $externalDataSources + $externalFileFormats + $externalTables + $views + $storedProcedures
$sqlScript =  $storedProcedures
Write-Host "final sql script is " $sqlScript
ExecuteSqlScripts $sqlScript $sqlDatabase