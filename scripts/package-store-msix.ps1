[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Executable,
    [switch]$TestIdentity,
    [string]$OutputDirectory = 'artifacts/store/packages'
)
$App = 'Tapp-Find'
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
$product = (Get-Content (Join-Path $repo 'packaging/windows/msix/product.json') -Raw -Encoding utf8 | ConvertFrom-Json)
if (!$product) { throw 'Missing assigned Partner Center product identity.' }
$name = $product.identityName; $publisher = $product.publisher; $display = $product.displayName
$publisherDisplay = $product.publisherDisplayName; $version = $product.packageVersion
if ($TestIdentity) {
    $name = "CalicoSleuth.PackagingTest"; $publisher = 'CN=Tapp Find Packaging Test'
    $display = "$App Packaging Test"; $publisherDisplay = 'Tapp Find packaging tests'
} elseif ("$name $publisher $display" -match '(?i)placeholder|packaging[ .-]?test|replace[_ -]?me') { throw 'Test identities cannot be submitted to the Store.' }
if ($name -notmatch '^[A-Za-z0-9.-]{3,50}$' -or !$publisher.StartsWith('CN=')) { throw 'Invalid package identity.' }
$null = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new($publisher)
if ($version -notmatch '^[1-9][0-9]*\.[0-9]+\.[0-9]+\.0$' -or @($version.Split('.') | Where-Object { [decimal]$_ -gt 65535 }).Count) { throw 'Invalid Store package version.' }
$exe = (Resolve-Path $Executable).Path
$reader = [System.IO.BinaryReader]::new([System.IO.File]::OpenRead($exe))
try {
    if ($reader.ReadUInt16() -ne 0x5a4d) { throw 'Not a PE executable.' }
    $reader.BaseStream.Position = 0x3c; $offset = $reader.ReadUInt32(); $reader.BaseStream.Position = $offset
    if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x8664) { throw 'An x64 executable is required.' }
} finally { $reader.Dispose() }
if ((Get-Item $exe).VersionInfo.ProductVersion -notlike '0.1.3*') { throw 'Expected released application version 0.1.3.' }
$sdk = Get-ChildItem "${env:ProgramFiles(x86)}/Windows Kits/10/bin" -Directory | Where-Object {
    $_.Name -match '^10\.0\.\d+\.\d+$' -and (Test-Path (Join-Path $_.FullName 'x64/makeappx.exe'))
} | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (!$sdk) { throw 'Windows SDK is required.' }
$makeappx = Join-Path $sdk.FullName 'x64/makeappx.exe'; $makepri = Join-Path $sdk.FullName 'x64/makepri.exe'
$out = [System.IO.Path]::GetFullPath($OutputDirectory); New-Item -ItemType Directory -Force $out | Out-Null
$flavor = if ($TestIdentity) { 'TEST-ONLY' } else { 'store' }
$package = Join-Path $out "$App-$version-$flavor-x64.msix"
if (Test-Path $package) { throw 'Refusing to overwrite an existing package.' }
$work = Join-Path $out ('.work-' + [guid]::NewGuid().ToString('N')); $layout = Join-Path $work 'layout'
New-Item -ItemType Directory -Force (Join-Path $layout 'Assets') | Out-Null
try {
    Copy-Item $exe (Join-Path $layout 'myfind.exe')
    Copy-Item (Join-Path $repo 'LICENSE'),(Join-Path $repo 'PRIVACY.md') $layout
    $source = 'src-tauri/icons'
    foreach ($asset in @('StoreLogo.png','Square150x150Logo.png','Square44x44Logo.png')) { Copy-Item (Join-Path $repo "$source/$asset") (Join-Path $layout "Assets/$asset") }
    [xml]$manifest = Get-Content (Join-Path $repo 'packaging/windows/msix/AppxManifest.xml') -Raw
    $manifest.Package.Identity.SetAttribute('Name',$name); $manifest.Package.Identity.SetAttribute('Publisher',$publisher)
    $manifest.Package.Identity.SetAttribute('Version',$version)
    $manifest.Package.Properties.DisplayName = $display; $manifest.Package.Properties.PublisherDisplayName = $publisherDisplay
    $description = 'Find files by name and metadata. Content search is planned.'
    $manifest.Package.Properties.Description = $description
    $vcRuntime = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($exe)) -match '(?i)(vcruntime140|msvcp140)(?:_[0-9]+)?\.dll'
    if ($vcRuntime) {
        $dependency = $manifest.CreateElement('PackageDependency',$manifest.DocumentElement.NamespaceURI)
        $dependency.SetAttribute('Name','Microsoft.VCLibs.140.00.UWPDesktop')
        $dependency.SetAttribute('MinVersion','14.0.30704.0')
        $dependency.SetAttribute('Publisher','CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US')
        $manifest.Package.Dependencies.AppendChild($dependency) | Out-Null
    }
    $application = $manifest.Package.Applications.Application
    $appId = 'CalicoSleuth'
    $application.SetAttribute('Id',$appId); $application.SetAttribute('Executable','myfind.exe')
    $visual = $manifest.GetElementsByTagName('VisualElements','http://schemas.microsoft.com/appx/manifest/uap/windows10')[0]
    $visual.SetAttribute('DisplayName',$display); $visual.SetAttribute('Description',$description)
    $manifest.Save((Join-Path $layout 'AppxManifest.xml'))
    & $makepri createconfig /cf (Join-Path $work 'priconfig.xml') /dq en-US /o
    if ($LASTEXITCODE -ne 0) { throw 'MakePri configuration failed.' }
    & $makepri new /pr $layout /cf (Join-Path $work 'priconfig.xml') /of (Join-Path $layout 'resources.pri') /o
    if ($LASTEXITCODE -ne 0) { throw 'Resource indexing failed.' }
    & $makeappx pack /d $layout /p $package /h SHA256 /o
    if ($LASTEXITCODE -ne 0) { throw 'Package semantic validation failed.' }
    $unpacked = Join-Path $work 'unpacked'; & $makeappx unpack /p $package /d $unpacked /o
    if ($LASTEXITCODE -ne 0) { throw 'Package round trip failed.' }
    if ((Get-FileHash $exe).Hash -ne (Get-FileHash (Join-Path $unpacked 'myfind.exe')).Hash) { throw 'Packaged executable changed.' }
    [xml]$roundTrip = Get-Content (Join-Path $unpacked 'AppxManifest.xml') -Raw
    if ($roundTrip.Package.Identity.Name -cne $name -or $roundTrip.Package.Identity.Publisher -cne $publisher -or $roundTrip.Package.Identity.Version -ne $version) { throw 'Identity mismatch.' }
    $caps = @($roundTrip.SelectNodes("//*[local-name()='Capability']"))
    if ($caps.Count -ne 1 -or $caps[0].GetAttribute('Name') -cne 'runFullTrust') { throw 'Unexpected capability.' }
    if ($roundTrip.SelectNodes("//*[local-name()='FileSystemWriteVirtualization' or local-name()='RegistryWriteVirtualization']").Count) { throw 'Virtualization must retain Windows defaults.' }
    if (Test-Path (Join-Path $unpacked 'AppxSignature.p7x')) { throw 'Store upload must remain unsigned.' }
    $hash = (Get-FileHash $package -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $([IO.Path]::GetFileName($package))" | Set-Content "$package.sha256" -Encoding ascii
    [ordered]@{ app=$App; applicationId=$appId; identityMode=$flavor; name=$name; publisher=$publisher; displayName=$display
        publisherDisplayName=$publisherDisplay; version=$version; appVersion='0.1.3'; architecture='x64'; minimumWindowsVersion='10.0.22000.0'
        sourceReference='v0.1.3'; packagingCommit=(& git rev-parse HEAD); binarySha256=(Get-FileHash $exe -Algorithm SHA256).Hash.ToLowerInvariant()
        sha256=$hash; signed=$false; webviewRuntime='Windows 11 system Evergreen WebView2'; vcRuntimeFramework=$vcRuntime; sdk=$sdk.Name
    } | ConvertTo-Json | Set-Content "$package.json" -Encoding utf8
    Write-Host "Verified unsigned $flavor package: $package"
} catch {
    Remove-Item $package,"$package.sha256","$package.json" -Force -ErrorAction SilentlyContinue
    throw
} finally { Remove-Item $work -Recurse -Force }
