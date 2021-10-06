[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

. $PSScriptRoot\Connect.ps1

. $PSScriptRoot\TFModule.ps1
. $PSScriptRoot\TFOAuth.ps1
. $PSScriptRoot\TFRun.ps1
. $PSScriptRoot\TFState.ps1
. $PSScriptRoot\TFWorkspace.ps1
. $PSScriptRoot\TFWorkspaceVariable.ps1