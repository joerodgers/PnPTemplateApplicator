
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials 
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12   

# Login-AzAccount -UseDeviceAuthentication

Select-AzSubscription -Subscription "d432671f-fd2d-449f-afdf-010ba093eace" -WarningAction SilentlyContinue

$clientId            = $env:O365_CLIENTID
$thumbprint          = $env:O365_THUMBPRINT
$tenantId            = $env:O365_TENANTID
$certificatePath     = "$PSScriptRoot\AADAppPrincipalCertificate.pfx"
$certificatePassword = 'pass@word1'
$templatePath        = "$PSScriptRoot\azure-function-arm-template.json"
$functionCodePath    = "$PSScriptRoot\function.ps1"
$resourceGroupName   = "RG-SPOTEMPLATEAPPLICATOR-NPROD-USEAST"
$templateZipPath     = "$PSScriptRoot\templates.zip"
$subscriptionId      = "d432671f-fd2d-449f-afdf-010ba093eace"

Select-AzSubscription -Subscription $subscriptionId -WarningAction SilentlyContinue

$templateParameters  = @{ 
    clientId               = $clientId
    tenantId               = $tenantId
    certificateThumbprint  = $thumbprint
    certificatePfxPassword = $certificatePassword
    certificatePfxBase64   = [System.Convert]::ToBase64String( (Get-Content -Path $certificatePath -Encoding Byte) )
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
    $credentials = Invoke-AzResourceAction `
                        -ResourceGroupName $resourceGroupName `
                        -ResourceType      "Microsoft.Web/sites/config" `
                        -ResourceName      "$($deployment.Outputs.functionAppName.Value)/publishingcredentials" `
                        -Action            "list" `
                        -ApiVersion        "2015-08-01" `
                        -Force

    $base64AuthHeader = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes( ("{0}:{1}" -f $credentials.properties.publishingUserName, $credentials.properties.publishingPassword) ) )

    Invoke-RestMethod `
        -Uri         "https://$($deployment.Outputs.functionAppName.Value).scm.azurewebsites.net/api/zip/site/wwwroot/$deployment.Outputs.functionName.Value" `
        -Headers     @{ Authorization = "Basic $base64AuthHeader" } `
        -Method      PUT `
        -InFile      $templateZipPath `
        -ContentType "multipart/form-data"

}