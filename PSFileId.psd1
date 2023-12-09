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
        public LargeInteger CreationTime;
        public LargeInteger LastAccessTime;
        public LargeInteger LastWriteTime;
        public LargeInteger ChangeTime;
        public LargeInteger EndOfFile;
        public LargeInteger AllocationSize;
        public uint FileAttributes;
        public uint FileNameLength;
        public uint EaSize;
        public char ShortNameLength;
        [MarshalAsAttribute(UnmanagedType.ByValTStr, SizeConst = 12)]
        public string ShortName;
        public LargeInteger FileId;
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
        out FILE_ID_BOTH_DIR_INFO fileInfo,
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
        Add-Type -MemberDefinition $script:memberDefinition -Name File -Namespace Kernel32
    }

    process {
        $currentPath = $Path.FullName

        try {
            Write-Verbose "CreateFile: Open file $currentPath"
            $fileHandle = [Kernel32.File]::CreateFile($currentPath,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::ReadWrite,
                [System.IntPtr]::Zero,
                [System.IO.FileMode]::Open,
                [System.UInt32]0x02000000,
                [System.IntPtr]::Zero)

            if ($fileHandle -eq -1) {
                throw "CreateFile: Error opening file $Path"
            }

            # Output object
            #$fileBasicInfo = New-Object -TypeName Kernel32.File+FILE_BASIC_INFO
            $fileBasicInfo = New-Object -TypeName Kernel32.File+FILE_ID_BOTH_DIR_INFO

            Write-Verbose "GetFileInformationByHandleEx: Get basic info"
            $bRetrieved = [Kernel32.File]::GetFileInformationByHandleEx($fileHandle, 19,
                [ref]$fileBasicInfo,
                [System.Runtime.InteropServices.Marshal]::SizeOf($fileBasicInfo))

            if (!$bRetrieved) {
                throw "GetFileInformationByHandleEx: Error retrieving item information"
            }

            # Return result
            [PSCustomObject]@{
                Item   = $Path
                #CreationTime = [System.DateTime]::FromFileTime($fileBasicInfo.CreationTime)
                #LastAccessTime = [System.DateTime]::FromFileTime($fileBasicInfo.LastAccessTime)
                #LastWriteTime = [System.DateTime]::FromFileTime($fileBasicInfo.LastWriteTime)
                #ChangeTime = [System.DateTime]::FromFileTime($fileBasicInfo.ChangeTime)
                #FileAttributes = $fileBasicInfo.FileAttributes
                FileId = $fileBasicInfo.FileId.QuadPart
            }
        }
        catch {
            throw $_
        }
        finally {
            Write-Verbose "CloseHandle: Close file $currentPath"
            $bClosed = [Kernel32.File]::CloseHandle($fileHandle)

            if (!$bClosed) {
                Write-Warning "CloseHandle: Error closing handle $fileHandle of $Path"
            }
        }
    }
}

Export-ModuleMember -Function Get-ItemId