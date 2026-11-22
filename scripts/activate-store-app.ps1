param([Parameter(Mandatory)][string]$ApplicationId, [string]$Document = '')
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Disposable CI only.' }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class StoreActivation {
    [ComImport, Guid("2e941141-7f97-4756-ba1d-9decde894a3d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IApplicationActivationManager {
        [PreserveSig] int ActivateApplication([MarshalAs(UnmanagedType.LPWStr)] string appId,
            [MarshalAs(UnmanagedType.LPWStr)] string arguments, uint options, out uint processId);
    }
    public static uint Launch(string appId, string arguments) {
        var type = Type.GetTypeFromCLSID(new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C"));
        var manager = (IApplicationActivationManager)Activator.CreateInstance(type);
        uint pid;
        int result = manager.ActivateApplication(appId, arguments, 0, out pid);
        Marshal.ThrowExceptionForHR(result);
        return pid;
    }
}
'@
$arguments = if ($Document) { '"' + $Document + '"' } else { '' }
[StoreActivation]::Launch($ApplicationId,$arguments)
