#Add paging
<# AVAILABLE
Apply a Run
    POST /runs/:run_id/actions/apply
#>

function Get-TFRun {
    <#
    .SYNOPSIS
    Get workspace runs.

    Run cmdlet to list all runs for a given workspace.  Use the CURRENT switch for the current run.
    or 
    Get properties of a specify a Run ID.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    List Runs in a Workspace
        GET /workspaces/:workspace_id/runs

    Get run details
        GET /runs/:run_id

    .LINK
    https://www.terraform.io/docs/cloud/api/run.html
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Position=0,Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName='Wks')]
        [string]$Name,

        [Parameter(ParameterSetName='Wks')]
        [switch]$Current,

        [Parameter(Position=1,Mandatory,ParameterSetName='Run')]
        [Alias('id')]
        [string]$RunId,

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Connect-Terraform"; Continue}

        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        if ($PSCmdlet.ParameterSetName -eq 'Wks') {

            $WorkspaceId = (Get-TFWorkspace -Server $Server -APIToken $APIToken -Name $Name).id
            Write-Verbose "Workspace $Name; WorkspaceId $WorkspaceId"
            if (!$WorkspaceId) {Continue}

            $Uri = "https://$Server/api/v2/workspaces/$WorkspaceId/runs"
            
        } elseif ($PSCmdlet.ParameterSetName -eq 'Run') {

            $Uri = "https://$Server/api/v2/runs/$RunId"
        
        }

        try {

            $Results = (Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get).data

            foreach ($Result in $Results) {
                $Run = ($Result).Attributes
                $Run.PSObject.TypeNames.Insert(0,'Terraform.TFRun')
                $Run | Add-Member -NotePropertyName id -NotePropertyValue $Result.id
                
                if ($Name) {
                    $Run | Add-Member -NotePropertyName name -NotePropertyValue $Name
                }

                $Run

                if ($Current) {break} #exit loop after first output
            }

        } catch {
            Write-Warning "Unable to get run : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

function Set-TFRun {
    <#
    .SYNOPSIS
    Set an ACTION for a specific Run.

    Specify any of the following Actions: APPLY, DISCARD, CANCEL, FORCE-CANCEL, FORCE-EXECUTE

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    Apply a Run
        POST /runs/:run_id/actions/apply

    Discard a Run
        POST /runs/:run_id/actions/discard

    Cancel a Run
        POST /runs/:run_id/actions/cancel

    Forcefully cancel a run
        POST /runs/:run_id/actions/force-cancel

    Forcefully execute a run
        POST /runs/:run_id/actions/force-execute

    .LINK
    https://www.terraform.io/docs/cloud/api/run.html
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidatePattern('^run-')]
        [Alias('id')]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateSet('apply','discard','cancel','force-cancel','force-execute')]
        [string]$Action,

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Connect-Terraform"; Continue}

        $Uri = "https://$Server/api/v2/runs/$RunId/actions/$Action"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        try {

            if ($PSCmdlet.ShouldProcess("$RunId : $Action")) {
                Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Post | Out-Null
            }

        } catch {
            Write-Warning "Unable to $Action on $RunId : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

function Start-TFRun {
    <#
    .SYNOPSIS
    Create a run for a workspace.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    Create a Run
        POST /runs

    .LINK
    https://www.terraform.io/docs/cloud/api/run.html
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$Message = 'Queued from PowerShell',

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Connect-Terraform"; Continue}

        $Uri = "https://$Server/api/v2/runs"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        try {

            $WorkspaceId = (Get-TFWorkspace -Server $Server -APIToken $APIToken -Name $Name).id
            Write-Verbose "Workspace $Name; WorkspaceId $WorkspaceId"
            if (!$WorkspaceId) {Continue}

            $Data = [PSCustomObject]@{
                attributes = [PSCustomObject]@{
                    message = $Message
                }
                relationships = @{workspace=@{data=@{id=$WorkspaceId}}}
            }

            $Body = @{data=$Data} | ConvertTo-Json -Depth 5
            Write-Verbose "$Body"

            Invoke-RestMethod -Uri $Uri -Headers $Headers -Body $Body -Method Post | Out-Null

        } catch {
            Write-Warning "Unable to get run : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

Set-Alias gtfr Get-TFRun
Set-Alias stfr Set-TFRun
Set-Alias satfr Start-TFRun
