
function IsNullOrEmpty ([Parameter(Mandatory = $true)][string] $s) {
    return [string]::IsNullOrEmpty($s)
}

function IsExistsFile ([Parameter(Mandatory = $true)]$s) {
    return [System.IO.File]::Exists($s)
}
function IsExistsDirectory ([Parameter(Mandatory = $true)]$s) {
    return [System.IO.Directory]::Exists($s)
}
function IsExists ([Parameter(Mandatory = $true)]$s) {
    return [System.IO.File]::Exists($s) -or [System.IO.Directory]::Exists($s)
}

function CopyFiles ([Parameter(Mandatory = $true)]$s, [Parameter(Mandatory = $true)]$d) {
    if ((IsExists $s) -and (IsExists $d)) {
        $ss = Get-Item $s
        $dd = Get-Item $d
        if ((($ss.Attributes -band 16) -eq 16) -and (($dd.Attributes -band 16) -eq 16) -and ($ss.Name -eq $dd.Name)) {
            Copy-Item ((Get-ChildItem $s -Force) | ForEach-Object {$_.FullName}) $d -Force
            return
        }
    }
    Copy-Item $s $d -Recurse -Force
}

function WarpArgument([string]$s, [switch]$ForchQuete) {
    if ($s -inotmatch "[\\`" \t\n\r]" -and !$ForchQuete.IsPresent) {
        return $s
    }
    $s2 = $s
    $s2 = ($s2 -replace "\\", "\\") -replace "`"", "\`""
    $s2 = "`"$s2`""
    # Write-Host "$s > $s2"
    return $s2
}

function RunAndWait([Parameter(Mandatory = $true)][string]$File, [string[]]$Arguments = @(), [string]$WorkingDirectory = (Get-Location)) {
    $rr = $null
    try {
        if ($Arguments.Count -gt 0) {
            $Arguments = $Arguments | ForEach-Object { WarpArgument($_)}
            $rr = Start-Process $File $Arguments -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru;
        }
        else {
            $rr = Start-Process $File -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru;
        }
    }
    catch {
        Write-Error ("Run `"$File`": " + $PSItem.Exception.Message)
        return -1
    }
    Wait-Process -InputObject $rr
    $rr = $rr.ExitCode
    return $rr;
}

function IfThenElse($v, $ifTrue, $isFalse) {
    if ($v) {
        return $ifTrue
    }
    return $isFalse
}

function FindInPath([Parameter(Mandatory = $true)][string] $Name) {
    return cmd /c "where $(WarpArgument($Name)) 2>nul"
}

function RemoveFiles([Parameter(Mandatory = $true)]$f, [bool]$log = $true, [int]$Milliseconds = 200) {
    if ($log) {
        Write-Host "remove files: $f" -ForegroundColor Green
    }
    $m = 10;
    while (IsExists($f) -and $m-- -gt 0) {
        try {
            Remove-Item -Path $f -Recurse -Force;
        }
        catch {

        }
        Start-Sleep -Milliseconds ms
    }
}

function RunAndWaitEx([Parameter(Mandatory = $true)][string]$FileName, [string[]]$Arguments = @(), [string]$WorkingDirectory = (Get-Location), [switch]$PassThru, [System.Text.Encoding]$Encoding = [System.Text.Encoding]::Default) {
    if ($PassThru.IsPresent) {
        return RunAndWait $FileName $Arguments $WorkingDirectory
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    $psi.Arguments = $Arguments
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    # $psi.RedirectStandardInput = $true
    $psi.StandardErrorEncoding = $Encoding
    $psi.StandardOutputEncoding = $Encoding
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = $WorkingDirectory
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    try {
        $process.Start() | Out-Null;
        $process.WaitForExit() | Out-Null;
    }
    catch {
        $ex = $_.Exception;
        if ($ex.InnerException) {
            $ex = $ex.InnerException
        }
        return @{
            StdOut   = $null
            StdError = "Run `"$FileName`" error: " + $ex.Message
            ExitCode = -1
        }
    }
    $out = $process.StandardOutput.ReadToEnd();
    $error = $process.StandardError.ReadToEnd();
    return @{
        StdOut   = $out
        StdError = $error
        ExitCode = $process.ExitCode
    }
}

function RunAsAdmin($Path, $Arguments = @(), $WorkingDirectory = (Get-Location), [switch] $Hide, [switch] $PassThru, [switch] $DEBUG) {
    $Path = WarpArgument $Path
    $WorkingDirectory = WarpArgument $WorkingDirectory
    $cmd = "Start-Process $Path -WorkingDirectory $WorkingDirectory -Verb runas -Wait "
    if ($Arguments.Count -gt 0) {
        $cmd += " -ArgumentList `$Arguments "
    }
    if ($Hide.IsPresent) {
        $cmd += " -WindowStyle Hidden "
    }
    if ($PassThru.IsPresent) {
        $cmd += " -PassThru "
    }
    if ($DEBUG.IsPresent) {
        Write-Output $cmd
        Write-Output $Arguments
    }
    return Invoke-Expression $cmd
    # Start-Process powershell.exe -Verb runas -ArgumentList "-NoExit","-Command","cd '$(Get-Location)'","-ExecutionPolicy","Unrestricted" -WorkingDirectory (Get-Location)        
}

Export-ModuleMember `
    -Function `
    RemoveFiles, FindInPath, IfThenElse, RunAndWait, WarpArgument, `
    CopyFiles, IsExists, IsExistsFile, IsExistsDirectory, IsNullOrEmpty, RunAndWaitEx, `
    RunAsAdmin
    