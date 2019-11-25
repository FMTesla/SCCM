<#
.SYNOPSIS
    Deploy applications to collections, based on Administrative Categories
.DESCRIPTION
    This script deploys applications to specified collections based on the attached Administrative Categories.
    It will then loop through those collections and remove any deployments for apps that no longer bear the
    category queried.

    Originally designed to automatically deploy applications as available to a Helpdesk user collection, and
    Available/Required (for Fast Channel installs) to a Machine Collection
.INPUTS
    "$deployments" = Edit table with relevant collections, admin categories, and deployment settings
    "$newAppArgs" = Additional settings/defaults for application deployments
    $newAppArgs["DistributionPointGroupName"] = Set your distribution group name
.NOTES
    Name:      Deploy-AppByCategory.ps1
    Author:    Vex
    Contributor: Chris Kibble (On a _massive_ level, thanks Chris!!!)
    Version: 1.0.0
    Release Date: 2019-08-13
#>

# Site configuration
$SiteCode = "CNT" # Site code 
$ProviderMachineName = "cm.contoso.com" # SMS Provider machine name

# Customizations
$initParams = @{ }
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if ((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if ((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

# Set the required deployment args per collection
$deployments = @{
    "HelpDesk Deployments"             = @{
        "Category"         = "Helpdesk"
        "Collections"      = @("IT - Helpdesk")
        "ApprovalRequired" = $false
        "DeployAction"     = "Install"
        "DeployPurpose"    = "Available"
        "UserNotification" = "DisplayAll"
    }
    "Fast Channel Deployments" = @{
        "Category"         = "Fast Channel App"
        "Collections"      = @("Deploy - Fast Channel Deployment")
        "ApprovalRequired" = $true       
        "DeployAction"     = "Install"
        "DeployPurpose"    = "Available"
        "UserNotification" = "DisplaySoftwareCenterOnly"
    }
}

# Grab all of the applications in SCCM that are not Expired (Retired)
$apps = Get-CMApplication -Fast | Where-Object { ($_.IsExpired -eq $false) } | Select-Object LocalizedDisplayName, LocalizedCategoryInstanceNames, CI_UniqueID

# Get the distribution status of all apps
$dists = Get-CMDistributionStatus

# Loop through the $deployemnts
ForEach ($deployment in $deployments.Keys) {

    # Pull a list of applications with that category
    $appList = $apps.Where( { $_.LocalizedCategoryInstanceNames -contains $deployments[$deployment].Category })

    # Loop over each application that should be deployed and ensure it is
    ForEach ($app in $appList) {
        
        $objectId = $(Split-Path $app.CI_UniqueID) -Replace '\\', '/'
        $distCount = ($dists | Where-Object { $_.ObjectID -eq $objectId }).NumberSuccess

        # Loop through the collections, if there are multiples
        ForEach ($collection in $deployments[$deployment].Collections) {
            
            $newAppArgs = @{
                "Name"             = $app.LocalizedDisplayName
                "DeployAction"     = $deployments[$deployment].DeployAction
                "DeployPurpose"    = $deployments[$deployment].DeployPurpose
                "ApprovalRequired" = $deployments[$deployment].ApprovalRequired
                "UserNotification" = $deployments[$deployment].UserNotification
                "TimeBaseOn"       = "LocalTime"
                "CollectionName"   = $collection
                "WhatIf"           = $true
                "Verbose"          = $true
            }
            
            # If the application has not been distributed, append the distribution parameters to the arg list
            If ($distCount -eq 0) {
                $newAppArgs["DistributeContent"] = $true
                $newAppArgs["DistributionPointGroupName"] = "Contoso Distribution Group"
            }

            If (Get-CMDeployment -SoftwareName $app.LocalizedDisplayName -CollectionName $collection) {
                # Already deployed; do nothing
            }
            Else {
                # Deploy application to the collection
                New-CMApplicationDeployment @newAppArgs

            }

        }
    }

    # Loop over each collection and ensure that there are no deployments that shouldn't be here
    ForEach ($collection in $collections) {
        
        # Grab the deployments on the current looped collection
        $deployedApps = Get-CMDeployment -CollectionName $collection | Select-Object ApplicationName
        # Find apps that aren't in our AppList for this collection
        $badDeployments = $deployedApps.Where( { $_.ApplicationName -notin $appList.LocalizedDisplayName })
        # Loop over apps and remove
        ForEach ($badDeployment in $badDeployments) {
            Remove-CMDeployment -ApplicationName $badDeployment.ApplicationName -CollectionName $collection -Force
        }
    }


}