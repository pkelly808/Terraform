<# AVAILABLE
Assign an SSH key to a workspace
    PATCH /workspaces/:workspace_id/relationships/ssh-key
Unassign an SSH key from a workspace
    PATCH /workspaces/:workspace_id/relationships/ssh-key
#>

function Get-TFWorkspace {
    <#
    .SYNOPSIS
    Get workspaces in terraform enterprise.

    Run cmdlet to list all workspaces.  Use the NAME parameter for a specific workspace.

    Format-Table view is used, actual Properties names and complete list of properties are visible with Format-List.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens   

    .DESCRIPTION
    List workspaces
        GET /organizations/:organization_name/workspaces
    
    Show workspace
        GET /workspaces/:workspace_id

    .EXAMPLE
    Get-TFWorkspace | ogv

    List workspaces and pipe objects to Out-GridView

    .EXAMPLE
    Get-TFWorkspace -Name workspace1

    List the properties for a specific workspace

    .EXAMPLE
    Get-TFWorkspace -Server tfe -APIToken string

    List using a specific Server and APIToken

    .LINK
    https://www.terraform.io/docs/cloud/api/workspaces.html
    #>

    [CmdletBinding()]
    Param
    (
        [string]$Name,

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org,

        [int]$ResultPageSize = 100
    )

    if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-Terraform"; Continue}
    
    if ($Name) {
        #Show workspace
        $Uri = "https://$Server/api/v2/organizations/$Org/workspaces/$Name"
    } else {
        #List workspaces
        $Uri = "https://$Server/api/v2/organizations/$Org/workspaces"
    }

    $Headers = @{
        Authorization = "Bearer $APIToken"
        'Content-Type' = 'application/vnd.api+json'
    }
    
    $i = 1

    do {
        try {
            
            $Results = (Invoke-RestMethod -Uri "$($Uri)?page%5Bsize%5D=$ResultPageSize&page%5Bnumber%5D=$i" -Headers $Headers -Method Get).Data

            foreach ($Result in $Results) {
                $Workspace = ($Result).Attributes
                $Workspace.PSObject.TypeNames.Insert(0,'Terraform.TFWorkspace')
                $Workspace | Add-Member -NotePropertyName id -NotePropertyValue $Result.id
                $Workspace | Add-Member -NotePropertyName branch -NotePropertyValue $Workspace.'vcs-repo'.branch
                $Workspace
            }

            Write-Verbose "Page $i; Results Count $($Results.count)"
            $i++

        } catch {
            if ($Name) {
                Write-Warning "Unable to get workspace for $Name : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            } else {
                Write-Warning "Unable to get list of workspaces : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            }
            Continue
        }
    } while ($Results.count -eq $ResultPageSize)
}

function New-TFWorkspace {
    <#
    .SYNOPSIS
    Create a new workspace.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    Create a Workspace
        POST /organizations/:organization_name/workspaces

    .LINK
    https://www.terraform.io/docs/cloud/api/workspaces.html
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$WorkingDirectory,

        [string]$Branch = 'master',

        [ValidateSet('Bitbucket','GitHub')]
        [string]$VCS = 'GitHub',

        [string]$Repo = 'TFE/terraform-repo',

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-Terraform"; Continue}

        $Uri = "https://$Server/api/v2/organizations/$Org/workspaces"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        try {

            $OAuthToken = Get-TFOAuthToken -VCS $VCS -Server $Server -APIToken $APIToken -Org $Org

            $Data = @{
                attributes = @{
                    name = $Name
                    'working-directory' = $WorkingDirectory.ToLower()
                    'vcs-repo' = @{
                        identifier = $Repo
                        'oauth-token-id' = $OAuthToken
                        branch = $Branch
                        'default-branch' = $true
                    }
                }
                type = 'workspaces'
            }

            $Body = @{data=$Data} | ConvertTo-Json -Depth 3
            Write-Verbose "$Body"

            if ($PSCmdlet.ShouldProcess($Name)) {
                Invoke-RestMethod -Uri $Uri -Headers $Headers -Body $Body -Method Post | Out-Null
            }
            
        } catch {
            Write-Warning "Unable to create $Name : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

function Set-TFWorkspace {
    <#
    .SYNOPSIS
    Update a workspace.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    Update a Workspace (two options, using Name instead of Id)
        PATCH /workspaces/:workspace_id
        PATCH /organizations/:organization_name/workspaces/:name

    .EXAMPLE
    Set-TFWorkspace workspace -TerraformVersion 0.12.24

    You will be prompted to confirm update.

    .LINK
    https://www.terraform.io/docs/cloud/api/workspaces.html
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$TerraformVersion,
        
        [string]$WorkingDirectory,

        [ValidateSet('Bitbucket','GitHub')]
        [string]$VCS,

        [string]$Repo,

        [string]$Branch,

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-Terraform"; Continue}
        if ($VCS -and !$Repo) {Write-Warning "Set VCS requires Repo"; Continue}

        $Uri = "https://$Server/api/v2/organizations/$Org/workspaces/$Name"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        try {

            $Attributes = New-Object -TypeName PSObject
            if ($TerraformVersion) {$Attributes | Add-Member -NotePropertyMembers @{terraform_version=$TerraformVersion}}
            if ($WorkingDirectory) {$Attributes | Add-Member -NotePropertyMembers @{'working-directory'=$WorkingDirectory}}

            if ($VCS -or $Repo -or $Branch) {
                $VcsRepo = New-Object -TypeName PSObject
                if ($VCS) {
                    $OAuthToken = Get-TFOAuthToken -VCS $VCS -Server $Server -APIToken $APIToken -Org $Org
                    $VcsRepo | Add-Member -NotePropertyMembers @{'oauth-token-id'=$OAuthToken}
                }
                if ($Repo) {$VcsRepo | Add-Member -NotePropertyMembers @{identifier=$Repo}}
                if ($Branch) {$VcsRepo | Add-Member -NotePropertyMembers @{branch=$Branch}}

                $Attributes | Add-Member -NotePropertyMembers @{'vcs-repo'=$VcsRepo}
            }

            $Data = [PSCustomObject]@{
                attributes = $Attributes
                type = 'workspaces'
            }

            $Body = @{data=$Data} | ConvertTo-Json -Depth 3
            Write-Verbose "$Body"

            if ($PSCmdlet.ShouldProcess($Name)) {
                Invoke-RestMethod -Uri $Uri -Headers $Headers -Body $Body -Method Patch | Out-Null
            }
            
        } catch {
            Write-Warning "Unable to update $Name : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

function Lock-TFWorkspace {
    <#
    .SYNOPSIS
    You can lock/unlock a workspace to allow/prevent Terraform runs.

    Lock-TFWorkspace
    UnLock-TFWorkspace
    UnLock-TFWorkspace -Force

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    Lock a workspace
        POST /workspaces/:workspace_id/actions/lock
    Unlock a workspace
        POST /workspaces/:workspace_id/actions/unlock
    Force Unlock a workspace
        POST /workspaces/:workspace_id/actions/force-unlock

    .EXAMPLE
    Lock-TFWorkspace workspace

    Lock a workspace

    .LINK
    https://www.terraform.io/docs/cloud/api/workspaces.html
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string[]]$Name,

        [string]$Reason = 'Locked from Powershell',

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

        foreach ($Workspace in $Name) {
            try {

                $WorkspaceId = (Get-TFWorkspace -Server $Server -APIToken $APIToken -Name $Workspace).id
                Write-Verbose "Workspace $Workspace; WorkspaceId $WorkspaceId"
                if (!$WorkspaceId) {Continue}
    
                $Uri = "https://$Server/api/v2/workspaces/$WorkspaceId/actions/lock"
    
                $Body = @{reason=$Reason} | ConvertTo-Json -Depth 1
                Write-Verbose "$Body"
    
                if ($PSCmdlet.ShouldProcess($Workspace)) {
                    Invoke-RestMethod -Uri $Uri -Headers $Headers -Body $Body -Method Post | Out-Null
                }
    
            } catch {
                Write-Warning "Unable to lock $Workspace : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
                Continue
            }
        }
    }
}

function Unlock-TFWorkspace {
    <#
    .SYNOPSIS
    You can lock/unlock a workspace to allow/prevent Terraform runs.

    Lock-TFWorkspace
    UnLock-TFWorkspace
    UnLock-TFWorkspace -Force

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    Lock a workspace
        POST /workspaces/:workspace_id/actions/lock
    Unlock a workspace
        POST /workspaces/:workspace_id/actions/unlock
    Force Unlock a workspace
        POST /workspaces/:workspace_id/actions/force-unlock

    .EXAMPLE
    Unlock-TFWorkspace workspace

    Unlock a workspace. 

    .EXAMPLE
    Unlock-TFWorkspace workspace -Force

    Force a workspace to be unlocked.

    .LINK
    https://www.terraform.io/docs/cloud/api/workspaces.html
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string[]]$Name,

        [switch]$Force,

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

        foreach ($Workspace in $Name) {
            try {

                $WorkspaceId = (Get-TFWorkspace -Server $Server -APIToken $APIToken -Name $Workspace).id
                Write-Verbose "Workspace $Workspace; WorkspaceId $WorkspaceId"
                if (!$WorkspaceId) {Continue}

                if ($Force) {
                    $Uri = "https://$Server/api/v2/workspaces/$WorkspaceId/actions/force-unlock"
                } else {
                    $Uri = "https://$Server/api/v2/workspaces/$WorkspaceId/actions/unlock"
                }

                if ($PSCmdlet.ShouldProcess($Workspace)) {
                    Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Post | Out-Null
                }

            } catch {
                Write-Warning "Unable to unlock $Workspace : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
                Continue
            }
        }
    }
}

function Remove-TFWorkspace {
    <#
    .SYNOPSIS
    Delete a workspace.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    Delete a workspace
        DELETE /organizations/:organization_name/workspaces/:name

    .LINK
    https://www.terraform.io/docs/cloud/api/workspaces.html#delete-a-workspace
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Name,

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-Terraform"; Continue}
        if (!$Token) {Write-Warning "Missing Token for vault_token key, use Get-CNVToken"; Continue}

        $Uri = "https://$Server/api/v2/organizations/$Org/workspaces/$Name"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        try {

            if ($PSCmdlet.ShouldProcess($Name)) {
                Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Delete | Out-Null
            }
            
        } catch {
            Write-Warning "Unable to delete $Name : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

Set-Alias gtfw Get-TFWorkspace
Set-Alias ntfw New-TFWorkspace
Set-Alias stfw Set-TFWorkspace
Set-Alias lktfw Lock-TFWorkspace
Set-Alias uktfw Unlock-TFWorkspace
Set-Alias rtfw Remove-TFWorkspace
