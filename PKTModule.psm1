function Get-PKTModule {
    <#
    .SYNOPSIS
    Get modules in terraform enterprise registry.

    Run cmdlet to list all modules.  Use the NAME parameter to list all available versions.  
    Specify the NAME with the specific VERSION or LATEST switch to get module properties.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-PKTServer to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    https://www.terraform.io/docs/registry/api.html

    List Modules
        GET	<base_url>/:namespace

    List Available Versions for a Specific Module
        GET	<base_url>/:namespace/:name/:provider/versions

    List Latest Version of Module for All Providers
        GET	<base_url>/:namespace/:name

    Get a Specific Module
        GET	<base_url>/:namespace/:name/:provider/:version

    .EXAMPLE
    Get-PKTModule | ogv

    List Modules and pipe objects to Out-GridView

    .EXAMPLE
    Get-PKTModule -Name instance

    List all versions of a specific Module

    .EXAMPLE
    Get-PKTModule -Name instance -Latest

    List the latest version of a specific Module

    .EXAMPLE
    Get-PKTModule -Name instance -Version 0.0.1

    List all properties of a specific Module version

    .EXAMPLE
    Get-PKTModule -Server tfe -APIToken string

    List using a specific Server and APIToken
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Version,

        [switch]$Latest,

        [ValidateSet('aws','azurerm','google','vsphere')]
        [string]$Provider = 'azurerm',

        [ValidateSet('server1','server2')]
        [string]$Server = $Global:PKTServer,

        [string]$APIToken = $Global:PKTAPIToken,

        [string]$Org = $Global:PKTOrg,

        [int]$ResultPageSize = 20
    )

    if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-PKTServer"; Continue}
        
    $Uri = "https://$Server/api/registry/v1/modules"
    $Headers = @{
        Authorization = "Bearer $APIToken"
        'Content-Type' = 'application/vnd.api+json'
    }

    if ($Name) {

        try {

            if ($Version) {
                #Get a Specific Module
                $Results = (Invoke-RestMethod -Uri "$($Uri)/$Org/$Name/$Provider/$Version" -Headers $Headers -Method Get)
                $Results
            } else {
                if ($Latest) {
                    #List Latest Version of Module for All Providers
                    $Results = (Invoke-RestMethod -Uri "$($Uri)/$Org/$Name" -Headers $Headers -Method Get).Modules
                    $Results
                } else {
                    #List Available Versions for a Specific Module
                    $Results = (Invoke-RestMethod -Uri "$($Uri)/$Org/$Name/$Provider/versions" -Headers $Headers -Method Get).Modules
                    foreach ($Version in ($Results | Select-Object -ExpandProperty Versions).version) {
                        [PSCustomObject]@{
                            Name = $Name
                            Version = $Version
                        }
                    }
                }
            }
        } catch {
            Write-Warning "Unable to get modules for $Name : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }

    } else {

        try {

            $i = 0

            do {
                #List Modules (sort is done per page and not for the entire results)
                $Results = (Invoke-RestMethod -Uri "$($Uri)?namespace=$Org&limit=$ResultPageSize&offset=$i" -Headers $Headers -Method Get).Modules | Sort-Object Provider,Name
                $Results
                
                Write-Verbose "Page $i; Results Count $($Results.count)"
                $i += $ResultPageSize
                
            } while ($Results.count -eq $ResultPageSize)

        } catch {
            Write-Warning "Unable to get modules : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }    
}

Set-Alias gtm Get-PKTModule
