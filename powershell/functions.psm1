
function isNullString ($s) {
    return [string]::IsNullOrEmpty($s)
}

function isExists ($s) {
    return [System.IO.File]::Exists($s) -or [System.IO.Directory]::Exists($s)
}

function copyFiles ($s, $d) {
    Write-Host "Copy $s -> $d" -ForegroundColor Green
    if ((isExists $s) -and (isExists $d)) {
        $ss = Get-Item $s
        $dd = Get-Item $d
        if ((($ss.Attributes -band 16) -eq 16) -and (($dd.Attributes -band 16) -eq 16) -and ($ss.Name -eq $dd.Name)) {
            Copy-Item ((Get-ChildItem $s -Force) | ForEach-Object {$_.FullName}) $d -Force
            return
        }
    }
    Copy-Item $s $d -Recurse -Force
}

function warpArgument([string]$s) {
    if ($s -inotmatch "[\\`" \t\n\r]") {
        return $s
    }
    $s2 = $s
    $s2 = ($s2 -replace "\\", "\\") -replace "`"", "\`""
    $s2 = "`"$s2`""
    # Write-Host "$s > $s2"
    return $s2
}

function exec([string]$file, [string[]]$arg = @(), [string]$cwd = (Get-Location)) {
    $arg = $arg | ForEach-Object { warpArgument($_)}
    Write-Host "Execute $file $($arg -join ' ')" -ForegroundColor Green
    Start-Sleep 1
    $rr = Start-Process $file $arg -WorkingDirectory $cwd -NoNewWindow -PassThru;
    Wait-Process -InputObject $rr
    $rr = $rr.ExitCode
    Start-Sleep 1
    return $rr;
}

function installNodeModules($path) {
    if (!(isExists "$path\node_modules")) {
        Write-Host "@$path npm install" -ForegroundColor Green
        $r = exec "npm" @("install") $path
        # $r = exec "cmd" @("/S", "/C", "npm", "install") $path
        if ($r -ne 0) {
            throw "npm install failed. code: $r"
        }
    }
}

function installRequireJs ($path) {
    if (!(isExists("$path\node_modules\require-css"))) {
        if (isExists("$path\..\Build\Project\node_modules")) {
            Write-Host "@$path copy modules" -ForegroundColor Green
            copyFiles "$path\..\Build\Project\node_modules" "$path\node_modules"
        }
        else {
            Write-Host "@$path npm install require-css csso" -ForegroundColor Green
            $r = exec "npm" @("install", "require-css", "csso") $path
            # $r = exec "cmd" @("/S", "/C", "npm", "install", "require-css", "csso") $path
            if ($r -ne 0) {
                throw "npm install failed. code: $r"
            }
        }
    }
}

function ifThenElse($v, $ifTrue, $isFalse) {
    if ($v) {
        return $ifTrue
    }
    return $isFalse
}

function findMsBuild () {
    if ((!(isNullString($env:MSBuild))) -and (isExists($env:MSBuild))) {
        return $env:MSBuild;
    }
    $msbuild = cmd /c where MSBuild.exe
    if (!(isNullString($msbuild))) {
        return $msbuild;
    }
    $arch = ifThenElse($env:PROCESSOR_ARCHITECTURE -eq "AMD64",""," (x86)");
    foreach ($Disk in (Get-Partition | Where-Object { $_.DriveLetter -match "\w+" }| ForEach-Object {$_.DriveLetter})) {
        foreach ($p in @(
            "$($Disk):\Program Files${$arch}\Microsoft Visual Studio\2017\Enterprise\MSBuild\15.0\bin\MSBuild.exe",
            "$($Disk):\Program Files${$arch}\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\bin\MSBuild.exe",
            "$($Disk):\Program Files${$arch}\Microsoft Visual Studio\2017\Community\MSBuild\15.0\bin\MSBuild.exe",
            "$($Disk):\Program Files${$arch}\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\bin\MSBuild.exe"
            )) {
            if (isExists($p)) {
                return $p;
            }
        }
    }
    throw "MSBuild.exe not found."
}

function CallMsBuild($cwd, $project, $targets, $property) {
    $MSBuild = findMsBuild;
    Write-Host "start buiid $project" -ForegroundColor Green
    Write-Host
    $pc = $env:NUMBER_OF_PROCESSORS / 2;
    if ($pc -lt 1) {
        $pc = 1
    }
    $args_ = @($project, "/nologo", "/v:m", "/m:$pc", "/nr:false") + ($targets | ForEach-Object {"/t:" + $_}) + ($property.GetEnumerator() | ForEach-Object { "/p:" + $_.Key + '=' + $_.Value });
    # Write-Host $args_
    $r = exec $MSBuild $args_ $cwd;
    # Write-Host $r.ExitCode
    if ($r -ne 0 ) {
        throw "build error, exit code: $r"
    }
    Write-Host
    Write-Host "MSBuild success." -ForegroundColor Green
    Write-Host
    return $r;
}

function removeFiles($f, [bool]$log = $true, [int]$wait = 1) {
    if ($log) {
        Write-Host "remove files: $f" -ForegroundColor Green
    }
    $m = 10;
    while (isExists($f) -and $m-- -gt 0) {
        try {
            Remove-Item -Path $f -Recurse -Force;
        }
        catch {

        }
        Start-Sleep $wait
    }
}

function RemovePdbAndXml ($path) {
    foreach ($item in Get-ChildItem $path -Directory) {
        RemovePdbAndXml $item.FullName
    }
    foreach ($item in Get-ChildItem $path -File -Filter "*.dll") {
        $f = $item.FullName -ireplace "\.dll$", ".pdb"
        if (isExists($f)) {
            removeFiles $f $false 0
        }
        $f = $item.FullName -ireplace "\.dll$", ".xml"
        if (isExists($f)) {
            removeFiles $f $false 0
        }
    }
    foreach ($item in Get-ChildItem $path -File -Filter "*.exe") {
        $f = $item.FullName -ireplace "\.exe$", ".pdb"
        if (isExists($f)) {
            removeFiles $f $false 0
        }
        $f = $item.FullName -ireplace "\.exe$", ".xml"
        if (isExists($f)) {
            removeFiles $f $false 0
        }
    }
}

function npmRun([string]$target, $cwd = (Get-Location)) {
    installNodeModules $cwd
    $r = exec "cmd" @("/S", "/C", "npm", "run", "build") $cwd
    if ($r -ne 0) {
        throw "run npm run $target error: $r"
    }
}

function Build($CWD, $ProjectDir, $Project, $Domain, $Configuration, $Type, $Dist, $VisualStudioVersion, $DotNetVersion, $KeepPdbAndXml, $Callbacks) {
    $OutPath = (Join-Path $CWD "Dist\$Configuration\$Domain")
    if (!(isNullString($Dist))) {
        $OutPath = "$Dist\$Configuration\$Domain"
    }
    $ObjPath = "obj/$Configuration/$Domain/"
    # Write-Host $CWD, $OutPath
    $code = 0;
    removeFiles("$CWD\$ProjectDir\$ObjPath")
    removeFiles("$OutPath")
    if ($Callbacks["OnPrepare"]) {
        Invoke-Command $Callbacks["OnPrepare"] -ArgumentList @("$CWD\$ProjectDir", $OutPath)
    }
    switch ($Type) {
        "Web" {
            $code = CallMsBuild -cwd $CWD -project "$CWD\$ProjectDir\$Project" -targets @("restore", "Build", "ResolveReferences;Compile", "_CopyWebApplication", "TransformWebConfig") -property @{
                VisualStudioVersion        = $VisualStudioVersion
                TargetFrameworkVersion     = $DotNetVersion
                WebProjectOutputDir        = $OutPath
                OutputPath                 = "$OutPath\bin"
                Configuration              = $Configuration
                BaseIntermediateOutputPath = $ObjPath
                WarningLevel               = 0
            }

            copyFiles "$CWD\$ProjectDir\$ObjPath\$Configuration\TransformWebConfig\transformed\web.config" "$OutPath\web.config"
        }
        "Exe" {
            $code = CallMsBuild -cwd $CWD -project "$CWD\$ProjectDir\$Project" -targets @("restore", "Build", "ResolveReferences;Compile") -property @{
                VisualStudioVersion        = $VisualStudioVersion
                TargetFrameworkVersion     = $DotNetVersion
                # WebProjectOutputDir        = $OutPath
                OutputPath                 = $OutPath
                Configuration              = $Configuration
                BaseIntermediateOutputPath = $ObjPath
                WarningLevel               = 0
            }
        }
        Default {
            throw "not match type"
        }
    }

    switch ($code) {
        0 {
            if ($KeepPdbAndXml -eq $false) {
                Write-Host "Remove pdb and xml" -ForegroundColor Green
                RemovePdbAndXml($OutPath)
            }
            if ($Callbacks["OnSuccess"]) {
                Invoke-Command $Callbacks["OnSuccess"] -ArgumentList @("$CWD\$ProjectDir", $OutPath)
            }
        }
        Default {
            if ($Callbacks["OnFailed"]) {
                Invoke-Command $Callbacks["OnFailed"] -ArgumentList @("$CWD\$ProjectDir", $OutPath)
            }
        }
    }

    return $code;
}
