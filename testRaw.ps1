# Module PSFileId.psd1
<#
.SYNOPSIS
     PowerShell module that uses Windows API GetFileInformationByHandleEx
     function to get a file ou folder filesystem id. Useful to asset files
     and folders and detect name changes, for example.
.SINTAXE
     Get-ItemId <System.IO.FileSystemInfo>
.DESCRIPTION
     Compile the Windows API and exposes by a PowerShell function called Get-ItemId.
.USAGE
     Install module using Install-Module -Name PSFileId
     Call Get-ItemId function
     Example: Get-ItemId $(Get-Item "C:\Test")
.NOTES
     Author: Samuel Diniz Casimiro - samuel.casimiro@camara.leg.br
     Based in the PSBasicInfo module written by Vasily Larionov available at
     https://www.powershellgallery.com/packages/PSBasicInfo/1.0.3
.SEEALSO
     Get-Item
     Add-Type
.LINK
     https://git.camara.gov.br/coaus-satus/scripts-powershell-sepac
#>
$script:memberDefinition = @'
    public enum FileInformationClass : int
    {
        FileBasicInfo = 0,
        FileStandardInfo = 1,
        FileNameInfo = 2,
        FileRenameInfo = 3,
        FileDispositionInfo = 4,
        FileAllocationInfo = 5,
        FileEndOfFileInfo = 6,
        FileStreamInfo = 7,
        FileCompressionInfo = 8,
        FileAttributeTagInfo = 9,
        FileIdBothDirectoryInfo = 10, // 0xA
        FileIdBothDirectoryRestartInfo = 11, // 0xB
        FileIoPriorityHintInfo = 12, // 0xC
        FileRemoteProtocolInfo = 13, // 0xD
        FileFullDirectoryInfo = 14, // 0xE
        FileFullDirectoryRestartInfo = 15, // 0xF
        FileStorageInfo = 16, // 0x10
        FileAlignmentInfo = 17, // 0x11
        FileIdInfo = 18, // 0x12
        FileIdExtdDirectoryInfo = 19, // 0x13
        FileIdExtdDirectoryRestartInfo = 20, // 0x14
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct FILE_DISPOSITION_INFO
    {
        public bool DeleteFile;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct FILE_END_OF_FILE_INFO
    {
        public Int64 EndOfFile;
    }
    [StructLayout(LayoutKind.Explicit)]
    public struct FileInformation
    {
        [FieldOffset(0)]
        public FILE_BASIC_INFO FILE_BASIC_INFO;
        [FieldOffset(0)]
        public FILE_DISPOSITION_INFO FILE_DISPOSITION_INFO;
        [FieldOffset(0)]
        public FILE_END_OF_FILE_INFO FILE_END_OF_FILE_INFO;
    }

    [DllImport("Kernel32.dll", SetLastError = true)]
    public static extern bool SetFileInformationByHandle(IntPtr hFile, FILE_BASIC_INFO fileTwo, Int64 time);

    [StructLayout(LayoutKind.Explicit)]
    public struct LargeInteger {
        [FieldOffset(0)]
            public int Low;
        [FieldOffset(4)]
            public int High;
        [FieldOffset(0)]
        public long QuadPart;

            // use only when QuadPart canot be passed
            public long ToInt64()
            {
                        return ((long)this.High << 32) | (uint)this.Low;
            }

        // just for demonstration
        public static LargeInteger FromInt64(long value)
        {
        return new LargeInteger
        {
            Low = (int)(value),
            High = (int)((value >> 32))
        };
        }
    }

    public struct FILE_ID_BOTH_DIR_INFO {
        public uint NextEntryOffset;
        public uint FileIndex;
        public Int64 CreationTime;
        public Int64 LastAccessTime;
        public Int64 LastWriteTime;
        public Int64 ChangeTime;
        public Int64 EndOfFile;
        public Int64 AllocationSize;
        public uint FileAttributes;
        public uint FileNameLength;
        public uint EaSize;
        public char ShortNameLength;
        [MarshalAsAttribute(UnmanagedType.ByValTStr, SizeConst = 12)]
        public string ShortName;
        public Int64 FileId;
        [MarshalAsAttribute(UnmanagedType.ByValTStr, SizeConst = 1)]
        public string FileName;
    }
    public struct FILE_BASIC_INFO
    {
        [MarshalAs(UnmanagedType.I8)]
        public Int64 CreationTime;
        [MarshalAs(UnmanagedType.I8)]
        public Int64 LastAccessTime;
        [MarshalAs(UnmanagedType.I8)]
        public Int64 LastWriteTime;
        [MarshalAs(UnmanagedType.I8)]
        public Int64 ChangeTime;
        [MarshalAs(UnmanagedType.U4)]
        public UInt32 FileAttributes;
    }
    [DllImport("kernel32.dll",CharSet = CharSet.Auto, SetLastError = true)]
    public static extern bool WriteFile(IntPtr hFile, byte [] lpBuffer,
       uint nNumberOfBytesToWrite);


    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr CreateFile(
        [MarshalAs(UnmanagedType.LPTStr)] string filename,
        [MarshalAs(UnmanagedType.U4)] UInt32 access,
        [MarshalAs(UnmanagedType.U4)] UInt32 share,
        IntPtr securityAttributes, // optional SECURITY_ATTRIBUTES struct or IntPtr.Zero
        [MarshalAs(UnmanagedType.U4)] UInt32 creationDisposition,
        [MarshalAs(UnmanagedType.U4)] UInt32 flagsAndAttributes,
        IntPtr templateFile);


    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetFileInformationByHandleEx(
        IntPtr hFile,
        int infoClass,
        out FILE_BASIC_INFO fileInfo,
        uint dwBufferSize);

'@

function Get-ItemId {
    [CmdletBinding()]
    param(
        # Path to file or directory
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({ Test-Path -Path $_.FullName })]
        [System.IO.FileSystemInfo]
        $Path
    )

    begin {
        #Pull in the method definition made above
        Add-Type -MemberDefinition $script:memberDefinition -Name File -Namespace Kernel32
    }

    process {
        $currentPath = $Path.FullName

        try {
            Write-Verbose "CreateFile: Open file $currentPath"
            #Gets a handle to the file, without sharing access
            $fileHandle = [Kernel32.File]::CreateFile($currentPath,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None,
                [System.IntPtr]::Zero,
                [System.IO.FileMode]::Open,
                [System.UInt32]0x02000000,
                [System.IntPtr]::Zero)

            if ($fileHandle -eq -1) {
                throw "CreateFile: Error opening file $Path"
            }

            # Output object
            $fileBasicInfo = New-Object -TypeName Kernel32.File+FILE_BASIC_INFO


            #Write-Verbose "GetFileInformationByHandleEx: Get basic info"
            $bRetrieved = [Kernel32.File]::GetFileInformationByHandleEx($fileHandle, 0,
                [ref]$fileBasicInfo,
                [System.Runtime.InteropServices.Marshal]::SizeOf($fileBasicInfo))

            # Print out the object
            Write-Host ($fileBasicInfo | Format-Table | Out-String)

            if (!$bRetrieved) {
                throw "GetFileInformationByHandleEx: Error retrieving item information"
            }


            # Convert BasicFileInfo to a byte array
            $size = [System.Runtime.InteropServices.Marshal]::SizeOf($fileBasicInfo)
            $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($size)
            try {
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($fileBasicInfo, $ptr, $false)

                $bytes = New-Object byte[] $size

                [System.Runtime.InteropServices.Marshal]::Copy($ptr, $bytes, 0, $size)
            }
            finally {

                [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)

                $lastWriteTimeRef = $fileBasicInfo.LastWriteTime
                 Write-Host $lastWriteTimeRef
                [Kernel32.File]::SetFileInformationByHandle($fileHandle, $fileBasicInfo, $lastWriteTimeRef )

                if ($fileHandle -ne $null -and $fileHandle -ne [System.IntPtr]::Zero) {
                    Write-Host "pass"
                    Write-Host $bytes
                    Write-Host $bytes.Length


                    $writeResult = [Kernel32.File]::WriteFile($fileHandle, $bytes, [System.UInt32]$bytes.Length)


                    if (-not $writeResult) {
                        $lastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                        throw "WriteFile: Error writing to file. Last error: $lastError"
                    }
                }
            }


            # Return result

        }
        catch {
            Write-Host $_
        }
        finally {
            Write-Host "CloseHandle: Close file $currentPath"
            $bClosed = [Kernel32.File]::CloseHandle($fileHandle)

            if (!$bClosed) {
                Write-Warning "CloseHandle: Error closing handle $fileHandle of $Path"
            }
        }
    }
}
# Example 1: Get item ID for a file
$filePath = "J:\twitter.txt"
Write-Host $(Get-Item $filePath)
$itemInfo = Get-ItemId $(Get-Item $filePath)
Write-Host "File ID: $($itemInfo)"
#Export-ModuleMember -Function Get-ItemId