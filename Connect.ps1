function Get-Terraform {
    <#
    .SYNOPSIS
    Get Terraform server configuration.

    .DESCRIPTION
    Get the Server name, API Token and Org stored in your local config file.
    #>

    [CmdletBinding()]
    param()

    function Decrypt {
        param($String)
        
        if ($String -is [System.Security.SecureString]) {
            [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($String))
        }
    }

    try {
        Import-Clixml -Path $Script:TerraformConfig | Select-Object -Property Server,@{n='Token';e={Decrypt $_.Token}},Org
    } catch {
        Write-Warning "Unable to import config file $($Script:TerraformConfig) : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
    }
}

function Set-Terraform {
    <#
    .SYNOPSIS
    Set Terraform server configuration.

    .DESCRIPTION
    Set the Server name, API Token and Org to store in your local config file.

    Multiple servers are supported.  Use Connect-Terraform to switch servers.

        WARNING: Use this to store the token on a filesystem at your own risk
                 Only supported on Windows via Data Protection API
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Server,

        [Parameter(Mandatory)]
        [string]$Token,

        [Parameter(Mandatory)]
        [string]$Org
    )

    Switch ($PSBoundParameters.Keys) {
        'Server'    {$Script:Terraform.Server = $Server}
        'Token'     {$Script:Terraform.Token = $Token}
        'Org'       {$Script:Terraform.Org = $Org}
    }

    function Encrypt {
        param([string]$String)
        
        if ($String -notlike '' -and (Test-IsWindows)) {
            ConvertTo-SecureString -String $String -AsPlainText -Force
        } else {
            ConvertTo-SecureString -String $String -AsPlainText -Force
        }
    }

    $XML = @(Import-Clixml -Path $Script:TerraformConfig)

    if (!($XML.Server)) {
        #No file, create new file
        $Script:Terraform | Select-Object Server,@{n='Token';e={Encrypt $_.Token}},Org | Export-Clixml -Path $Script:TerraformConfig -force
    } elseif ($XML.Server -match "$Server") {
        #File exists, update existing server
        $XML | Where-Object Server -eq $Server | ForEach-Object {$_.Token=(Encrypt $Token)}
        $XML | Export-Clixml -Path $Script:TerraformConfig -force
    } else {
        #File exists, add new server
        $XML += $Script:Terraform | Select-Object Server,@{n='Token';e={Encrypt $_.Token}},Org
        $XML | Export-Clixml -Path $Script:TerraformConfig -force
    }
}

function Connect-Terraform {
    <#
    .SYNOPSIS
    Load autentication token into memory.  Load via Terracreds (cross platform) or from encrypted config file (Windows).

    Terracreds is preferred and leverages the operating system vault: https://github.com/tonedefdev/terracreds

    .DESCRIPTION
    With Terracreds:
        Connect-Terraform app.terraform.io -Org <org>

    Without Terracreds (Windows Only):
        Use Get-Terraform and Set-Terraform to manage your server connections.

        WARNING: Use this to store the token on a filesystem at your own risk
                 Only supported on Windows via Data Protection API
    
    .EXAMPLE
    Connect-Terraform -Server app.terraform.io -Org MyOrg -Terracreds
    
    Using -Terracreds will retrieve your token from your local credential manager.  -Org is required.

    .EXAMPLE
    Connect-Terraform -Server app.terraform.io

    Retrieve your token from your encrypted config file.  Only supported by Windows.
    Note: The first server stored in your config file is automatically loaded when you import this module.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory)]
        [string]$Server,
        
        [Parameter(Mandatory,ParameterSetName='Terracreds')]
        [string]$Org,

        [Parameter(Mandatory,ParameterSetName='Terracreds')]
        [switch]$Terracreds
    )

    if ($Terracreds) {

        try {
            $Script:Terraform = [PSCustomObject]@{
                Server = $Server
                Token = (Invoke-Expression -Command "terracreds get $Server" | ConvertFrom-Json).token
                Org = $Org
            }
        } catch {
            Write-Warning "Terracreds error for $Server. Use 'terracreds --help' : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
            Continue
        }
        
    } else {

        $Script:Terraform = Get-Terraform | Where-Object Server -eq $Server

    }
}

$TerraformConfig = Get-TerraformConfig

# Create initial file until Set-Terraform is run
if (!(Test-Path -Path $Script:TerraformConfig -ea SilentlyContinue)) {
    try {

        [PSCustomObject]@{
            Server = $null
            Token = $null
            Org = $null
        } | Export-Clixml -Path $Script:TerraformConfig -force

    } catch {
        Write-Warning "Unable to create config file $($Script:TerraformConfig) : $($_.Exception.Message) : Line $($_.InvocationInfo.ScriptLineNumber)"
    }
}

$Terraform = (Get-Terraform)[0]
