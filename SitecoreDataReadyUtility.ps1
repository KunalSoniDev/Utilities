function Write-Log($message) {
    $timeStamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    Write-Host "$($timeStamp) $($message)"
}
function searchContentNode($nodeItems, $fieldsToSearch, $templateToSearch) {
    $results = @()
    foreach ($nodeItem in $nodeItems) {
        foreach ($field in $fieldsToSearch) {
            $field = $field.Trim();
            $items = $nodeItem.Axes.GetDescendants() | Initialize-Item | Where-Object { 
                $_.Fields[$field] -ne $null -and 
                ($templateToSearch.Count -eq 0 -or $templateToSearch.TemplateName -contains $_.TemplateName)
            } | Select-Object -Property Id,
            Name,
            ItemPath, 
            TemplateName, 
            @{Name = "Field Name"; Expression = { $field } },
            @{Name = "Field Value"; Expression = { 
                    if ($_.Fields[$field].Type -eq "DateTime") {
                        [DateTime]::ParseExact($_.Fields[$field].Value, "yyyyMMddTHHmmss'Z'", $null).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                    elseif ($_.Fields[$field].Type -eq "Checkbox") {
                        if ($_.Fields[$field].Value -eq "1") { "Checked" } else { "Unchecked" }
                    }
                    elseif ($_.Fields[$field].Type -eq "Radio") {
                        if ($_.Fields[$field].Value -ne $null) { "Selected" } else { "Not Selected" }
                    }
                    else {
                        $_.Fields[$field].Value
                    }
                } 
            },
            @{Name = "Updated Value"; Expression = { "" } }
            $results += $items
        }
    }
    return $results | Show-ListView
}
$props = @{
    Parameters       = @(
        @{ Name     = "ContentPathItem"; 
            Title   = "Content Item Path"; 
            Tooltip = "Select the content item path";
            Source  = "DataSource=/sitecore/content"; 
            editor  = "treelist";
            Tab     = "Search";
        },
        @{ Name       = "FieldToSearch"; 
            Title     = "Field to search"; 
            Tooltip   = "Enter the field Name to search";
            Mandatory = $true;
            Tab       = "Search";
        },
        @{ Name     = "ContentPathFilterTemplate"; 
            Title   = "Template Filter"; 
            Tooltip = "search the content based on example page template you have selected.";
            Source  = "DataSource=/sitecore/content"; 
            editor  = "treelist";
            Tab     = "Filters";
        }
    )
    Title            = "Bulk read utility"
    Description      = "This Utility will crawl through the content tree and search the data as per the configuration."
    Width            = 650
    Height           = 650
    ShowHints        = $true
    OkButtonName     = "Run"
    CancelButtonName = "Cancel"
}

$result = Read-Variable @props
if ($result -ne "ok") {
    Write-Log "Cancelled by user"
    Exit
}
$templateToSearch = $ContentPathFilterTemplate | Select-Object -Property TemplateName;
$FieldsToSearch = $FieldToSearch -split ',';

searchContentNode $ContentPathItem $FieldsToSearch $templateToSearch;
