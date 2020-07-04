<#AVAILABLE
OAUTH CLIENTS API
Show an OAuth Client
    GET /oauth-clients/:id
Create an OAuth Client
    POST /organizations/:organization_name/oauth-clients
Update an OAuth Client
    PATCH /oauth-clients/:id
Destroy an OAuth Client
    DELETE /oauth-clients/:id

OAUTH TOKENS
List OAuth Tokens
    GET /oauth-clients/:oauth_client_id/oauth-tokens
Show an OAuth Token
    GET /oauth-tokens/:id
Update an OAuth Token
    PATCH /oauth-tokens/:id
Destroy an OAuth Token
    DELETE /oauth-tokens/:id
#>

function Get-TFOAuthToken {
    <#
    .SYNOPSIS
    Returns OAuth Token from VCS OAuth Client.

    An OAuth Client represents the connection between an organization and a VCS provider.

    The oauth-token object represents a VCS configuration which includes the OAuth connection and the associated OAuth token. 
    This object is used when creating a workspace to identify which VCS connection to use.

    .DESCRIPTION
    List OAuth Clients
        GET /organizations/:organization_name/oauth-clients
    List OAuth Clients
        GET /organizations/:organization_name/oauth-clients
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidateSet('Bitbucket','GitHub')]
        [string]$VCS,

        [string]$Server = $Terraform.Server,

        [string]$APIToken = $Terraform.Token,

        [string]$Org = $Terraform.Org
    )

    PROCESS {
        
        if (!$Server -or !$APIToken) {Write-Warning "Missing Server and APIToken, use Set-Terraform"; Continue}

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
