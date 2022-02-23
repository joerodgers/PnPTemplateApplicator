#requires -modules "PnP.PowerShell"

[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials 
[System.Net.ServicePointManager]::SecurityProtocol   = [System.Net.SecurityProtocolType]::Tls12


$landingPowerAutomateOrLogicAppTriggerUrl     = ""
$perspectivePowerAutomateOrLogicAppTriggerUrl = ""


function Get-SiteTemplate
{
  
}

# connect to tenant admin

    Connect-PnPOnline `
        -Url        "https://$($env:O365_TENANT)-admin.sharepoint.com" `
        -ClientId   $env:O365_CLIENTID `
        -Thumbprint $env:O365_THUMBPRINT `
        -Tenant     $env:O365_TENANTID


# create "The Landing" site script

    $landingTriggerFlowSchema = '
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
             "template" : "Landing"
           }}
         }}
       ]
    }}
    '

    $content = $landingTriggerFlowSchema -f $landingPowerAutomateOrLogicAppTriggerUrl

    $landingSiteScriptId = Add-PnPSiteScript `
                                -Title       "" `
                                -Description "" `
                                -Content     $content



# create "The Perspective" site script

    $perspectiveTriggerFlowSchema = '
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
             "template" : "Perspective"
           }}
         }}
       ]
    }}
    '

    $content = $perspectiveTriggerFlowSchema -f $perspectivePowerAutomateOrLogicAppTriggerUrl

    $perspectiveSiteScriptId = Add-PnPSiteScript `
                                    -Title       "" `
                                    -Description "" `
                                    -Content     $content

# create the site design for "The Perspective"

    Add-PnPSiteDesign `
        -Title           "" `
        -Description     "" `
        -ThumbnailUrl    "" `
        -SiteScriptIds   $perspectiveSiteScriptId `
        -WebTemplate     "CommunicationSite" `
        -PreviewImageUrl "" `


# create the site design for "The Landing"

    Add-PnPSiteDesign `
        -Title           "" `
        -Description     "" `
        -ThumbnailUrl    "" `
        -SiteScriptIds   $landingSiteScriptId `
        -WebTemplate     "CommunicationSite" `
        -PreviewImageUrl "" `

