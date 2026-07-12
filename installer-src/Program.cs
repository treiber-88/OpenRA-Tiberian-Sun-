using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Runtime.Versioning;
using System.Threading.Tasks;
using System.Windows.Forms;

[assembly: SupportedOSPlatform("windows")]

static class Program
{
    const string ModVersion   = "playtest-20260222";
    const string EngineUrl    = $"https://github.com/OpenRA/OpenRA/releases/download/{ModVersion}/OpenRA-{ModVersion}-installer.exe";
    const string ReleasePage  = $"https://github.com/OpenRA/OpenRA/releases/tag/{ModVersion}";

    static readonly string[] EngineCandidates =
    [
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),        @"OpenRA (playtest)\TiberianDawn.exe"),
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),    @"OpenRA (playtest)\TiberianDawn.exe"),
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"OpenRA (playtest)\TiberianDawn.exe"),
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Programs\OpenRA (playtest)\TiberianDawn.exe"),
    ];

    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);

        var installer = new InstallerForm(ModVersion, EngineUrl, ReleasePage, EngineCandidates);
        Application.Run(installer);
    }
}
