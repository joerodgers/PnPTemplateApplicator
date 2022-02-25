#requires -modules "Az.Resources", "Az.Accounts"

[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials 
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12   

Login-AzAccount -UseDeviceAuthentication

$clientId            = $env:O365_CLIENTID
$thumbprint          = $env:O365_THUMBPRINT
$tenantId            = $env:O365_TENANTID
$certificatePath     = "$PSScriptRoot\function\certificate.pfx"
$certificatePassword = 'pass@word1'
$templatePath        = "$PSScriptRoot\function\azure-function-arm-template.json"
$functionCodePath    = "$PSScriptRoot\function\function.ps1"
$resourceGroupName   = "RG-SPOTEMPLATEAPPLICATOR-NPROD-USEAST"
$templateZipPath     = "$PSScriptRoot\function\templates.zip"
$requirementsZipPath = "$PSScriptRoot\function\requirements.zip"
$subscriptionId      = "d432671f-fd2d-449f-afdf-010ba093eace"


Select-AzSubscription -Subscription $subscriptionId -WarningAction SilentlyContinue

$templateParameters  = @{ 
    clientId               = $clientId
    tenantId               = $tenantId
    certificateThumbprint  = $thumbprint
    certificatePfxPassword = $certificatePassword
    certificatePfxBase64   = [System.Convert]::ToBase64String( (Get-Content -Path $certificatePath -AsByteStream -Raw) )
    functionCode           = (Get-Content -Path $functionCodePath -Raw).ToString()
}

if( Test-Path -Path $templatePath -PathType Leaf )
{

    $deployment = New-AzResourceGroupDeployment `
                    -ResourceGroupName       $resourceGroupName `
                    -TemplateFile            $templatePath  `
                    -TemplateParameterObject $templateParameters

    $deployment.OutputsString
}

if( $deployment -and (Test-Path -Path $templateZipPath -PathType Leaf) )
{
    if( Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $deployment.Outputs.functionAppName.Value )
    {
        $null = Publish-AzWebApp `
                    -ResourceGroupName $resourceGroupName `
                    -Name              $deployment.Outputs.functionAppName.Value `
                    -ArchivePath       $templateZipPath `
                    -Force

        $null = Publish-AzWebApp `
                    -ResourceGroupName $resourceGroupName `
                    -Name              $deployment.Outputs.functionAppName.Value `
                    -ArchivePath       $requirementsZipPath `
                    -Force
    }
}

