##
# how to:
# create an app registration;
# create a service connection from the app registration; 
# grant the app registration Full permissions on the site collection level via AppInv.aspx;
##

function BundleAndPackage-Solution {
    if (Is-Pipeline) {
        Write-Host "`n##[command] installing npm packages..."
        npm i
    }
    Write-Host "`n##[command] bundling the solution..."
    gulp clean
    gulp bundle --p
    Write-Host "`n##[command] packaging the solution..."
    gulp package-solution --p
}

function DeployAndInstall-Solution {
    param ($siteUrl)
    Write-Host "`n##[command] deploying and installing..."
    $pkgPath = (Get-ChildItem -Path .\sharepoint\ -Recurse -Include *.sppkg).FullName
    
    if (!(Is-Pipeline)) {
        Connect-PnPOnline $siteUrl -UseWebLogin
    }
    else {
        Install-Module SharePointPnPPowerShellOnline -Scope CurrentUser -Force
        Connect-PnPOnline $siteUrl -ClientId $env:servicePrincipalId -ClientSecret $env:servicePrincipalKey
    }

    $app = Add-PnPApp -Path $pkgPath -Scope Site -Publish -Overwrite
    if (!$app.InstalledVersion) { 
        Install-PnPApp -Identity $app.Id -Scope Site 
    }
    elseif ($app.CanUpgrade) { 
        Update-PnPApp -Identity $app.Id -Scope Site 
    }
}

function Is-Pipeline {
	return ($env:servicePrincipalId.length -ne 0)
}


function Run-Deployment {
    param (
        [parameter(Mandatory=$true)]
        [ValidateSet("DEV", "TEST", "QA", "PROD")]
        [String[]] $envName
    )

    $config = Get-Content .\deployment\config.json | ConvertFrom-Json
    
    Set-Location .\application
    BundleAndPackage-Solution
    DeployAndInstall-Solution $config.$envName.siteUrl

    Write-Host "`n##[command] done"
}

# how to run:
# Run-Deployment DEV