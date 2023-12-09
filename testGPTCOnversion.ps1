$getFileSignature = @'
[DllImport("kernel32.dll", SetLastError = true)]
private static extern bool GetFileInformationByHandleEx(IntPtr hFile, FILE_INFO_BY_HANDLE_CLASS infoClass, out FILE_ID_BOTH_DIR_INFO dirInfo, uint dwBufferSize);
[StructLayout(LayoutKind.Sequential)]
public struct FILE_ID_BOTH_DIR_INFO {
    public ulong VolumeSerialNumber;
    public long FileId;
    public uint FileIndexHigh;
    public uint FileIndexLow;
    public uint VolumeSequenceNumber;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
    public char[] FileName;
}
public enum FILE_INFO_BY_HANDLE_CLASS : int {
    FileIdInfo = 18,
    FileIdExtdDirectoryInfo = 0x20,
    FileIdBothDirectoryInfo = 0x22
}
'@

$Win32 = Add-Type -MemberDefinition $getFileSignature -Name 'Win32' -Namespace 'pinvoke' -PassThru

# Define the FILE_ID_BOTH_DIR_INFO structure
Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    namespace pinvoke {
        [StructLayout(LayoutKind.Sequential)]
        public struct FILE_ID_BOTH_DIR_INFO {
            public ulong VolumeSerialNumber;
            public long FileId;
            public uint FileIndexHigh;
            public uint FileIndexLow;
            public uint VolumeSequenceNumber;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
            public char[] FileName;
        }

        public enum FILE_INFO_BY_HANDLE_CLASS : int {
            FileIdInfo = 18,
            FileIdExtdDirectoryInfo = 0x20,
            FileIdBothDirectoryInfo = 0x22
        }
    }
"@

# Define the GetDirectoryId function
function GetDirectoryId() {
    param (
        $handle
    )

    $fileStruct = New-Object pinvoke.FILE_ID_BOTH_DIR_INFO
    $result = $Win32::GetFileInformationByHandleEx($handle, [pinvoke.FILE_INFO_BY_HANDLE_CLASS]::FileIdBothDirectoryInfo, [ref]$fileStruct, [uint]::SizeOf($fileStruct))

    if (-not $result) {
        Write-Host "Failed to get file information. Error: $($Win32::GetLastError())"
        return $null
    }

    return $fileStruct.FileId
}

# Example usage
$createSignature = @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr CreateFileW(
      string filename,
      System.IO.FileAccess access,
      System.IO.FileShare share,
      IntPtr securityAttributes,
      System.IO.FileMode creationDisposition,
      uint flagsAndAttributes,
      IntPtr templateFile);
'@

$createFile = Add-Type -MemberDefinition $createSignature -Name 'CreateFile' -Namespace 'pinvoke' -PassThru

# example usage for read access to a directory
$handle = $createFile[0]::CreateFileW('\\?\C:\Users\tadghh\Pictures\1676909802687421.jpg', [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read, [System.IntPtr]::Zero, [System.IO.FileMode]::Open, [System.UInt32]0x02000000, [System.IntPtr]::Zero)

# Get directory ID
$directoryId = GetDirectoryId -handle $handle
Write-Host "Directory ID: $directoryId"
