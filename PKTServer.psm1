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
