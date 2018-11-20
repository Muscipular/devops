
function warpArgument([string]$s) {
    if ($s -inotmatch "[\\`" \t\n\r]") {
        return $s
    }
    $s2 = $s
    $s2 = ($s2 -replace "\\", "\\") -replace "`"", "\`""
    $s2 = "`"$s2`""
    return $s2
}

function ExecEx([string]$FileName, [string[]]$Arguments = @(), [string]$WorkingDirectory = (Get-Location), [switch]$PassThru, [System.Text.Encoding]$Encoding = [System.Text.Encoding]::Default) {
    if ($PassThru.IsPresent) {
        $arg = $arg | ForEach-Object { warpArgument($_)}
        $rr = Start-Process $file $arg -WorkingDirectory $cwd -NoNewWindow -PassThru;
        Wait-Process -InputObject $rr
        return $rr.ExitCode
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

    $p = $process.Start();
    $p = $process.WaitForExit();
    $out = $process.StandardOutput.ReadToEnd();
    $error = $process.StandardError.ReadToEnd();
    return @{
        StdOut   = $out
        StdError = $error
        ExitCode = $process.ExitCode
    }
}

function GitSvnPropGet {
    param (
        [String] $Prop = "",
        [System.Text.Encoding] $Encoding = [System.Text.Encoding]::UTF8
    )
    $r = ExecEx git @('svn', 'propget', $Prop) -Encoding $Encoding
    if (!([System.String]::IsNullOrEmpty($r.StdError))) {
        return ""
    }
    return $r.StdOut
}

# function GitSvnDCommit(
#     [Parameter(Mandatory = $false)][string] $name, 
#     [Parameter(Mandatory = $false)][string[]] $MergeInfo,
#     [switch]$OverrideMergeInfo) {
#     $info = ((GitSvnPropGet svn:mergeinfo) -split "`n") | where {$_}
#     return $info
# }

Export-ModuleMember -Function GitSvnPropGet
