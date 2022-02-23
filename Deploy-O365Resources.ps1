#requires -modules "PnP.PowerShell"

[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials 
[System.Net.ServicePointManager]::SecurityProtocol   = [System.Net.SecurityProtocolType]::Tls12

$clientId   = $env:O365_CLIENTID
$thumbprint = $env:O365_THUMBPRINT
$tenantId   = $env:O365_TENANTID
$tenant     = $env:O365_TENANT

# you will see this as output in the Deploy-AzureResources.ps1 script or pull directly from the Logic App's trigger action.
$powerAutomateOrLogicAppTriggerUrl = "https://prod-56.eastus.logic.azure.com:443/workflows/e761dc8bd8314b0492584547119c60bf/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=olk-9EBHy4sx_a10VFfUhZhhVPSE2oTcPijOLc4mp_w"

# manually upload these files and update the paths below
$landingThumbnailImageUrl     = "https://$tenant.sharepoint.com/SiteAssets/thumbnail-thelanding.jpg"
$landingPreviewImageUrl       = "https://$tenant.sharepoint.com/SiteAssets/card-thelanding.jpg"

$perspectiveThumbnailImageUrl = "https://$tenant.sharepoint.com/SiteAssets/thumbnail-theperspective.jpg"
$perspectivePreviewImageUrl   = "https://$tenant.sharepoint.com/SiteAssets/card-theperspective.jpg"


# connect to tenant admin

    Connect-PnPOnline `
        -Url        "https://$tenant-admin.sharepoint.com" `
        -ClientId   $clientId `
        -Thumbprint $thumbprint `
        -Tenant     $tenantId


# create site script 

    $template = '
    {{
    "$schema" : "schema.json",
    "actions" : [
        {{
        "verb" : "triggerFlow",
        "url"  : "{0}",
        "name" : "Apply Site Template",
        "parameters" : {{
            "event"    : "site creation",
            "product"  : "SharePoint Online",
            "template" : "{1}"
        }}
        }}
    ]
    }}
    '

    if( -not ($landingSiteScript = Get-PnPSiteScript | Where-Object -Property "Title" -eq "Landing Template Applicator") )
    {
        Write-Host "Provisioning Site Script: Landing"

        $schema = $template -f $powerAutomateOrLogicAppTriggerUrl, "Landing"

        $landingSiteScript = Add-PnPSiteScript `
                                    -Title       "Landing Template Applicator" `
                                    -Description "Applies 'The Landing' template to a SharePoint Online Communications site." `
                                    -Content     $schema
    }


    if( -not ($perspectiveSiteScript = Get-PnPSiteScript | Where-Object -Property "Title" -eq "Perspective Template Applicator") )
    {
        Write-Host "Provisioning Site Script: Perspective"

        $schema = $template -f $powerAutomateOrLogicAppTriggerUrl, "Perspective"

        $perspectiveSiteScript = Add-PnPSiteScript `
                                    -Title       "Perspective Template Applicator" `
                                    -Description "Applies 'The Perspective' template to a SharePoint Online Communications site." `
                                    -Content     $schema
    }


# create the site designs

if( -not (Get-PnPSiteDesign | Where-Object -Property "Title" -eq "The Landing - News, resources, personalized content" ) )
{
    Write-Host "Provisioning Site Design: Landing"

    Add-PnPSiteDesign `
        -Title           "The Landing - News, resources, personalized content" `
        -Description     "This communication site is designed to be the place where your employees can find the news and resources they need, plus personalized content tailored just for them." `
        -ThumbnailUrl    $landingThumbnailImageUrl `
        -SiteScriptIds   $landingSiteScript.Id `
        -PreviewImageUrl $landingPreviewImageUrl `
        -WebTemplate     "CommunicationSite"
}

if( -not (Get-PnPSiteDesign | Where-Object -Property "Title" -eq "The Perspective - News, video, personalized content" ) )
{
    Write-Host "Provisioning Site Design: Perspective"

    Add-PnPSiteDesign `
        -Title           "The Perspective - News, video, personalized content" `
        -Description     "Designed to offer news and personalized content, this site also includes videos to inspire even more engagement." `
        -ThumbnailUrl    $perspectiveThumbnailImageUrl `
        -SiteScriptIds   $perspectiveSiteScript.Id `
        -PreviewImageUrl $perspectivePreviewImageUrl `
        -WebTemplate     "CommunicationSite"
}

<# 

# Remove Solution Commands

    Get-PnPSiteDesign | Where-Object -Property "Title" -eq "The Perspective - News, video, personalized content" | Remove-PnPSiteDesign -Force
    Get-PnPSiteDesign | Where-Object -Property "Title" -eq "The Landing - News, resources, personalized content" | Remove-PnPSiteDesign -Force

    Get-PnPSiteScript | Where-Object -Property "Title" -eq "Landing Template Applicator"     | Remove-PnPSiteScript -Force
    Get-PnPSiteScript | Where-Object -Property "Title" -eq "Perspective Template Applicator" | Remove-PnPSiteScript -Force

#>
