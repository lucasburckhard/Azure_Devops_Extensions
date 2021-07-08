[CmdletBinding()]
param()

# For more information on the Azure DevOps Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    $ErrorActionPreference = "SilentlyContinue";
    
    $rawdomain= Get-VstsInput -Name baseUrl -Require 
    $homepage= Get-VstsInput -Name homepage -Require
    $urlFileName= Get-VstsInput -Name urlFile -Require
    $workingdirectory= Get-VstsInput -Name workingDirectory -Require
    $loopnumber= Get-VstsInput -Name loopNumber -Require
    
    $outputfile=Join-Path -Path $workingdirectory -ChildPath $urlFileName
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    #Arrays to contain the data 
$UrlHash = @{} 
$TempURLHash =@{} 
$finalHash= @{}
 
#This does the raw crawl of $urls passed into it  
function global:FindURL($url){  
try{
if($finalHash.Keys -notcontains $url){
write-host "Assessing $url"
$finalhash[$url]=$url
    return @((invoke-webrequest -uri $url -ErrorAction SilentlyContinue).links.href) 
    
    }else{write-host "Already assessed $url"}
}
catch{
}

}  
 
#Add everything after 1st level to the hashtable 
function CallFromTheHash ($HashURL) { 

    FindUrl -url $HashURL Where-Object { -not $UrlHash[$_] } | ForEach-Object {if($_ -ne $null){ $UrlHash[$_] = $_} }  
$UrlHash.count 
write-host $HashURL 
} 

 #Add homepage to hashtable 
$UrlHash[$homepage] = $homepage  
$UrlHash.count 

 #Call funtion with $homepage and add results to hashtable 
FindUrl -url $homepage Where-Object { -not $UrlHash[$_] } | ForEach-Object { $UrlHash[$_] = $_ }  

#Loop through hashtable contents  
$i = 2 
For(;$i -le $loopnumber; ){
    foreach ($halfurl in $urlhash.keys) {
        if($halfurl -like "*#*"){if($halfurl -notlike "#*" -and $halfurl -notlike "/#*"){$halfurl=$halfurl.Substring(0,$halfurl.IndexOf("#"))}}
        if($halfurl -notlike "http*" -and $halfurl -notlike "*tel:*" -and $halfurl -notlike "*mailto*" -and $halfurl -notlike "#*"){
            if($halfurl -like "/*"){$halfurl=$homepage.Substring(0,$homepage.Length-1) + $halfurl
                if($TempURLHash.Keys -notcontains $halfurl){$TempURLHash += @{$halfurl = $halfurl}}
            }
            else{$halfurl=$homepage + $halfurl
                if($TempURLHash.Values -notcontains $halfurl){$TempURLHash += @{$halfurl = $halfurl}}
            }
        }elseif($halfurl -like "*$rawdomain*" -and $halfurl -like "http*"){if($TempURLHash.Values -notcontains $halfurl){$TempURLHash += @{$halfurl = $halfurl}}}
    } 
    foreach ($newurl in ($TempURLHash | Select-Object * -Unique).Keys) {CallFromTheHash $newurl}  
$i++ 
} 
##add found urls to an array.
[System.Collections.ArrayList]$array=foreach($halfurl in $UrlHash.Keys){
if($halfurl -like "*#*"){if($halfurl -notlike "#*" -and $halfurl -notlike "/#*"){$halfurl=$halfurl.Substring(0,$halfurl.IndexOf("#"))}}
if($halfurl -notlike "http*" -and $halfurl -notlike "*tel:*" -and $halfurl -notlike "*mailto*" -and $halfurl -notlike "#*"){   
        if($halfurl -like "/*"){$halfurl=$homepage.Substring(0,$homepage.Length-1) + $halfurl
            $halfurl
        }
        else{$halfurl=$homepage + $halfurl
            $halfurl
        }
    }elseif($halfurl -like "*$rawdomain*" -and $halfurl -like "http*"){$halfurl}
}

#Create URLs.txt file. If there is already one present, the found urls will be added to the already existing list. 
if(Test-Path $outputfile){$a=get-content $outputfile
foreach($b in $a){if($array -contains $b){$array.Add($b)}}
Remove-Item -Path $outputfile -force}
New-Item -Path $outputfile -force
$array = $array | Select-Object -Unique | Sort-Object
Set-Content $outputfile ($array | Out-String) -force
write-host "Found the following unique URLs.."
$array | Select-Object -Unique | Sort-Object | Out-String


} 
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
