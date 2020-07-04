<# AVAILABLE
Create a State Version
    POST /workspaces/:workspace_id/state-versions
#>

function Get-TFState {
    <#
    .SYNOPSIS
    Get workspace state.

    Run cmdlet to list all state versions for a given workspace.  Use the CURRENT switch to fetch the current state.
    or 
    Get properties of a specify a state ID.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    List State Versions for a Workspace
        GET /state-versions

    Fetch the Current State Version for a Workspace
        GET /workspaces/:workspace_id/current-state-version

    Show a State Version
        GET /state-versions/:state_version_id

    .EXAMPLE
    Get-TFState -Name workspace

    List all state versions

    .EXAMPLE
    Get-TFWorkspace workspace | Get-TFState -Current

    Get the current state for a workspace

    .EXAMPLE
    Get-TFState workspace | select stateid

    List all state ids for a workspace
    
    .EXAMPLE
    Get-TFState -id sv-8oekDRUuXhUBmG3W

    Get detailed properties of a state

    .EXAMPLE
    Get-TFModule -Server tfe -APIToken string

    List using a specific Server and APIToken

    .LINK
    https://www.terraform.io/docs/cloud/api/state-versions.html
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Position=0,Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName='Wks')]
        [string[]]$Name,

        [Parameter(ParameterSetName='Wks')]
        [switch]$Current,

        [Parameter(Position=1,Mandatory,ParameterSetName='State')]
        [Alias('id')]
        [string]$StateId,

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-Terraform"; Continue}

        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        if ($PSCmdlet.ParameterSetName -eq 'Wks') {

            foreach ($Workspace in $Name) {

                try {
                    if ($Current) {
                        $WorkspaceId = (Get-TFWorkspace -Server $Server -APIToken $APIToken -Name $Workspace).id
                        Write-Verbose "Workspace $Workspace; WorkspaceId $WorkspaceId"
                        if (!$WorkspaceId) {Continue}

                        #Fetch the Current State Version for a Workspace
                        $Uri = "https://$Server/api/v2/workspaces/$WorkspaceId/current-state-version"
                    } else {
                        #List State Versions for a Workspace
                        #Currently supports 1 page of 20 States
                        $Uri = "https://$Server/api/v2/state-versions?filter%5Bworkspace%5D%5Bname%5D=$Workspace&filter%5Borganization%5D%5Bname%5D=$Org"
                    }    

                    $State = (Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get).data
                    $State | Select-Object @{n='name';e={$Workspace}},@{n='stateid';e={$_.id}} -exp attributes

                } catch {
                    Write-Warning "Unable to get state for $Workspace : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
                    Continue
                }
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'State') {

            #Show a State Version
            $Uri = "https://$Server/api/v2/state-versions/$StateId"

            try {

                $State = (Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get).data
                $State | Select-Object @{n='stateid';e={$_.id}} -exp attributes

            } catch {
                Write-Warning "Unable to get state for $StateId : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
                Continue
            }
        }
    }
}

Set-Alias gtfs Get-TFState
