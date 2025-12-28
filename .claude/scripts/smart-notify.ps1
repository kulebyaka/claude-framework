param(
    [Parameter(Mandatory=$true)]
    [string]$Message,

    [Parameter(Mandatory=$true)]
    [int]$IdleThreshold,

    [Parameter(Mandatory=$false)]
    [string]$Topic = ""
)

# Load Windows API for idle detection
$signature = @"
using System;
using System.Runtime.InteropServices;

public class UserInput {
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
}
"@

try {
    Add-Type -TypeDefinition $signature -ErrorAction SilentlyContinue
} catch {}

# Get idle time using the struct
$lastInputInfo = New-Object UserInput+LASTINPUTINFO
$lastInputInfo.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$lastInputInfo.GetType())
[UserInput]::GetLastInputInfo([ref]$lastInputInfo) | Out-Null

$idleMs = [Environment]::TickCount - $lastInputInfo.dwTime
$idleSeconds = $idleMs / 1000

# Skip if user is active (idle less than threshold)
if ($idleSeconds -lt $IdleThreshold) {
    exit 0
}

# Send ntfy.sh notification (only if topic is configured)
if ($Topic -ne "") {
    try {
        Invoke-WebRequest -Uri "https://ntfy.sh/$Topic" -Method Post -Body $Message -UseBasicParsing | Out-Null
    } catch {
        # Fallback to curl.exe if available
        & curl.exe -s -d $Message "ntfy.sh/$Topic" 2>$null
    }
}

# Show Windows toast notification with sound
try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    $toastXml = @"
<toast duration="short">
    <visual>
        <binding template="ToastText02">
            <text id="1">Claude Code</text>
            <text id="2">$Message</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($toastXml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Claude Code").Show($toast)
} catch {
    # Fallback: use BurntToast module if available, otherwise just play a sound
    try {
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast
            New-BurntToastNotification -Text "Claude Code", $Message -Sound Default
        } else {
            # Simple fallback: just play the notification sound
            [System.Media.SystemSounds]::Exclamation.Play()
        }
    } catch {
        [System.Media.SystemSounds]::Exclamation.Play()
    }
}
