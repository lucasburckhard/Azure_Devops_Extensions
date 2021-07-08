[CmdletBinding()]
param()

# For more information on the Azure DevOps Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    $ErrorActionPreference = "Stop";
    
    $fortifyUrl= Get-VstsInput -Name baseUrl -Require 
    $ProjectName= Get-VstsInput -Name projectName -Require
    $BuildIdName= Get-VstsInput -Name version -Require
    $SolutionFilePath= Get-VstsInput -Name workingDirectory -Require
    $BuildNumber = $env:BUILD_BUILDNUMBER
    $BuildId     = $env:BUILD_DEFINITIONNAME
    $SSCFPRFileName="FPRFile.fpr"
    $path = "$SolutionFilePath\sca_artifacts"
    
    if($authtoken.length -lt 36){$authtoken=$env:FortifyAuthToken}
   
    ###Example entries for testing purposes###
    #$fortifyUrl = 'https://fortify/ssc'
    #$authtoken="57c9db83-d75c-4e89-a193-ec5d77ec3fca"
    #$ProjectName="RES-TOPS-FTMFundingAPI"
    #$BuildIdName = "1.10.0"
    #$SolutionFilePath = "E:\b\2\_work\604\s\"
    #$TranslateArguments="-64 -Xmx6G -Xss3G -disable-language javascript:tsql"

#setpath & remove any existing FPR file (one will exist if multiple Fortify scan tasks are used in the pipeline)
If(!(test-path $path))
{
    New-Item -ItemType Directory -Force -Path $path
}
Elseif(test-path "$path\$SSCFPRFileName"){
    Remove-Item -Path "$path\$SSCFPRFileName" -Force
}
#change to working directory
cd \
cd "$SolutionFilePath"
#show current directory
pwd

    ##clean existing fortify session for fresh start
    try{
    write-host "Cleaning binaries.."
    write-host ""
    write-host "sourceanalyzer -b $($BuildId) -clean"
    sourceanalyzer -b $BuildId -clean
    write-host ""
    }
    catch{
    write-host "An Error occurred while executing source analyzer clean command."
    $error
    exit 1
    }

    #translate binaries
    try{
    write-host "Attempting to translate binaries..."
    write-host ""
    write-host "sourceanalyzer -b $($BuildId) -64 -Xmx6G -Xss3G -disable-language javascript:tsql:python -libdirs **\* **\* !**/node_modules/** -build-label $($BuildNumber)"
    sourceanalyzer -b $BuildId -disable-language javascript:tsql -libdirs **\* **\*  !**/node_modules/** -build-label $BuildNumber
    write-host ""
    }
    catch{
    write-host "An Error occurred while executing source analyzer translate command."
    $error
    exit 1
    }

    #scan translated files
    try{
    write-host "Attempting to scan binaries.."
    write-host ""
    write-host "sourceanalyzer -b $($BuildId) -scan -f "$($path)\$($SSCFPRFileName)" -build-label $($BuildNumber)"
    sourceanalyzer -b $BuildId -scan -f "$path\$SSCFPRFileName" -build-label $BuildNumber
    write-host ""
    }
    catch{
    write-host "An Error occurred while executing source analyzer scan command."
    $error
    exit 1
    }

    #upload scan to SSC
    try{
    write-host "Attempting to upload scan to Fortify SSC website."
    write-host ""
    write-host "fortifyclient.bat -url ($fortifyUrl) -authtoken $($authtoken) uploadFPR -file "$($path)\$($SSCFPRFileName)" -project $($ProjectName) -version $($BuildIdName)"
    write-host ""
    fortifyclient.bat -url $fortifyUrl -authtoken $authtoken uploadFPR -file "$path\$SSCFPRFileName" -project $ProjectName -version $BuildIdName
    write-host "To verify upload, browse to $($fortifyUrl) and search for $($projectName).  This scan was uploaded to version number $($BuildIDName)."
    write-host ""
    }
    catch{
    write-host "An Error occurred while uploading FPR file to SSC."
    $error
    exit 1
    }
} 
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
