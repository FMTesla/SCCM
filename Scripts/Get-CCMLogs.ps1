<#

		Description: Very basic function to pull all of the logs off a remote machine
		and copy them to a designated location. The $SavePath can obviously be edited to
		wherever you want.

		Inputs: Workstation name.

		Outputs: Copies log files to the destination.

		Example: Get-CCMLogs SkynetPC

#>

Function Get-CCMLogs {
[CmdletBinding()]
 Param(
    [Parameter (Mandatory=$true, 
               Position=0,                           
               ValueFromPipeline=$true,             
               ValueFromPipelineByPropertyName=$true)]             
    [String[]]$ComputerName 
   )#Param
Begin {
 $SMSTSLogs = "\\$ComputerName\c$\_SMSTaskSequence\Logs"
 $CCMLogs = "\\$ComputerName\c$\Windows\CCM\Logs"
 $CCMSetupLogs = "\\$ComputerName\c$\Windows\CCMSetup\Logs"
 $SavePath = "\\(Server)\PulledLogs\$ComputerName"
 
 If ( -Not (Test-Path $SavePath -pathType Container))
 {
 New-Item -Path $SavePath -Type Container -Force
 } 
} #Begin
End { 
  If ( -Not (Test-Path $SMSTSLogs -PathType Container))
    {
    New-Item -Path $SavePath\CCM\Logs -Type Container -Force
    New-Item -Path $SavePath\CCMSetup\Logs -Type Container -Force
	Copy-Item "$CCMLogs\*.*" $SavePath\CCM\Logs -Force -Recurse
    Copy-Item "$CCMSetupLogs\*.*" $SavePath\CCMSetup\Logs -Force -Recurse
    } Else {
    New-Item -Path $SavePath\_SMSTaskSequence\Logs -Type Container -Force
    New-Item -Path $SavePath\CCM\Logs -Type Container -Force
    New-Item -Path $SavePath\CCMSetup\Logs -Type Container -Force
    Copy-Item "$SMSTSLogs\*.*" $SavePath\_SMSTaskSequence\Logs -Force -Recurse
    Copy-Item "$CCMLogs\*.*" $SavePath\CCM\Logs -Force -Recurse
    Copy-Item "$CCMSetupLogs\*.*" $SavePath\CCMSetup\Logs -Force -Recurse
    }
  } #End
 }
