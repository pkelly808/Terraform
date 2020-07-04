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
        }
    }

    $XML = @(Import-Clixml -Path $Script:TerraformConfig)

    if (!($XML.Server)) {
        $Script:Terraform | Select-Object Server,@{n='Token';e={Encrypt $_.Token}},Org | Export-Clixml -Path $Script:TerraformConfig -force
    } elseif ($XML.Server -match "$Server") {
        $XML | Where-Object Server -eq $Server | ForEach-Object {$_.Token=(Encrypt $Token)}
        $XML | Export-Clixml -Path $Script:TerraformConfig -force
    } else {
        $XML += $Script:Terraform | Select-Object Server,@{n='Token';e={Encrypt $_.Token}},Org
        $XML | Export-Clixml -Path $Script:TerraformConfig -force
    }
}

function Connect-Terraform {
    <#
    .SYNOPSIS
    Set Terraform server connection for this session.

    .DESCRIPTION
    The first server stored in your config file is automatically imported when you import this module.

    Use Get-Terraform and Set-Terraform to manage your server connections.

        WARNING: Use this to store the token on a filesystem at your own risk
                 Only supported on Windows via Data Protection API
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Server
    )

    $Script:Terraform = Get-Terraform | Where-Object Server -eq $Server
    
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
