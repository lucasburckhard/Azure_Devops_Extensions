[CmdletBinding()]
param()

# For more information on the Azure DevOps Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    $ErrorActionPreference = "Stop";
    
    $urlsfile= Get-VstsInput -Name urlFile -Require 
    $waveApiKey= Get-VstsInput -Name waveKey -Require
    $workingdirectory= Get-VstsInput -Name workingDirectory -Require

    $urlfullpath=Join-Path -Path $workingdirectory -ChildPath $urlsfile
    $content=Get-Content -Path $urlfullpath | Select-Object -Unique
    $epoch="20000000000000000000" - (Get-Date).Ticks
    $GMTTime = (Get-Date).ToUniversalTime().toString('R')
    

write-host "`nAssessing Urls:`n`n"

$urlreport=foreach($a in $content){if($a -notlike ""){$response=Invoke-WebRequest -Uri "http://wave.webaim.org/api/request?key=$($waveApiKey)&url=$($a)&reporttype=1&format=json"
$responseArray+="$a`n$($response.Content)`n`n"
$object=$response.Content | ConvertFrom-Json
[Management.Automation.PSObject]@{
Hash="$($a.GetHashCode())"
Timestamp=$GMTTime
Epoch=$epoch
Url=$a
BasicErrors=$object.categories.error.count
ContrastErrors=$object.categories.contrast.count
Alerts=$object.categories.alert.count
Features=$object.categories.feature.count
Structure=$object.categories.structure.count
Aria=$object.categories.aria.count
WaveUrl=$object.statistics.waveurl}}}

$responseArray

$csvreport=$urlreport | where { $_.url -notlike "" } | %{New-Object psobject -Property $_} | select Hash,Epoch,Url,BasicErrors,ContrastErrors,Alerts,Features,Structure,Aria,WaveUrl,Timestamp | ConvertTo-Csv -NoTypeInformation
$csvpath=Join-Path -Path $workingdirectory -ChildPath "wave.txt"
if(Test-Path $csvpath){Remove-Item -Path $csvpath -Force}
New-Item -Path $csvpath -Force
Set-Content $csvpath $csvreport -Force

$csvreport=$urlreport | where { $_.url -notlike "" } | %{New-Object psobject -Property $_} | select Url,BasicErrors,ContrastErrors,Alerts,Features,Structure,Aria,WaveUrl,Timestamp | ConvertTo-Html
$csvpath=Join-Path -Path $workingdirectory -ChildPath "wave.html"
if(Test-Path $csvpath){Remove-Item -Path $csvpath -Force}
New-Item -Path $csvpath -Force
Set-Content $csvpath $csvreport -Force

} 
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
