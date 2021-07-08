[CmdletBinding()]
param()

# For more information on the Azure DevOps Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    $ErrorActionPreference = "Stop";
    
    $csvfilename= Get-VstsInput -Name csvFile -Require 
    $storageAccount= Get-VstsInput -Name storageAccount -Require
    $accessKey= Get-VstsInput -Name accessKey -Require
    $table= Get-VstsInput -Name table -Require
    $partitionKey= Get-VstsInput -Name partitionKey -Require
    $rowKey= Get-VstsInput -Name rowKey -Require
    $workingdirectory= Get-VstsInput -Name workingDirectory -Require

$csvFullPath=Join-Path -Path $workingdirectory -ChildPath $csvfilename
$csv=Get-Content -Path $csvFullPath | ConvertFrom-Csv 

write-host "Creating table $table if not exists.."
$body = @{    
"TableName"=$table
}

$uri="https://$($storageAccount).table.core.windows.net/Tables?$($accesskey)"
$version = "2017-04-17"
$GMTTime = (Get-Date).ToUniversalTime().toString('R')
$stringToSign = "$GMTTime`n/$storageAccount/$table"
$headers = @{
        'x-ms-date'    = $GMTTime
        'Content-Type'         = "application/json"
        Accept                 = "application/json"
        "x-ms-version" = $version
    }
    $body=$body | ConvertTo-Json
try{
invoke-webrequest -uri $uri -Headers $headers -Method Post -Body $body
}
catch{
}
####end create a table

$body=""

foreach($a in $csv){
$pkey=$a."$($partitionkey)"
$rkey=$a."$($rowkey)"
$a=$a | ConvertTo-Json
$body=$a -replace $PartitionKey,"PartitionKey"
$body=$body -replace $RowKey,"RowKey"
$body=$body -replace "^@",""
$body=$body -replace "=",":"
$body=$body -replace ";",","

$uri="https://$($storageAccount).table.core.windows.net/$($table)(PartitionKey='$($pkey)',RowKey='$($rkey)')?$($accesskey)"
$body
$version = "2017-04-17"
$GMTTime = (Get-Date).ToUniversalTime().toString('R')
$stringToSign = "$GMTTime`n/$storageAccount/$resource"
$headers = @{
        'x-ms-date'    = $GMTTime
        'Content-Type'         = "application/json"
        Accept                 = "application/json"
        "x-ms-version" = $version
    }

    if($a -notlike ""){
    write-host "Uploading data to storage table: $table in storage account: $storageAccount"
    invoke-webrequest -uri $uri -Headers $headers -Method Put -Body $body
    }
}
} 
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
