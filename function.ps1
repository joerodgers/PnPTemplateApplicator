param
(
    $QueueItem, 
    $TriggerMetadata 
)

if( $QueueItem -is [string] )
{
    $QueueItem = $QueueItem | ConvertFrom-Json -Depth 100
}

Import-Module -Name "PnP.PowerShell"

<#

    $QueueItem - Parameter is a HashTable sent from the the JSON message dropped in the Azure Storage Queue

        $QueueItem.SiteCollectionUrl = "https://tenant.sharepoint.com/sites/sitename"
        $QueueItem.Template          = "Perspective"
        $QueueItem.Force             = true/false (optional parameter to force application of a template to a site again)

    $TriggerMetadata - Parameter is used to supply additional information about the trigger. See https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell?tabs=portal#triggermetadata-parameter
    
#>

# credentials

    $clientId   = $env:SPO_CLIENTID
    $thumbprint = $env:SPO_THUMBPRINT
    $tenantId   = $env:SPO_TENANTID

# define paths to template resources

    $templates = @{
        "Perspective" = Join-Path -Path $PSScriptRoot -ChildPath "perspective\template.xml"
        "Landing"     = Join-Path -Path $PSScriptRoot -ChildPath "landing\template.xml"
    }

# parameter validation

    if( [string]::IsNullOrWhitespace($QueueItem.SiteCollectionUrl) )
    {
        throw "SiteCollectionUrl parameter was null or empty."
    }

    if( [string]::IsNullOrWhitespace($QueueItem.Template) )
    {
        throw "Template parameter was null or empty."
    }

    if( -not $templates.ContainsKey($QueueItem.Template) )
    {
        throw "Template parameter was invalid."
    }

    if( -not (Test-Path -Path $templates[$QueueItem.Template]) )
    {
        throw "Template not found: $($templates[$QueueItem.Template])"
    }

    if( -not (Get-Module -Name "PnP.PowerShell") )
    {
        throw "PnP.PowerShell module not found, update the requirements.psd1 to include this module."
    }

    $siteCollectionUrl = $QueueItem.SiteCollectionUrl
    $templateName      = $QueueItem.Template
    $templatePath      = $templates[$templateName]
    $force             = $QueueItem.ContainsKey("Force") -and ( $QueueItem.Force -eq $true -or $QueueItem.Force -eq "True" )


# connection

    Write-Host "Connecting to: $siteCollectionUrl"

    $siteConnection = Connect-PnPOnline `
                                -Url        $siteCollectionUrl `
                                -ClientId   $clientId `
                                -Thumbprint $thumbprint `
                                -Tenant     $tenantId `
                                -ReturnConnection

    if( -not $siteConnection -or -not $? )
    {
        throw "Failed to connect to tenant site: $siteCollectionUrl"
    }

# target site validation

    $web = Get-PnPweb -Includes WebTemplate, SiteLogoUrl

    # ensure we only apply to a communications site
    if( $web.WebTemplate -ne "SITEPAGEPUBLISHING")
    {
        Write-Error "Invalid target site web template: $webTemplate"
        return
    }

    # don't apply the template again if the template's logo is already applied to the site
    [Xml]$templateXml = Get-Content -Path $templatePath

    # read the logo file name from the template
    $logo = $templateXml.Provisioning.Templates.ProvisioningTemplate.WebSettings.SiteLogo -Split "/" | Select-Object -Last 1

    # if the site's logo file name is is the same as the logo image name from the selected template, assume the template is already applied and don't apply again
    if( -not $force -and -not [string]::IsNullOrWhitespace($logo) -and $web.SiteLogoUrl -match "$logo$" )
    {
        Write-Warning "$templateName template is already applied to $siteCollectionUrl"
        return
    }

# apply template

    try
    {
        Write-Host "Applying the $templateName template to $siteCollectionUrl"

        Invoke-PnPSiteTemplate -Path $templatePath -Connection $siteConnection -ErrorAction Stop

        Write-Host "Template application complete"
    }
    catch
    {
        throw "Failed to apply template. Exception: $($_)"
    }

# close

    Disconnect-PnPOnline