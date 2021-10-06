# Terraform
This is a module to interact with the Terraform Cloud or Enterprise API

# Instructions
```powershell
# Install from PowerShell Gallery
Install-Module Terraform

# Import module (auto imported if in $env:PSModulePath)
Import-Module Terraform

# Get commands in the module
Get-Command -Module Terraform

# Get alias for commands
Get-Alias | ? Source -eq Terraform

# Get help
help Set-TFWorkspaceVariable -Full
```

# Alias for common commands
```powershell
gtfmo -> Get-TFModule
gtfr -> Get-TFRun
gtfs -> Get-TFState
gtfw -> Get-TFWorkspace
gtfwv -> Get-TFWorkspaceVariable
lktfw -> Lock-TFWorkspace
ntfw -> New-TFWorkspace
ntfwv -> New-TFWorkspaceVariable
pbtfmo -> Publish-TFModule
rtfmo -> Remove-TFModule
rtfw -> Remove-TFWorkspace
rtfwv -> Remove-TFWorkspaceVariable
satfr -> Start-TFRun
stfr -> Set-TFRun
stfw -> Set-TFWorkspace
stfwv -> Set-TFWorkspaceVariable
uktfw -> Unlock-TFWorkspace
```

# Connect to Terraform API
1. Login to Terraform and ***Create an API token*** for your user.
2. Use ***Set-Terraform*** to save your **Server**, **Token** and **Org**.
3. Your session will auto import the first server you specify. 
***Connect-Terraform*** can be used if you have multiple servers.
```powershell
# Set your terraform server connection settings
Set-Terraform -Server server1 -Token <token> -Org contoso
Set-Terraform -Server server2 -Token <token> -Org contoso

# View your terraform server connection settings
Get-Terraform

# Select the server connection that you want to use (if not )
Connect-Terraform server2
```
*Note: Use Windows filesystem (DPAPI) to store your token at your own risk.*
*If preferred, you can specify your token with each cmdlet.*

# Examples
Some helpful one-liner commands to manage Terraform

## Workspace
```powershell
# Get-TFWorkspace > group them by terraform-version to get all versions and count of each
gtfw | group terraform-version -NoElement

# Get-TFWorkspace > where the version equals 0.12.24 > Set-TFWorkspace version to 0.12.25
gtfw | ? terraform-version -eq 0.12.24 | stfw -TerraformVersion 0.12.25

# Set-TFWorkspace working directory for a specific workspace (also supports multiple workspaces)
stfw <workspace> -WorkingDirectory v2
```

## Workspace Variable
```powershell
# Get-TFWorkspaceVariabe for a workspace > Format-Table
gtfwv <name> | ft

# New-TFWorkspaceVariable Key=environment, Value=development
ntfwv <name> environment development

# Set-TFWorkspaceVariable Key=token, Value=****, Enable Sensitive flag for secure values (HCL also supported)
stfwv <name> -Key token -Value <token> -Sensitive

# Remove-TFWorkspaceVariable Key=test, surpress confirmation
rtfwv <name> -Key test -Confirm:$false
```

## Module Registry
```powershell
# Get-TFModule to list all modules in the registry > Out-GridView to easily view/sort/filter
gtfmo | ogv

# Get-TFModule for a specific module: List all, select specific or get the latest
gtfmo <name>
gtfmo <name> -Version 0.0.7
gtfmo <name> -Latest

# Get-TFModule for a specific module > where the version is greater than 3.0.0 > Remove-TFModule (confirmation prompted)
gtfmo <name> | ? Version -gt 3.0.0 | rtfmo
```