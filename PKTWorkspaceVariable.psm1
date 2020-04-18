function Get-PKTWorkspaceVariable {
    <#
    .SYNOPSIS
    List variables for a workspace.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-PKTServer to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    https://www.terraform.io/docs/cloud/api/workspace-variables.html

    List Variables
        GET /workspaces/:workspace_id/vars

    .EXAMPLE
    Get-PKTWorkspaceVariable -Name workspace | ogv

    List all variables and pipe objects to Out-GridView

    .EXAMPLE
    Get-PKTWorkspaceVariable workspace1,workspace2

    List all variables for multiple workspaces
    
    .EXAMPLE
    Get-PKTWorkspaceVariable -Name workspace -Server tfe -APIToken string

    List using a specific Server and APIToken
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string[]]$Name,

        [ValidateSet('server1','server2')]
        [string]$Server = $Global:PKTServer,

        [string]$APIToken = $Global:PKTAPIToken,

        [string]$Org = $Global:PKTOrg
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-PKTServer"; Continue}

        $Uri = "https://$Server/api/v2/workspaces"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        foreach ($Workspace in $Name) {

            try {

                $WorkspaceId = (Get-PKTWorkspace -Server $Server -APIToken $APIToken -Name $Workspace).id
                Write-Verbose "Workspace $Workspace; WorkspaceId $WorkspaceId"

                $Variables = (Invoke-RestMethod -Uri "$Uri/$WorkspaceId/vars" -Headers $Headers -Method Get).data

                $Variables | Select-Object id -exp attributes

            } catch {
                Write-Warning "Unable to get a list of $Workspace variables : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
                Continue
            }
        }
    }
}

function New-PKTWorkspaceVariable {
    <#
    .SYNOPSIS
    Create a new variable for a workspace.

    Specify the KEY, VALUE and DESCRIPTION for Workspace to create a new variable.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-PKTServer to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    https://www.terraform.io/docs/cloud/api/workspace-variables.html

    Create a Variable
        POST /workspaces/:workspace_id/vars

    {
        "data": {
            "type":"vars",
            "attributes": {
            "key":"some_key",
            "value":"some_value",
            "description":"some description",
            "category":"terraform",
            "hcl":false,
            "sensitive":false
            }
        }
    }

    .EXAMPLE
    New-PKTWorkspaceVariable workspace -Key webservers -Value 2 -Description 'Number of Web Servers'

    You will be prompted to confirm new variable.
    .EXAMPLE
    New-PKTWorkspaceVariable workspace -Key token -Value tokenstring -Description 'Secure Token' -Sensitive

    Use the optional Sensitive and/or HCL switches.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Key,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Value,
        
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Description,

        [switch]$HCL,

        [switch]$Sensitive,

        [ValidateSet('server1','server2')]
        [string]$Server = $Global:PKTServer,

        [string]$APIToken = $Global:PKTAPIToken,

        [string]$Org = $Global:PKTOrg
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-PKTServer"; Continue}

        $Uri = "https://$Server/api/v2/workspaces"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        try {

            $WorkspaceId = (Get-PKTWorkspace -Server $Server -APIToken $APIToken -Name $Name).id
            Write-Verbose "Workspace $Workspace; WorkspaceId $WorkspaceId"
            if (!$WorkspaceId) {Continue}
            
            $Data = [PSCustomObject]@{
                type = 'vars'
                attributes = [PSCustomObject]@{
                    key = $Key.ToLower()
                    value = $Value.ToLower()
                    description = $Description.ToLower()
                    category = 'terraform'
                    hcl = $HCL.IsPresent
                    sensitive = $Sensitive.IsPresent
                }
            }

            $Body = @{'data'=$Data} | ConvertTo-Json -Depth 3
            Write-Verbose "$Body"

            if ($PSCmdlet.ShouldProcess("$Name : $Key")) {
                Invoke-RestMethod -Uri "$Uri/$WorkspaceId/vars/" -Headers $Headers -Body $Body -Method Post | Out-Null
            }
            
        } catch {
            Write-Warning "Unable to create $Key for $Name : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

function Set-PKTWorkspaceVariable {
    <#
    .SYNOPSIS
    Update an existing variable for a workspace.

    Specify the KEY, VALUE and DESCRIPTION for Workspace to update a variable.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-PKTServer to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    https://www.terraform.io/docs/cloud/api/workspace-variables.html

    Update Variables
        PATCH /workspaces/:workspace_id/vars/:variable_id

    {
        "data": {
            "id":"var-yRmifb4PJj7cLkMG",
            "attributes": {
            "key":"name",
            "value":"mars",
            "description":"some description",
            "category":"terraform",
            "hcl": false,
            "sensitive": false
            },
            "type":"vars"
        }
    }

    .EXAMPLE
    Set-PKTWorkspaceVariable workspace -Key webservers -Value 4

    You will be prompted to confirm variable update.
    .EXAMPLE
    Set-PKTWorkspaceVariable workspace -Key token -Value tokenstring -Description 'Secure Token' -Sensitive

    Use the optional Sensitive and/or HCL switches.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Key,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Value,
        
        [string]$Description,

        [switch]$HCL,

        [switch]$Sensitive,

        [ValidateSet('server1','server2')]
        [string]$Server = $Global:PKTServer,

        [string]$APIToken = $Global:PKTAPIToken,

        [string]$Org = $Global:PKTOrg
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-PKTServer"; Continue}

        $Uri = "https://$Server/api/v2/workspaces"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        try {

            $WorkspaceId = (Get-PKTWorkspace -Server $Server -APIToken $APIToken -Name $Name).id
            Write-Verbose "Workspace $Workspace; WorkspaceId $WorkspaceId"
            if (!$WorkspaceId) {Continue}

            $Variable = Get-PKTWorkspaceVariable -Server $Server -APIToken $APIToken -Name $Name | Where-Object Key -eq $Key

            $Data = [PSCustomObject]@{
                id = $Variable.id
                attributes = [PSCustomObject]@{
                    value = $Value.ToLower()
                    description = if ($Description) {$Description} else {$Variable.description}
                    category = if ($Category) {$Category} else {$Variable.category}
                    hcl = if ($HCL) {$HCL.IsPresent} else {$Variable.hcl}
                    sensitive = if ($Sensitive) {$Sensitive.IsPresent} else {$Variable.sensitive}
                }
                type = 'vars'
            }

            $Body = @{'data'=$Data} | ConvertTo-Json -Depth 3
            Write-Verbose "$Body"

            if ($PSCmdlet.ShouldProcess("$Name : $Key")) {
                Invoke-RestMethod -Uri "$Uri/$WorkspaceId/vars/$($Variable.id)" -Headers $Headers -Body $Body -Method Patch | Out-Null
            }
            
        } catch {
            Write-Warning "Unable to set $Key for $Name : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

function Remove-PKTWorkspaceVariable {
    <#
    .SYNOPSIS
    Delete a variable from a workspace.

    Specify the KEY of the variable that you want to delete for a Workspace.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-PKTServer to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    https://www.terraform.io/docs/cloud/api/workspace-variables.html

    Delete Variables
        DELETE /workspaces/:workspace_id/vars/:variable_id

    .EXAMPLE
    Remove-PKTWorkspaceVariable workspace -Key badkey

    You will be prompted to confirm variable removal.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Key,

        [ValidateSet('server1','server2')]
        [string]$Server = $Global:PKTServer,

        [string]$APIToken = $Global:PKTAPIToken,

        [string]$Org = $Global:PKTOrg
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-PKTServer"; Continue}
        if (!$Token) {Write-Warning "Missing Token for vault_token key, use Get-PKVToken"; Continue}

        $Uri = "https://$Server/api/v2/workspaces"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        try {

            $WorkspaceId = (Get-PKTWorkspace -Server $Server -APIToken $APIToken -Name $Name).id
            Write-Verbose "Workspace $Workspace; WorkspaceId $WorkspaceId"
            if (!$WorkspaceId) {Continue}

            $Variable = Get-PKTWorkspaceVariable -Server $Server -APIToken $APIToken -Name $Name | Where-Object Key -eq $Key

            if ($PSCmdlet.ShouldProcess("$Name : $Key")) {
                Invoke-RestMethod -Uri "$Uri/$WorkspaceId/vars/$($Variable.id)" -Headers $Headers -Method Delete | Out-Null
            }
            
        } catch {
            Write-Warning "Unable to delete $Key for $Name : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}


function Set-PKTWorkspaceToken {
    <#
    .SYNOPSIS
    Update an vault token on multiple workspaces.

    Uses Set-PKTWorkspaceVariable cmdlet but supports multiple workspace names.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-PKTServer to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    Set-PKTWorkspaceVariable -Name $Workspace -Key vault_token -Value $Token -Server $Server -APIToken $APIToken -Org $Org

    .EXAMPLE
    Set-PKTWorkspaceToken -Name workspace1,workspace2 -Token tokenstring

    You will be prompted to confirm variable update.

    .EXAMPLE
    Get-PKTWorkspace | select -f 2 | Set-PKTWorkspaceToken -Token tokenstring -Confirm:$false

    Get all workspaces, select the first two, set the token.  Confirmation prompt will be ignored.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string[]]$Name,

        [string]$Token = $Global:Token,

        [ValidateSet('server1','server2')]
        [string]$Server = $Global:PKTServer,

        [string]$APIToken = $Global:PKTAPIToken,

        [string]$Org = $Global:PKTOrg
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-PKTServer"; Continue}
        if (!$Token) {Write-Warning "Missing Token for vault_token key, use Get-PKVToken"; Continue}

        foreach ($Workspace in $Name) {

            Set-PKTWorkspaceVariable -Name $Workspace -Key vault_token -Value $Token -Server $Server -APIToken $APIToken -Org $Org
                
        }
    }
}

Set-Alias gtwv Get-PKTWorkspaceVariable
Set-Alias ntwv New-PKTWorkspaceVariable
Set-Alias stwv Set-PKTWorkspaceVariable
Set-Alias rtwv Remove-PKTWorkspaceVariable
