function Set-PKTServer {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('server1','server2')]
        [string]$Server,

        [string]$APIToken,

        [string]$Org = 'DefaultOrg'
    )

    $Global:PKTServer = $Server
    $Global:PKTAPIToken = $APIToken
    $Global:PKTOrg = $Org
}

function Get-PKTServer {

    if (!$Global:PKTServer -and !$Global:PKTAPIToken) {Write-Warning "Missing Server and APIToken, use Set-PKTServer"; Continue}

    [PSCustomObject]@{
        Server = $Global:PKTServer
        APIToken = if ($Global:PKTAPIToken) {$true} else {$false}
        Org = $Global:PKTOrg
    }
}

function Clear-PKTServer {

    Clear-Variable -Scope Global -Name PKTServer, PKTAPIToken, PKTOrg -ea SilentlyContinue

}

<# API didn't work w/ admin or org token
function Get-PKTServerVersion {

    [CmdletBinding()]
    Param
    (
        [ValidateSet('server1','server2')]
        [string]$Server = $Global:PKTServer,

        [string]$APIToken = $Global:PKTAPIToken

        #[int]$ResultPageSize = 100
    )

    if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-PKTServer"; Continue}
    
    $Uri = "https://$Server/api/v2/admin/terraform-versions"

    $Headers = @{
        Authorization = "Bearer $APIToken"
        'Content-Type' = 'application/vnd.api+json'
    }
    
    try {
        
        $Results = (Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get)
        #$Results | Select-Object Id -ExpandProperty Attributes
        $Results
        
    } catch {
        Write-Warning "Unable to get list of terraform versions : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
        Continue
    }
}
#>
