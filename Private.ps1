function Test-IsWindows {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    end {
        !(Test-Path -Path Variable:\IsWindows) -or $IsWindows
    }
}

function Get-TerraformConfig {
    [CmdletBinding()]
    param()

    end {
        if (Test-IsWindows) {
            Join-Path -Path $env:APPDATA -ChildPath "$env:USERNAME-Terraform.xml"
        } else {
            Join-Path -Path $env:HOME -ChildPath '.terraform'
        }
    }
}
