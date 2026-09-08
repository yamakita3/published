# ============================================================
# GeoTIFF -> RGB PNG (+ world file) batch converter
# Automatically stretches each band to 0-255 (like QGIS "Stretch to MinMax")
# ============================================================
# --- Stretch settings ---------------------------------------------------
# Use a fixed min/max for all files instead of auto-detecting per file
$UseFixedRange = $false
$FixedMin = 0
$FixedMax = 3000

# Multiply the max value (fixed or auto-detected) by this factor
# to pull in bright outliers like clouds/glint. 1.0 = no change, 0.7 = 70%
$MaxScaleFactor = 0.2
# -------------
try {

$InputDir = $PSScriptRoot
$Recurse = $false
$OutputDir = Join-Path $InputDir "PNG_out"
$LogFile = Join-Path $InputDir "log.txt"
"===== Start: $(Get-Date) =====" | Out-File -FilePath $LogFile -Encoding UTF8

function Find-QgisProcess {
    $candidates = @(
        "C:\Users\$env:USERNAME\AppData\Local\Programs\OSGeo4W\bin\qgis_process-qgis.bat",
        "C:\OSGeo4W64\bin\qgis_process-qgis.bat",
        "C:\OSGeo4W\bin\qgis_process-qgis.bat"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }

    $programFilesDirs = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}") | Where-Object { $_ -and (Test-Path $_) }
    foreach ($pf in $programFilesDirs) {
        $qgisDirs = Get-ChildItem -Path $pf -Directory -Filter "QGIS*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        foreach ($dir in $qgisDirs) {
            $binPath = Join-Path $dir.FullName "bin"
            if (Test-Path $binPath) {
                $found = Get-ChildItem -Path $binPath -Filter "qgis_process*.bat" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) { return $found.FullName }
            }
        }
    }

    $searchRoots = @("C:\OSGeo4W*", "C:\Program Files*") | ForEach-Object { Resolve-Path $_ -ErrorAction SilentlyContinue }
    foreach ($root in $searchRoots) {
        $found = Get-ChildItem -Path $root -Recurse -Filter "qgis_process*.bat" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

$QgisProcess = Find-QgisProcess
if (-not $QgisProcess -or -not (Test-Path $QgisProcess)) {
    Write-Host "qgis_process not found automatically. Set `$QgisProcess manually." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$BinDir = Split-Path $QgisProcess -Parent
$GdalInfo = Join-Path $BinDir "gdalinfo.exe"
$UseStretch = Test-Path $GdalInfo

Write-Host "Using qgis_process: $QgisProcess"
Write-Host "Input folder: $InputDir"
if ($UseStretch) {
    Write-Host "gdalinfo found: $GdalInfo (auto min-max stretch enabled)"
} else {
    Write-Host "gdalinfo NOT found near qgis_process. Falling back to no stretch (DATA_TYPE unchanged)." -ForegroundColor Yellow
}

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

$tifFiles = @()
$tifFiles += Get-ChildItem -Path $InputDir -Filter "*.tif"  -File -Recurse:$Recurse
$tifFiles += Get-ChildItem -Path $InputDir -Filter "*.tiff" -File -Recurse:$Recurse

if ($tifFiles.Count -eq 0) {
    Write-Host "No .tif / .tiff files found in: $InputDir" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 0
}

function Get-BandMinMax {
    param([string]$GdalInfoPath, [string]$FilePath)
    $out = & $GdalInfoPath -stats $FilePath 2>&1
    $text = $out -join "`n"
    $matches = [regex]::Matches($text, "Minimum=([\-0-9.eE]+),\s*Maximum=([\-0-9.eE]+)")
    $ranges = @()
    foreach ($m in $matches) {
        $ranges += [PSCustomObject]@{ Min = [double]$m.Groups[1].Value; Max = [double]$m.Groups[2].Value }
    }
    return $ranges
}

Write-Host "Files to process: $($tifFiles.Count)"
$successCount = 0
$failCount = 0

foreach ($file in $tifFiles) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $outputPng = Join-Path $OutputDir ($baseName + ".png")

    Write-Host "----------------------------------------------------------"
    Write-Host "Converting: $($file.FullName)"

    $extra = "-co WORLDFILE=YES"
    $dataType = 0

    if ($UseFixedRange) {
        $ranges = @(
            [PSCustomObject]@{ Min = $FixedMin; Max = $FixedMax },
            [PSCustomObject]@{ Min = $FixedMin; Max = $FixedMax },
            [PSCustomObject]@{ Min = $FixedMin; Max = $FixedMax }
        )
    } elseif ($UseStretch) {
        $ranges = Get-BandMinMax -GdalInfoPath $GdalInfo -FilePath $file.FullName
    } else {
        $ranges = @()
    }

    if ($ranges.Count -ge 3) {
        $max1 = $ranges[0].Max * $MaxScaleFactor
        $max2 = $ranges[1].Max * $MaxScaleFactor
        $max3 = $ranges[2].Max * $MaxScaleFactor
        $extra = "-co WORLDFILE=YES -scale_1 $($ranges[0].Min) $max1 0 255 -scale_2 $($ranges[1].Min) $max2 0 255 -scale_3 $($ranges[2].Min) $max3 0 255"
        $dataType = 1
        Write-Host "  Band ranges (x$MaxScaleFactor): R[$($ranges[0].Min), $max1] G[$($ranges[1].Min), $max2] B[$($ranges[2].Min), $max3]"
    } else {
        Write-Host "  Could not read 3-band stats, using no stretch." -ForegroundColor Yellow
    }

    $arguments = @(
        "run", "gdal:translate",
        "--INPUT=$($file.FullName)",
        "--COPY_SUBDATASETS=false",
        "--EXTRA=$extra",
        "--DATA_TYPE=$dataType",
        "--OUTPUT=$outputPng"
    )

    $result = & $QgisProcess @arguments 2>&1
    $result | Out-File -FilePath $LogFile -Append -Encoding UTF8

    if ($LASTEXITCODE -eq 0 -and (Test-Path $outputPng)) {
        $successCount++
        Write-Host "  Done" -ForegroundColor Green
    } else {
        $failCount++
        Write-Host "  Failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
    }
}

Write-Host "============================================================"
Write-Host "Finished: $successCount succeeded / $failCount failed"
Write-Host "Output folder: $OutputDir"

} catch {
    Write-Host "An unexpected error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace
}

Read-Host "Finished. Press Enter to close"
