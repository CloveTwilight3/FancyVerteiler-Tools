# Fetch Minecraft CurseForge Versions
# This script fetches the latest Minecraft versions from CurseForge
# and generates the Go code to add to versions.go

param(
    [Parameter(Mandatory=$true)]
    [string]$ApiToken,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("plugin", "mod")]
    [string]$Type = "plugin"
)

$headers = @{
    "X-Api-Token" = $ApiToken
    "Accept" = "application/json"
}

Write-Host "Fetching Minecraft $Type versions from CurseForge..." -ForegroundColor Cyan

try {
    $allVersions = Invoke-RestMethod -Uri "https://minecraft.curseforge.com/api/game/versions" -Headers $headers -Method Get
    
    # Filter by type
    if ($Type -eq "plugin") {
        $versions = $allVersions | Where-Object { $_.gameVersionTypeID -eq 1 }
        $mapName = "pluginVersionToID"
        $typeDesc = "Bukkit/Plugin"
    } else {
        # For mods, get versions from multiple type IDs
        $versions = $allVersions | Where-Object { 
            $_.gameVersionTypeID -eq 73407 -or 
            $_.gameVersionTypeID -eq 75125 -or 
            $_.gameVersionTypeID -eq 77784 
        }
        $mapName = "modVersionToID"
        $typeDesc = "Mod Loader"
    }
    
    Write-Host "`nFound $($versions.Count) $Type versions" -ForegroundColor Green
    Write-Host ""
    
    # Display recent versions in a table (last 20)
    Write-Host "Recent Versions (last 20):" -ForegroundColor Cyan
    $versions | Select-Object -Last 20 | Format-Table @{
        Label = "Version"
        Expression = { $_.name }
        Width = 12
    }, @{
        Label = "ID"
        Expression = { $_.id }
        Width = 8
    }, @{
        Label = "Type ID"
        Expression = { $_.gameVersionTypeID }
        Width = 8
    }, @{
        Label = "Slug"
        Expression = { $_.slug }
    } -AutoSize
    
    # Generate Go code
    Write-Host "`n=== Go Code for versions.go ===" -ForegroundColor Yellow
    Write-Host "var $mapName = map[string]int{" -ForegroundColor White
    
    # Group and display last 30 versions
    $recentVersions = $versions | Select-Object -Last 30 | Sort-Object name
    $lastMajor = ""
    
    foreach ($ver in $recentVersions) {
        # Add comment for major version changes
        if ($ver.name -match '^(\d+\.\d+)$') {
            $major = $ver.name
            if ($major -ne $lastMajor) {
                Write-Host "" -ForegroundColor White
                Write-Host "`t// $major.x versions" -ForegroundColor Gray
                $lastMajor = $major
            }
        } elseif ($ver.name -match '^(\d+\.\d+)\.\d+$') {
            $major = $Matches[1]
            if ($major -ne $lastMajor) {
                Write-Host "" -ForegroundColor White
                Write-Host "`t// $major.x versions" -ForegroundColor Gray
                $lastMajor = $major
            }
        }
        
        $paddingLength = [Math]::Max(0, 20 - $ver.name.Length)
        $padding = " " * $paddingLength
        $comment = "// gameVersionTypeID: $($ver.gameVersionTypeID), slug: $($ver.slug)"
        Write-Host "`t`"$($ver.name)`":$padding$($ver.id), $comment" -ForegroundColor White
    }
    
    Write-Host "}" -ForegroundColor White
    
    # Generate JSON mapping
    Write-Host "`n=== JSON Export ===" -ForegroundColor Yellow
    
    $exportData = $versions | Select-Object name, id, gameVersionTypeID, slug
    $outputFile = "minecraft-$Type-versions-export.json"
    
    # Show first few entries
    $exportData | Select-Object -First 20 | ConvertTo-Json | Write-Host
    Write-Host "..." -ForegroundColor Gray
    
    # Save all to file
    $exportData | ConvertTo-Json -Depth 10 | Out-File $outputFile -Encoding UTF8
    Write-Host "`nFull data saved to $outputFile" -ForegroundColor Green
    
    # Generate configuration examples
    Write-Host "`n=== Example Configurations ===" -ForegroundColor Yellow
    
    $latestVersion = ($versions | Select-Object -Last 1).name
    
    Write-Host "`nFor latest version ($latestVersion):" -ForegroundColor Cyan
    
    if ($Type -eq "plugin") {
        Write-Host @"
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "plugin",
    "gameVersions": ["$latestVersion"],
    "releaseType": "release"
  }
}
"@ -ForegroundColor White
    } else {
        Write-Host @"
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "mod",
    "loader": "fabric",  // or "forge", "neoforge", "quilt"
    "gameVersions": ["$latestVersion"],
    "releaseType": "release"
  }
}
"@ -ForegroundColor White
    }
    
    # Show multiple version example
    Write-Host "`nFor multiple versions:" -ForegroundColor Cyan
    $versionList = ($versions | Select-Object -Last 3 | ForEach-Object { "`"$($_.name)`"" }) -join ", "
    
    if ($Type -eq "plugin") {
        Write-Host @"
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "plugin",
    "gameVersions": [$versionList],
    "releaseType": "release"
  }
}
"@ -ForegroundColor White
    } else {
        Write-Host @"
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "mod",
    "loader": "fabric",
    "gameVersions": [$versionList],
    "releaseType": "release"
  }
}
"@ -ForegroundColor White
    }
    
    # Show version type info
    Write-Host "`n=== Version Type Information ===" -ForegroundColor Yellow
    
    if ($Type -eq "plugin") {
        Write-Host "Version Type ID: 1 (PluginVersionType)" -ForegroundColor White
        Write-Host "All Bukkit/Spigot/Paper plugin versions use gameVersionTypeID = 1" -ForegroundColor Gray
    } else {
        Write-Host "Version Type IDs for Mods:" -ForegroundColor White
        Write-Host "  - 1.19.x: 73407 (ModVersionType_119)" -ForegroundColor White
        Write-Host "  - 1.20.x: 75125 (ModVersionType_120)" -ForegroundColor White
        Write-Host "  - 1.21.x: 77784 (ModVersionType_121)" -ForegroundColor White
        Write-Host "Mod versions are split by Minecraft version family" -ForegroundColor Gray
    }
    
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
if ($Type -eq "plugin") {
    Write-Host "2. Replace or update the pluginVersionToID map" -ForegroundColor White
} else {
    Write-Host "2. Replace or update the modVersionToID map" -ForegroundColor White
}
Write-Host "3. Update your deployment.json with the version names you need" -ForegroundColor White
Write-Host "4. Test your deployment!" -ForegroundColor White

Write-Host "`nTip: Use -Type mod to get mod versions, or -Type plugin for plugin versions" -ForegroundColor Gray