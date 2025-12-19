# Fetch Hytale CurseForge Versions
# This script fetches the latest Hytale versions from CurseForge
# and generates the Go code to add to versions.go

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiToken
)

$headers = @{
    "X-Api-Token" = $ApiToken
    "Accept" = "application/json"
}

Write-Host "Fetching Hytale versions from CurseForge..." -ForegroundColor Cyan

try {
    $versions = Invoke-RestMethod -Uri "https://hytale.curseforge.com/api/game/versions" -Headers $headers -Method Get
    
    Write-Host "`nFound $($versions.Count) version(s):" -ForegroundColor Green
    Write-Host ""
    
    # Display versions in a table
    $versions | Format-Table @{
        Label = "Version Name"
        Expression = { $_.name }
    }, @{
        Label = "Version ID"
        Expression = { $_.id }
    }, @{
        Label = "Type ID"
        Expression = { $_.gameVersionTypeID }
    }, @{
        Label = "Slug"
        Expression = { $_.slug }
    } -AutoSize
    
    # Generate Go code
    Write-Host "`n=== Go Code for versions.go ===" -ForegroundColor Yellow
    Write-Host "var hytaleVersionToID = map[string]int{" -ForegroundColor White
    
    $versions | Sort-Object name | ForEach-Object {
        $paddingLength = [Math]::Max(0, 20 - $_.name.Length)
        $padding = " " * $paddingLength
        Write-Host "`t`"$($_.name)`":$padding$($_.id), // Slug: $($_.slug)" -ForegroundColor White
    }
    
    Write-Host "}" -ForegroundColor White
    
    # Generate JSON mapping
    Write-Host "`n=== JSON Mapping ===" -ForegroundColor Yellow
    $mapping = @{
        versionTypeId = $versions[0].gameVersionTypeID
        versions = @()
    }
    
    $versions | ForEach-Object {
        $mapping.versions += @{
            name = $_.name
            id = $_.id
            slug = $_.slug
        }
    }
    
    $mapping | ConvertTo-Json -Depth 10 | Out-File "hytale-versions-export.json" -Encoding UTF8
    Write-Host "Saved to hytale-versions-export.json" -ForegroundColor Green
    
    # Generate configuration examples
    Write-Host "`n=== Example Configurations ===" -ForegroundColor Yellow
    
    Write-Host "`nFor use in deployment.json:" -ForegroundColor Cyan
    Write-Host @"
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "hytale",
    "gameVersions": ["$($versions[0].name)"],
    "releaseType": "release"
  }
}
"@ -ForegroundColor White
    
    if ($versions.Count -gt 1) {
        Write-Host "`nFor multiple versions:" -ForegroundColor Cyan
        $versionList = ($versions | Select-Object -First 3 | ForEach-Object { "`"$($_.name)`"" }) -join ", "
        Write-Host @"
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "hytale",
    "gameVersions": [$versionList],
    "releaseType": "release"
  }
}
"@ -ForegroundColor White
    }
    
    # Show version type info
    Write-Host "`n=== Version Type Information ===" -ForegroundColor Yellow
    Write-Host "Version Type ID: $($versions[0].gameVersionTypeID)" -ForegroundColor White
    Write-Host "This should match HytaleVersionType constant in versions.go" -ForegroundColor Gray
    
} catch {
    Write-Host "`nError fetching versions:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "Status Code: $statusCode" -ForegroundColor Red
        
        if ($statusCode -eq 403) {
            Write-Host "`nPossible issues:" -ForegroundColor Yellow
            Write-Host "1. API token is invalid or expired" -ForegroundColor Yellow
            Write-Host "2. Regenerate at: https://www.curseforge.com/account/api-tokens" -ForegroundColor Yellow
        }
    }
    exit 1
}

Write-Host "`n=== Instructions ===" -ForegroundColor Cyan
Write-Host "1. Copy the 'Go Code' section above into your versions.go file" -ForegroundColor White
Write-Host "2. Replace the existing hytaleVersionToID map" -ForegroundColor White
Write-Host "3. Update your deployment.json with the version names you need" -ForegroundColor White
Write-Host "4. Test your deployment!" -ForegroundColor White