param([string]$Reports = 'artifacts/store/reports')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Disposable CI only.' }
New-Item -ItemType Directory -Force $Reports | Out-Null
$sdk = Get-ChildItem "${env:ProgramFiles(x86)}/Windows Kits/10/bin" -Directory | Where-Object {
    $_.Name -match '^10\.0\.\d+\.\d+$' -and (Test-Path (Join-Path $_.FullName 'x64/signtool.exe'))
} | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$signtool = Join-Path $sdk.FullName 'x64/signtool.exe'
$work = Join-Path $env:TEMP ('calico-msix-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $work | Out-Null
$cert = $null; $registered = $null
try {
    if (!(Get-AppxPackage -Name Microsoft.VCLibs.140.00.UWPDesktop)) {
        Invoke-WebRequest 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile (Join-Path $work 'VCLibs.appx')
        & $signtool verify /pa (Join-Path $work 'VCLibs.appx')
        if ($LASTEXITCODE -ne 0) { throw 'Invalid runtime signature.' }
        Add-AppxPackage -Path (Join-Path $work 'VCLibs.appx')
    }
    $package = @(Get-ChildItem 'artifacts/store/test' -Filter '*TEST-ONLY-x64.msix')
    if ($package.Count -ne 1) { throw 'Expected one test package.' }
    $info = Get-Content ($package[0].FullName + '.json') -Raw -Encoding utf8 | ConvertFrom-Json
    if ($info.name -cne 'CalicoSleuth.PackagingTest') { throw 'Test identity required.' }
    $original = (Get-FileHash $package[0].FullName).Hash
    $cert = New-SelfSignedCertificate -Type Custom -Subject 'CN=Calico Sleuth Packaging Test' -KeyUsage DigitalSignature `
        -CertStoreLocation 'Cert:\CurrentUser\My' -HashAlgorithm SHA256 -NotAfter (Get-Date).AddDays(1) `
        -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3','2.5.29.19={text}')
    Export-Certificate -Cert $cert -FilePath (Join-Path $work 'test.cer') | Out-Null
    Import-Certificate -FilePath (Join-Path $work 'test.cer') -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople' | Out-Null
    $copy = Join-Path $work 'test.msix'; Copy-Item $package[0].FullName $copy
    & $signtool sign /fd SHA256 /sha1 $cert.Thumbprint /s My $copy
    if ($LASTEXITCODE -ne 0) { throw 'Test signing failed.' }
    Add-AppxPackage -Path $copy
    $registered = Get-AppxPackage -Name $info.name
    if (!$registered -or $registered.Version -ne $info.version) { throw 'Package registration failed.' }
    # CI-only WebView2 policies; never included in the distributed package.
    foreach ($view in @([Microsoft.Win32.RegistryView]::Registry64,[Microsoft.Win32.RegistryView]::Registry32)) {
        $root = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$view)
        $arguments = $root.CreateSubKey('Software\Policies\Microsoft\Edge\WebView2\AdditionalBrowserArguments')
        $profile = $root.CreateSubKey('Software\Policies\Microsoft\Edge\WebView2\UserDataFolder')
        foreach ($id in @('myfind.exe','myfind','com.gokcol.myfind',(Join-Path $registered.InstallLocation 'myfind.exe'))) {
            $arguments.SetValue($id,'--remote-debugging-port=9222',[Microsoft.Win32.RegistryValueKind]::String)
            $profile.SetValue($id,(Join-Path $work 'webview'),[Microsoft.Win32.RegistryValueKind]::String)
        }
        $arguments.Dispose(); $profile.Dispose(); $root.Dispose()
    }
    & node scripts/windows-store-smoke.mjs "$env:RUNNER_TEMP/calico-smoke/node_modules/playwright/index.mjs" "$($registered.PackageFamilyName)!CalicoSleuth" $Reports
    if ($LASTEXITCODE -ne 0) { throw 'Native packaged-app checks failed.' }
    $appcert = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/App Certification Kit/appcert.exe'
    $wack = 'not-available-on-runner'
    if (Test-Path $appcert) {
        & $appcert reset | Out-Null
        $report = Join-Path ([IO.Path]::GetFullPath($Reports)) 'WACK.xml'
        $process = Start-Process $appcert -ArgumentList @('test','-apptype','windowsstoreapp','-appxpackagepath',"`"$copy`"",'-reportoutputpath',"`"$report`"") -PassThru
        if ($process.WaitForExit(180000)) { $wack = 'requires-report-review' }
        else { Stop-Process -Id $process.Id -Force; $wack = 'timeout-requires-review' }
    }
    Get-Process -Name myfind -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($registered.InstallLocation) } | Stop-Process -Force
    Remove-AppxPackage -Package $registered.PackageFullName
    $registered = $null
    if (Get-AppxPackage -Name $info.name) { throw 'Uninstall failed.' }
    if ((Get-FileHash $package[0].FullName).Hash -ne $original) { throw 'Unsigned test artifact changed.' }
    @{installation=$true;uninstall=$true;unsignedArtifactPreserved=$true;wack=$wack} | ConvertTo-Json | Set-Content (Join-Path $Reports 'MSIX-validation.json') -Encoding utf8
} finally {
    if ($registered) { Remove-AppxPackage -Package $registered.PackageFullName -ErrorAction SilentlyContinue }
    if ($cert) {
        Remove-Item "Cert:\LocalMachine\TrustedPeople\$($cert.Thumbprint)" -ErrorAction SilentlyContinue
        Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -DeleteKey -ErrorAction SilentlyContinue
    }
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
