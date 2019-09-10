
function GetDrives() {
    return [System.IO.DriveInfo]::GetDrives() | where DriveType -EQ 3 | % {($_.Name +"_")[0] } | where { $_ -MATCH "[A-Z]"}
}

function VSWhere {
    try {
        return (& "$(${Env:ProgramFiles(x86)})\Microsoft Visual Studio\Installer\vswhere.exe" -products "*" -requires Microsoft.Component.MSBuild -property installationPath)
    }
    catch {
        return ""
    }
}

function FindMsBuild () {
    $_msbuild = Get-Variable -Name "MSBuild" -ErrorAction Ignore -Scope Global -ValueOnly
    if ((!(IsNullOrEmpty($_msbuild))) -and (IsExists($_msbuild))) {
        return $_msbuild;
    }
    if ((!(IsNullOrEmpty($env:MSBuild))) -and (IsExists($env:MSBuild))) {
        return $env:MSBuild;
    }
    $_msbuild = cmd /c where MSBuild.exe 2>$null
    if (!(IsNullOrEmpty($_msbuild))) {
        return $_msbuild;
    }
    $vs = VSWhere
    if ((!(IsNullOrEmpty($vs))) -and (IsExists("$vs\MSBuild\15.0\bin\MSBuild.exe"))) {
        return "$vs\MSBuild\15.0\bin\MSBuild.exe";
    }
    $arch = ifThenElse ($env:PROCESSOR_ARCHITECTURE -ne "AMD64") "" " (x86)";
    foreach ($Disk in (getDrives)) {
        foreach ($d in @('Enterprise', 'Professional', 'Community', 'BuildTools')) {
            foreach ($p in @(
                    "$($Disk):\Program Files$($arch)\Microsoft Visual Studio\2017\$($d)\MSBuild\15.0\bin\MSBuild.exe"
                )) {
                if (isExists($p)) {
                    return $p;
                }
            }
        }
    }
    throw "MSBuild.exe not found."
}

function CleanProject(
    [string] $Path = (Get-Location),
    [switch] $Obj, [switch] $Bin) {
        Get-ChildItem -Path $Path -Directory -Exclude @(".*","packages") | ForEach-Object {dir $_.Name -Directory | where {$_.Name -in (\"bin\",\"obj\")}| ForEach-Object {Remove-Item $_.FullName -Force -Recurse} } 
}