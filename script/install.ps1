function Get-QQpath {
    try {
        $key = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\QQ"
        $uninstallString = $key.UninstallString
        return [System.IO.Path]::GetDirectoryName($uninstallString) + "\QQ.exe"
    }
    catch {
        throw "get QQ path error: $_"
    }
}
function Get-QQDownloadUrl {
    #请求https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsDownloadUrl.js获取返回文本 正则匹配 https://dldir1\.qq\.com/qqfile/qq/QQNT/Windows/QQ_[0-9]+\.[0-9]+\.[0-9]+_[0-9]{6}_64_[0-9]{2}\.exe
    try {
        $url = "https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsDownloadUrl.js"
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $regex = "https://dldir1\.qq\.com/qqfile/qq/QQNT/Windows/QQ_[0-9]+\.[0-9]+\.[0-9]+_[0-9]{6}_64_[0-9]{2}\.exe"
        $response.Content -match $regex
        return $matches[0]
    }
    catch {
        throw "get QQ download url error: $_"
    }
}
function Get-IsQQInstalled {
    try {
        Get-QQpath
        return $true
    }
    catch {
        return $false
    }
}
function Install-QQ {
    try {
        $QQInstallerUrl = Get-QQDownloadUrl
        $QQInstallerPath = "$env:TEMP\QQInstaller.exe"
        Invoke-WebRequest -Uri $QQInstallerUrl -OutFile $QQInstallerPath
        Start-Process -FilePath $QQInstallerPath -ArgumentList "/s" -Wait
        Remove-Item -Path $QQInstallerPath -Force
    }
    catch {
        return $false
    }
    return Get-IsQQInstalled
}
function Get-RemoteNapCatVersion {
    try {
        $url = "https://fastly.jsdelivr.net/gh/NapNeko/NapCatQQ@main/package.json"
        $response = Invoke-WebRequest -Uri $url -UseBasicP
        $json = $response.Content | ConvertFrom-Json
        return $json.version
    }
    catch {
        throw "get version error: $_"
    }
}

$isQQInstalled = Get-IsQQInstalled

# 用于检测是否安装QQ
if (!$isQQInstalled) {
    $result = [System.Windows.Forms.MessageBox]::Show("未检测到QQ, 是否安装?", "提示", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq "OK") {
        $QQInstallPath = $folderBrowserDialog.SelectedPath
        if ($QQInstallPath -eq "") {
            Write-Host "Install QQ canceled."
            exit
        }
        # 将安装目录写入 HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Tencent\QQNT 的Install键（string） 注册表
        $registryPath = "HKLM:\SOFTWARE\WOW6432Node\Tencent\QQNT"
        $registryKey = "Install"
        $registryValue = $QQInstallPath
        if (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }
        if (!(Test-Path "$registryPath\$registryKey")) {
            New-ItemProperty -Path $registryPath -Name $registryKey -Value $registryValue-PropertyType String -Force | Out-Null
        }
        Write-Host "Please Wait ..."
        $isInstalled = Install-QQ
        if (!$isInstalled) {
            Write-Host "Install QQ failed."
            exit
        }
        else {
            Write-Host "Install QQ canceled."
            exit
        }
    }
}
# 获取远程版本号
$remoteVersion = Get-RemoteNapCatVersion
if ($null -eq $remoteVersion) {
    Write-Host "Get remote version failed."
    exit
}
Write-Host "Remote Version: $remoteVersion"
#下载https://github.com/NapNeko/NapCatQQ/releases/download/v$remoteVersion/NapCat.win32.x64.zip 的zip
$url = "https://github.com/NapNeko/NapCatQQ/releases/download/v$remoteVersion/NapCat.win32.x64.zip"
try {
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    $zipFile = "$env:TEMP\NapCat.win32.x64.zip"
    $zipFile | Out-File -FilePath $zipFile -Encoding utf8
    # 解压zip到当前目录的./tmp文件夹
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipFile)
    foreach ($entry in $zip.Entries) {
        $entryPath = Join-Path -Path $PSScriptRoot -ChildPath $entry.FullName
        $directory =Split-Path -Path $entryPath -Parent
        if (!(Test-Path $directory)) {
            New-Item -Path $directory -ItemType Directory | Out-Null
        }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entryPath, $true)
    }
    $zip.Dispose()
    Remove-Item -Path $zipFile -Force
}catch{
    Write-Host "Download failed."
    exit
}
Write-Host "Install Success!"