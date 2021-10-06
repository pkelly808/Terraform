<# AVAILABLE
https://www.terraform.io/docs/cloud/api/run.html
Search Modules
    GET	<base_url>/search
Latest Version for a Specific Module Provider
    GET	<base_url>/:namespace/:name/:provider
Download Source Code for a Specific Module Version
    GET	<base_url>/:namespace/:name/:provider/:version/download
Download the Latest Version of a Module
    GET	<base_url>/:namespace/:name/:provider/download

https://www.terraform.io/docs/cloud/api/modules.html
Create a Module
    POST /organizations/:organization_name/registry-modules
Create a Module Version
    POST /registry-modules/:organization_name/:name/:provider/versions

Upload a Module Version
    PUT https://archivist.terraform.io/v1/object/<UNIQUE OBJECT ID>
#>

function Get-TFModule {
    <#
    .SYNOPSIS
    Get modules in terraform enterprise registry.

    Run cmdlet to list all modules.  Use the NAME parameter to list all available versions.  
    Specify the NAME with the specific VERSION or LATEST switch to get module properties.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    List Modules
        GET	<base_url>/:namespace

    List Available Versions for a Specific Module
        GET	<base_url>/:namespace/:name/:provider/versions

    List Latest Version of Module for All Providers
        GET	<base_url>/:namespace/:name

    Get a Specific Module
        GET	<base_url>/:namespace/:name/:provider/:version

    .EXAMPLE
    Get-TFModule | ogv

    List Modules and pipe objects to Out-GridView

    .EXAMPLE
    Get-TFModule -Name instance

    List all versions of a specific Module

    .EXAMPLE
    Get-TFModule -Name instance -Latest

    List the latest version of a specific Module

    .EXAMPLE
    Get-TFModule -Name instance -Version 0.0.1

    List all properties of a specific Module version

    .LINK
    https://www.terraform.io/docs/registry/api.html
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Version,

        [switch]$Latest,

        [ValidateSet('azurerm','vsphere','infoblox','chef','aws')]
        [string]$Provider = 'azurerm',

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org,

        [int]$ResultPageSize = 20
    )

    if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Connect-Terraform"; Continue}
        
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
                            Name = $name
                            Version = $version
                            Provider = $provider
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

function Publish-TFModule {
    <#
    .SYNOPSIS
    Publishes a new registry module from a VCS repository, with module versions managed automatically by the repository's tags.

    Name: TFE/terraform-<PROVIDER>-<NAME>

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    Publish a Module from a VCS
        POST /registry-modules
        
    .EXAMPLE
    Publish-TFModule -Name terraform-azurerm-notification-hub -VCS TFE

    Publish the module notification-hub using <VCS>/terraform-<PROVIDER>-<NAME>

    .LINK
    https://www.terraform.io/docs/cloud/api/modules.html
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidateSet('Bitbucket','GitHub')]
        [string]$VCS,

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Connect-Terraform"; Continue}

        $Uri = "https://$Server/api/v2/registry-modules"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }

        $OAuthToken = Get-TFOAuthToken -VCS $VCS -Server $Server -APIToken $APIToken -Org $Org

        try {

            $Data = @{
                attributes = @{
                    'vcs-repo' = @{
                        identifier = $Name
                        'oauth-token-id' = $OAuthToken
                        display_identifier = $Name
                    }
                }
                type = 'registry-modules'
            }

            $Body = @{data=$Data} | ConvertTo-Json -Depth 3
            Write-Verbose "$Body"

            if ($PSCmdlet.ShouldProcess($Name)) {
                Invoke-RestMethod -Uri $Uri -Headers $Headers -Body $Body -Method Post | Out-Null
            }

        } catch {
            Write-Warning "Unable to publish $Name : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

function Remove-TFModule {
    <#
    .SYNOPSIS
    Delete modules in terraform enterprise registry.

    Delete a specific VERSION or use the ALL switch to remove the entire module.

    Specify the SERVER, APITOKEN and ORG within the cmdlet or use Set-Terraform to store them globally.
    APIToken can be generated at https://<TFE>/app/settings/tokens

    .DESCRIPTION
    Delete a Module - specific version
        POST /registry-modules/actions/delete/:organization_name/:name/:provider/:version

    Delete a Module - entire module
        POST /registry-modules/actions/delete/:organization_name/:name

    .EXAMPLE
    Get-TFModule notification-hub -Latest | Remove-TFModule

    Get latest module and delete it.

    .EXAMPLE
    Remove-TFModule notification-hub -All

    Delete all versions of the module

    .LINK
    https://www.terraform.io/docs/cloud/api/modules.html
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,Position=1,ParameterSetName='Ver')]
        [string]$Version,

        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName,Position=2,ParameterSetName='Ver')]
        [ValidateSet('azurerm','vsphere','infoblox','chef','aws')]
        [string]$Provider = 'azurerm',

        [Parameter(Mandatory,Position=1,ParameterSetName='All')]
        [switch]$All,

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

        try {

            if ($PSCmdlet.ParameterSetName -eq 'Ver') {
                $Uri = "https://$Server/api/v2/registry-modules/actions/delete/$Org/$Name/$Provider/$Version"
                $Confirm = "$Name $Version"
            } elseif ($PSCmdlet.ParameterSetName -eq 'All') {
                $Uri = "https://$Server/api/v2/registry-modules/actions/delete/$Org/$Name"
                $Confirm = "$Name All"
            }

            if ($PSCmdlet.ShouldProcess($Confirm)) {
                Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Post | Out-Null
            }

        } catch {
            Write-Warning "Unable to remove $Name : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

Set-Alias gtfmo Get-TFModule
Set-Alias pbtfmo Publish-TFModule
Set-Alias rtfmo Remove-TFModule
