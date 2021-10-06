<#AVAILABLE
OAUTH CLIENTS API
https://www.terraform.io/docs/cloud/api/oauth-clients.html
Show an OAuth Client
    GET /oauth-clients/:id
Create an OAuth Client
    POST /organizations/:organization_name/oauth-clients
Update an OAuth Client
    PATCH /oauth-clients/:id
Destroy an OAuth Client
    DELETE /oauth-clients/:id

OAUTH TOKENS
https://www.terraform.io/docs/cloud/api/oauth-tokens.html
List OAuth Tokens
    GET /oauth-clients/:oauth_client_id/oauth-tokens
Show an OAuth Token
    GET /oauth-tokens/:id
Update an OAuth Token
    PATCH /oauth-tokens/:id
Destroy an OAuth Token
    DELETE /oauth-tokens/:id
#>

function Get-TFOAuthClient {
    <#
    .SYNOPSIS
    Returns VCS OAuth Clients.

    An OAuth Client represents the connection between an organization and a VCS provider.

    This endpoint allows you to list VCS connections between an organization and a VCS provider (GitHub, Bitbucket, or GitLab) for use when creating or setting up workspaces.

    .DESCRIPTION
    List OAuth Clients
        GET /organizations/:organization_name/oauth-clients
    #>

    [CmdletBinding()]
    Param
    (
        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Connect-Terraform"; Continue}

        $Uri = "https://$Server/api/v2"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }
        
        try{
            $OAuthClients = (Invoke-RestMethod "$Uri/organizations/$Org/oauth-clients" -Headers $Headers -Method Get).data
            
            foreach ($OAuthClient in $OAuthClients){
                [PSCustomObject]@{
                    Name=$OAuthClient.attributes.name
                    Id=$OAuthClient.id
                }
            }
            
        }
        catch{
            Write-Warning "Unable to get OAuth Client : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}

function Get-TFOAuthToken {
    <#
    .SYNOPSIS
    Returns OAuth Token from VCS OAuth Client.

    An OAuth Client represents the connection between an organization and a VCS provider.

    The oauth-token object represents a VCS configuration which includes the OAuth connection and the associated OAuth token. 
    This object is used when creating a workspace to identify which VCS connection to use.

    .DESCRIPTION
    List all the OAuth Tokens for a given OAuth Client
        GET /oauth-clients/:oauth_client_id/oauth-tokens
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [string]$VCS,

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Connect-Terraform"; Continue}

        $Uri = "https://$Server/api/v2"
        $Headers = @{
            Authorization = "Bearer $APIToken"
            'Content-Type' = 'application/vnd.api+json'
        }
        
        try{
            $OAuthClients = (Invoke-RestMethod "$Uri/organizations/$Org/oauth-clients" -Headers $Headers -Method Get).data
            $OAuthClient = ($OAuthClients | Where-Object {$_.attributes -match $VCS}).id
            Write-Verbose "VCS $VCS : OAuthClient $OAuthClient"

            (Invoke-RestMethod "$Uri/oauth-clients/$OAuthClient/oauth-tokens" -Headers $Headers -Method Get).data.id
        }
        catch{
            Write-Warning "Unable to get OAuth Token : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
    }
}
