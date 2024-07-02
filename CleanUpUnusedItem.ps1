function Write-Log($message) {
    $timeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Write-Host "$($timeStamp) $($message)"
}
function File-Log($message) {
    $timeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    return "$($timeStamp) $($message)"
}
$ProcessLogs = @()
$RemovableItemLogs = @()


$ProcessLogs += File-Log "script intialization...!"

$scanningNode = Get-Item -Path "master:/sitecore/media library"; 
$ProcessLogs += File-Log "scanningNode $($scanningNode.ItemPath)"

$excludeNode = "master:/sitecore/media library/Activity";
$ProcessLogs += File-Log "excludeNode $($excludeNode)"

$Target = "web"
$ProcessLogs += File-Log "Target $($Target)"

$Languages = "en"
$ProcessLogs += File-Log "Languages $($Languages)"

$Downloadableitems = @()
$location = get-location
$time = Get-Date -format "yyyy-MM-d_hhmmss"
$zipName = "MediaCleanupActivity"
New-Item -Path "$($SitecoreDataFolder)" -Name "PS_MediaCleanUp" -ItemType "directory"
$zipPath = "$($SitecoreDataFolder)\PS_MediaCleanUp\$zipName-$time.zip"
$ProcessLogs += File-Log "zipPath $($zipPath)"
$ProcessLogPath = "$($SitecoreDataFolder)\PS_MediaCleanUp\SP_ProcessLog-$time.txt"
$RemovableItemLogsPath = "$($SitecoreDataFolder)\PS_MediaCleanUp\SP_RemovableItemLogs-$time.txt"




$NodeRecurse = $scanningNode | Get-ChildItem -Path master:

function Search-MediaRefferWithExclusion ($scanningItem, $excludeItems, $Target, $Languages) {
    foreach ($excludedItem in $excludeItems) {
        $exclueNode = Get-Item -Path $excludedItem;
        
        if (($exclueNode.ID -eq $scanningItem.ID) -or ($scanningItem.ItemPath.StartsWith($exclueNode.ItemPath))) {
            $script:ProcessLogs += File-Log "Skipping branch as it's in exclude list $($exclueNode.ItemPath)."
            return;
        }
    }
    if ($scanningItem.TemplateName -eq "Image") {
        $itemLinks = Get-ItemReferrer -Item $scanningItem | Select-Object -Property Name
        $itemcount = (@() + $itemLinks).Count 
        if ( $itemcount -eq 0 ) {
            $script:Downloadableitems += $scanningItem  
            #for validation perse commenting this line and working with logs to be validate. once we done with validation i'll uncomment below to do heard delete from CM
            # $scanningItem | Remove-Item
            $script:ProcessLogs += File-Log "Delete image $($scanningItem.ItemPath)."
            $script:RemovableItemLogs += File-Log "Delete  image $($scanningItem.ItemPath)."
        }
        else {
            $script:ProcessLogs += File-Log "Skip image $($scanningItem.ItemPath) as it having $($itemcount) references."
        }
        
    }
    $NodeRecurse = $scanningItem | Get-ChildItem -Path master:
    foreach ($nodeItem in $NodeRecurse) {
        $script:ProcessLogs += File-Log "Node Item in recursion :- $($nodeItem.ItemPath)"
        Search-MediaRefferWithExclusion -scanningItem $nodeItem -excludeItems $excludeItems -Target $Target -Languages $Languages
    }
}

function prepare-ZipItems( $zipArchive, $sourcedir ) {
    Set-Location $sourcedir
    [System.Reflection.Assembly]::Load("WindowsBase,Version=3.0.0.0, `
      Culture=neutral, PublicKeyToken=31bf3856ad364e35") > $null
    $ZipPackage = [System.IO.Packaging.ZipPackage]::Open($zipArchive, `
            [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite)
      
    [byte[]]$buff = new-object byte[] 40960
    $i = 0;
    ForEach ($item In $Downloadableitems) {
        $i++
        if ([Sitecore.Resources.Media.MediaManager]::HasMediaContent($item)) {
            $mediaItem = New-Object "Sitecore.Data.Items.MediaItem" $item;
            $mediaStream = $mediaItem.GetMediaStream();
            $fileName = Resolve-Path -Path $item.ProviderPath -Relative
            $fileName = "$fileName.$($item.Extension)".Replace("\", "/").Replace("./", "/");
            "Added: $fileName"
            Write-Progress -Activity "Zipping Files " -CurrentOperation "Adding $fileName" -Status "$i out of $($Downloadableitems.Length)" -PercentComplete ($i * 100 / $Downloadableitems.Length)
            $partUri = New-Object System.Uri($fileName, [System.UriKind]::Relative)
            $partUri = [System.IO.Packaging.PackUriHelper]::CreatePartUri($partUri);
            $part = $ZipPackage.CreatePart($partUri, "application/zip", [System.IO.Packaging.CompressionOption]::Maximum)
            $stream = $part.GetStream();
            do {
                $count = $mediaStream.Read($buff, 0, $buff.Length)
                $stream.Write($buff, 0, $count)
            } while ($count -gt 0)
            $stream.Close()
            $mediaStream.Close()
        }
    }
    $ZipPackage.Close()
}


$ProcessLogs += File-Log "Node Recursion started"
foreach ($nodeItem in $NodeRecurse) {
    $ProcessLogs += File-Log "Node Item :- $($nodeItem.ItemPath)"
    Search-MediaRefferWithExclusion -scanningItem $nodeItem -excludeItems $excludeNode -Target $Target -Languages $Languages
}
$ProcessLogs += File-Log "Start Zip Creation...!"
prepare-ZipItems $zipPath $location
$ProcessLogs += File-Log "Start downloading Zip...!"
#Download-File -FullName $zipPath > $null
$ProcessLogs += File-Log "Remove Zip file...!"
# Remove-Item $zipPath
$ProcessLogs | Out-file -FilePath $ProcessLogPath
$RemovableItemLogs | Out-file -FilePath $RemovableItemLogsPath
# $ProcessLogs | Out-String | Out-Download -Name $ProcessLogPath 

Close-Window