if($env:FunctionApp_ConfigureEnable -eq "True")
{
    Write-Host "Zipping the function codes then publishing"
    #Compress-Archive -Path "Resources/function/*" -Update -DestinationPath "Resources/Archive/function44.zip"
    Compress-Archive -Path "Resources/function/*" -CompressionLevel "Fastest" -DestinationPath "Resources/Archive/function47.zip"
    Write-Host "Zipping Completed and Start Publishing"
    sleep 60
    #Publish-AzWebapp -ResourceGroupName $env:ResouceGroup_Name -Name $env:FunctionApp_Name -ArchivePath "Resources/Archive/function48.zip" -Force
    az webapp deploy --resource-group $env:ResouceGroup_Name --name $env:FunctionApp_Name --src-path "Resources/Archive/function47.zip" --debug
    Write-Host "Publishing Completed"

}