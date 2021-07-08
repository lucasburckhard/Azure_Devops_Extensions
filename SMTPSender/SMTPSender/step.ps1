[CmdletBinding()]
param()

# For more information on the Azure DevOps Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    $ErrorActionPreference = "Stop";
    
    $htmlfile= Get-VstsInput -Name htmlFile -Require 
    $smtpServer= Get-VstsInput -Name smtpServerName -Require
    $Subject= Get-VstsInput -Name subject -Require
    $To= Get-VstsInput -Name to -Require
    $From= Get-VstsInput -Name from -Require
    $workingdirectory= Get-VstsInput -Name workingDirectory -Require

    $htmlfullpath=Join-Path -Path $workingdirectory -ChildPath $htmlfile
    $htmlreport=Get-Content -Path $htmlfullpath

if($htmlreport -like "*<body>*"){
$htmlreport=($htmlreport | out-string).Substring(($htmlreport | out-string).IndexOf("<body>")+6)
$htmlreport=($htmlreport | out-string).Substring(0,($htmlreport | out-string).IndexOf("</body>"))
}
write-host "Sending an email from $from to $to with subject: $subject - and this body of content: "
$htmlreport

    Send-Mailmessage -smtpServer $smtpServer -from $From -to $To -subject $Subject -body $htmlreport -bodyasHTML -priority High

} 
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
