[CmdletBinding()]
param()

# For more information on the Azure DevOps Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    $ErrorActionPreference = "Stop";
    
    $clientId= Get-VstsInput -Name SPNName -Require 
    $TenantID= Get-VstsInput -Name Tenant -Require 
    $clientSecret= Get-VstsInput -Name SPNkey -Require 
    $ServerName= Get-VstsInput -Name ServerName -Require
    $DatabaseName= Get-VstsInput -Name DatabaseName -Require
    $SqlScript=Get-VstsInput -Name Script -Require
   
    $resourceAppIdURI = 'https://database.windows.net/'

    $rawsql=get-content $SqlScript | Out-String

$tokenResponse = Invoke-RestMethod -Method Post -UseBasicParsing `
    -Uri "https://login.windows.net/$($TenantID)/oauth2/token" `
    -Body @{
        resource=$resourceAppIdURI
        client_id=$clientId
        grant_type='client_credentials'
        client_secret=$clientSecret
    } -ContentType 'application/x-www-form-urlencoded'

if ($tokenResponse) {
    Write-debug "Access token type is $($tokenResponse.token_type), expires $($tokenResponse.expires_on)"
    $Token = $tokenResponse.access_token
}


$conn = new-object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = "Server=tcp:$($ServerName),1433;Initial Catalog=$($DatabaseName);Persist Security Info=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" 
$conn.AccessToken = $token

Write-host "Connecting to database $($conn.ConnectionString) and attempting to run sql script:`n $rawsql"


$conn.FireInfoMessageEventOnUserErrors=$false
$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { Write-Verbose "$($_)" }
$conn.add_InfoMessage($handler)

$queries=$rawsql
$queries = $queries -split "GO"

Try{
$conn.Open()
}
Catch
{
Write-Error $_
continue
}

foreach($query in $queries){
if($query -notlike ""){
write-host "$query`n"
$Command = New-Object System.Data.SQLClient.SQLCommand($query,$conn)
$command.CommandTimeout=120
$ds= New-Object System.Data.DataSet
$da= New-Object System.Data.SqlClient.SqlDataAdapter($Command)

Try
{
[void]$da.fill($ds)
}
Catch [System.Data.SqlClient.SqlException] #for sql errors
{
 $Err = $_ 

                 Write-Verbose "Capture SQL Error" 
 
                 Write-Verbose "SQL Error:  $Err"
                 switch ($ErrorActionPreference.tostring()) 
                 { 
                     {'SilentlyContinue','Ignore' -contains $_} {} 
                     'Stop' {     Throw $Err } 
                     'Continue' { Throw $Err} 
                     Default {    Throw $Err} 
                 } 
}
 Catch # For other exception 
             { 
                 Write-Verbose "Capture Other Error"   
 
 
                 $Err = $_ 
 
 
                 Write-Verbose "Other Error:  $Err"
 
 
                 switch ($ErrorActionPreference.tostring()) 
                 { 
                     {'SilentlyContinue','Ignore' -contains $_} {} 
                     'Stop' {     Throw $Err} 
                     'Continue' { Throw $Err} 
                     Default {    Throw $Err} 
                 } 
             } 
             
      }
}

$conn.Close()

} 
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
