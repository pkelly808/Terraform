function Get-PKTWorkspace {
    <#
    .SYNOPSIS
    Get workspaces in terraform enterprise.

    Run cmdlet to list all workspaces.  Use the NAME parameter for a specific workspace.

    Format-Table view is used, actual Properties names and complete list of properties are visible with Format-List.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-PKTServer to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens   

    .DESCRIPTION
    https://www.terraform.io/docs/cloud/api/workspaces.html
    
    List workspaces
        GET /organizations/:organization_name/workspaces
    
    Show workspace
        GET /workspaces/:workspace_id

    .EXAMPLE
    Get-PKTWorkspace | ogv

    List workspaces and pipe objects to Out-GridView

    .EXAMPLE
    Get-PKTWorkspace -Name workspace1

    List the properties for a specific workspace

    .EXAMPLE
    Get-PKTWorkspace -Server tfe -APIToken string

    List using a specific Server and APIToken
    #>

    [CmdletBinding()]
    Param
    (
        [string]$Name,

        [ValidateSet('server1','server2')]
        [string]$Server = $Global:PKTServer,

        [string]$APIToken = $Global:PKTAPIToken,

        [string]$Org = $Global:PKTOrg,

        [int]$ResultPageSize = 100
    )

    if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-PKTServer"; Continue}
    
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
                $Workspace | Add-Member -NotePropertyName id -NotePropertyValue $Result.id
                $Workspace | Add-Member -NotePropertyName branch -NotePropertyValue $Workspace.'vcs-repo'.branch
                $Workspace.PSObject.TypeNames.Insert(0,'PKTWorkspace')
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

Set-Alias gtw Get-PKTWorkspace
