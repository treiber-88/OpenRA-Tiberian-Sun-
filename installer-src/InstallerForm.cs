using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net.Http;
using System.Runtime.Versioning;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

[SupportedOSPlatform("windows")]
sealed class InstallerForm : Form
{
    // ── controls ──────────────────────────────────────────────────────────────
    readonly Label      _titleLabel;
    readonly Label      _statusLabel;
    readonly ProgressBar _bar;
    readonly Button     _actionBtn;
    readonly Button     _cancelBtn;
    readonly PictureBox _logo;

    // ── state ─────────────────────────────────────────────────────────────────
    readonly string   _modVersion;
    readonly string   _engineUrl;
    readonly string   _releasePage;
    readonly string[] _engineCandidates;
    string?           _engineExe;

    enum Step { Welcome, CheckingEngine, DownloadConfirm, Downloading, InstallingEngine,
                InstallingMod, CreatingShortcut, Done, Error }
    Step _step = Step.Welcome;

    public InstallerForm(string modVersion, string engineUrl, string releasePage, string[] engineCandidates)
    {
        _modVersion       = modVersion;
        _engineUrl        = engineUrl;
        _releasePage      = releasePage;
        _engineCandidates = engineCandidates;

        // ── Window ────────────────────────────────────────────────────────────
        Text            = "Tiberian Sun — OpenRA Mod Installer";
        Size            = new Size(520, 360);
        MinimumSize     = Size;
        MaximumSize     = Size;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox     = false;
        StartPosition   = FormStartPosition.CenterScreen;
        BackColor       = Color.FromArgb(20, 20, 30);
        ForeColor       = Color.FromArgb(220, 220, 200);

        // ── Logo / banner ─────────────────────────────────────────────────────
        _logo = new PictureBox
        {
            Location  = new Point(0, 0),
            Size      = new Size(520, 80),
            BackColor = Color.FromArgb(40, 60, 40),
        };
        var bannerLabel = new Label
        {
            Text      = "C&C  TIBERIAN SUN",
            Font      = new Font("Consolas", 20f, FontStyle.Bold),
            ForeColor = Color.FromArgb(60, 200, 60),
            BackColor = Color.Transparent,
            AutoSize  = true,
            Location  = new Point(20, 22),
        };
        _logo.Controls.Add(bannerLabel);
        Controls.Add(_logo);

        // ── Title ─────────────────────────────────────────────────────────────
        _titleLabel = MakeLabel("OpenRA Mod Installer", 20, 100, 480, 28, 14f, FontStyle.Bold);
        Controls.Add(_titleLabel);

        // ── Status ────────────────────────────────────────────────────────────
        _statusLabel = MakeLabel(WelcomeText(), 20, 135, 480, 120, 9.5f, FontStyle.Regular);
        Controls.Add(_statusLabel);

        // ── Progress bar ──────────────────────────────────────────────────────
        _bar = new ProgressBar
        {
            Location  = new Point(20, 265),
            Size      = new Size(480, 22),
            Minimum   = 0,
            Maximum   = 100,
            Value     = 0,
            Style     = ProgressBarStyle.Continuous,
            Visible   = false,
        };
        Controls.Add(_bar);

        // ── Buttons ───────────────────────────────────────────────────────────
        _actionBtn = MakeButton("Install", 310, 295, 90, 32, true);
        _actionBtn.Click += OnActionClick;
        Controls.Add(_actionBtn);

        _cancelBtn = MakeButton("Cancel", 410, 295, 90, 32, false);
        _cancelBtn.Click += (_, _) => Close();
        Controls.Add(_cancelBtn);
    }

    // ── UI helpers ────────────────────────────────────────────────────────────

    static Label MakeLabel(string text, int x, int y, int w, int h, float fontSize, FontStyle style)
    {
        return new Label
        {
            Text      = text,
            Location  = new Point(x, y),
            Size      = new Size(w, h),
            Font      = new Font("Segoe UI", fontSize, style),
            ForeColor = Color.FromArgb(210, 210, 190),
            BackColor = Color.Transparent,
        };
    }

    static Button MakeButton(string text, int x, int y, int w, int h, bool isDefault)
    {
        return new Button
        {
            Text      = text,
            Location  = new Point(x, y),
            Size      = new Size(w, h),
            FlatStyle = FlatStyle.Flat,
            BackColor = isDefault ? Color.FromArgb(40, 100, 40) : Color.FromArgb(60, 40, 40),
            ForeColor = Color.White,
            Font      = new Font("Segoe UI", 9f, FontStyle.Bold),
        };
    }

    static string WelcomeText() =>
        "This installer will:\n\n" +
        "  1.  Check for OpenRA playtest-20260222\n" +
        "  2.  Download and install it if needed\n" +
        "  3.  Install the Tiberian Sun mod\n" +
        "  4.  Create a Desktop shortcut\n\n" +
        "Click Install to continue.";

    // ── Main flow ─────────────────────────────────────────────────────────────

    void OnActionClick(object? sender, EventArgs e)
    {
        _actionBtn.Enabled = false;

        switch (_step)
        {
            case Step.Welcome:
                _ = RunInstallAsync();
                break;
            case Step.DownloadConfirm:
                _ = DownloadAndInstallEngineAsync();
                break;
            case Step.Done:
                Close();
                break;
            case Step.Error:
                Process.Start(new ProcessStartInfo(_releasePage) { UseShellExecute = true });
                break;
        }
    }

    async Task RunInstallAsync()
    {
        SetStep(Step.CheckingEngine, "Checking for OpenRA…");
        await Task.Delay(300); // let the UI repaint

        _engineExe = FindEngine();

        if (_engineExe != null)
        {
            await DoModInstallAsync();
        }
        else
        {
            SetStep(Step.DownloadConfirm,
                $"OpenRA {_modVersion} was not found on this computer.\n\n" +
                "Click Download to fetch and run the OpenRA installer (~50 MB).\n\n" +
                "After the OpenRA installer finishes, this wizard will\n" +
                "continue automatically.");
            _actionBtn.Text    = "Download";
            _actionBtn.Enabled = true;
        }
    }

    async Task DownloadAndInstallEngineAsync()
    {
        var tmp = Path.Combine(Path.GetTempPath(), $"OpenRA-{_modVersion}-installer.exe");

        SetStep(Step.Downloading, $"Downloading OpenRA {_modVersion}…");
        _bar.Visible = true;

        bool ok = await DownloadFileAsync(_engineUrl, tmp);
        if (!ok)
        {
            SetStep(Step.Error,
                "Download failed. Please check your internet connection,\n" +
                "or download OpenRA manually:\n\n" +
                $"  {_releasePage}\n\n" +
                "Click Open to visit the download page.");
            _actionBtn.Text    = "Open";
            _actionBtn.Enabled = true;
            return;
        }

        SetStep(Step.InstallingEngine, "Running OpenRA installer — please follow the prompts…");
        _bar.Style = ProgressBarStyle.Marquee;

        await Task.Run(() => Process.Start(new ProcessStartInfo(tmp) { UseShellExecute = true })?.WaitForExit());

        _bar.Style = ProgressBarStyle.Continuous;
        _engineExe = FindEngine();

        if (_engineExe == null)
        {
            SetStep(Step.Error,
                "OpenRA does not appear to have been installed.\n\n" +
                "Please install it manually and re-run this installer.");
            _actionBtn.Text    = "Open";
            _actionBtn.Enabled = true;
            return;
        }

        await DoModInstallAsync();
    }

    async Task DoModInstallAsync()
    {
        SetStep(Step.InstallingMod, "Installing Tiberian Sun mod…");
        _bar.Visible = true;
        _bar.Value   = 10;
        await Task.Delay(100);

        try
        {
            InstallModFiles();
        }
        catch (Exception ex)
        {
            SetStep(Step.Error, $"Failed to install mod files:\n\n{ex.Message}");
            _actionBtn.Text    = "Close";
            _actionBtn.Enabled = true;
            return;
        }

        _bar.Value = 60;
        SetStep(Step.CreatingShortcut, "Creating Desktop shortcut…");
        await Task.Delay(100);

        CreateShortcut();

        _bar.Value = 100;
        SetStep(Step.Done,
            "Tiberian Sun has been installed!\n\n" +
            "A shortcut has been placed on your Desktop.\n\n" +
            "The first time you launch the game you will be prompted\n" +
            "to download the free Tiberian Sun content files.");
        _actionBtn.Text    = "Finish";
        _actionBtn.BackColor = Color.FromArgb(30, 80, 120);
        _actionBtn.Enabled = true;
        _cancelBtn.Visible = false;
    }

    void SetStep(Step step, string message)
    {
        _step = step;
        _statusLabel.Invoke(() => _statusLabel.Text = message);
        _titleLabel.Invoke(() => _titleLabel.Text = step switch
        {
            Step.CheckingEngine   => "Checking for OpenRA…",
            Step.DownloadConfirm  => "OpenRA Not Found",
            Step.Downloading      => "Downloading OpenRA…",
            Step.InstallingEngine => "Installing OpenRA…",
            Step.InstallingMod    => "Installing Mod…",
            Step.CreatingShortcut => "Creating Shortcut…",
            Step.Done             => "Installation Complete",
            Step.Error            => "Installation Failed",
            _                     => "Tiberian Sun — OpenRA Mod Installer",
        });
    }

    // ── Engine detection ──────────────────────────────────────────────────────

    string? FindEngine()
    {
        foreach (var p in _engineCandidates)
            if (File.Exists(p)) return p;
        return null;
    }

    // ── Mod file installation ─────────────────────────────────────────────────

    void InstallModFiles()
    {
        var modDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "OpenRA", "mods");
        Directory.CreateDirectory(modDir);

        var baseDir = AppContext.BaseDirectory;

        var oramod = Path.Combine(baseDir, "ts.oramod");
        if (File.Exists(oramod))
        {
            File.Copy(oramod, Path.Combine(modDir, "ts.oramod"), overwrite: true);
            return;
        }

        var modSrc = Path.Combine(baseDir, "mods", "ts");
        if (Directory.Exists(modSrc))
        {
            CopyDirectory(modSrc, Path.Combine(modDir, "ts"));
            return;
        }

        throw new DirectoryNotFoundException(
            $"Could not find ts.oramod or mods\\ts\\ relative to installer:\n{baseDir}");
    }

    static void CopyDirectory(string src, string dst)
    {
        Directory.CreateDirectory(dst);
        foreach (var f in Directory.GetFiles(src))
            File.Copy(f, Path.Combine(dst, Path.GetFileName(f)), overwrite: true);
        foreach (var d in Directory.GetDirectories(src))
            CopyDirectory(d, Path.Combine(dst, Path.GetFileName(d)));
    }

    // ── Shortcut creation ─────────────────────────────────────────────────────

    void CreateShortcut()
    {
        if (_engineExe == null) return;

        var desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        var lnk     = Path.Combine(desktop, "Tiberian Sun.lnk");
        var workDir = Path.GetDirectoryName(_engineExe) ?? "";

        var script =
            $"$ws = New-Object -ComObject WScript.Shell;" +
            $"$s = $ws.CreateShortcut('{lnk.Replace("'", "''")}');" +
            $"$s.TargetPath = '{_engineExe.Replace("'", "''")}';  " +
            $"$s.Arguments = 'Game.Mod=ts';" +
            $"$s.WorkingDirectory = '{workDir.Replace("'", "''")}';  " +
            $"$s.Description = 'OpenRA - Tiberian Sun';" +
            "$s.Save()";

        Process.Start(new ProcessStartInfo("powershell", $"-NoProfile -Command \"{script}\"")
        {
            UseShellExecute       = false,
            CreateNoWindow        = true,
        })?.WaitForExit();
    }

    // ── File download ─────────────────────────────────────────────────────────

    async Task<bool> DownloadFileAsync(string url, string dest)
    {
        try
        {
            using var http = new HttpClient();
            http.DefaultRequestHeaders.Add("User-Agent", "TiberianSun-Installer/1.0");

            using var response = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
            response.EnsureSuccessStatusCode();

            var total   = response.Content.Headers.ContentLength ?? -1L;
            var buffer  = new byte[81920];
            long downloaded = 0;

            await using var src = await response.Content.ReadAsStreamAsync();
            await using var dst = File.Create(dest);

            int read;
            while ((read = await src.ReadAsync(buffer)) > 0)
            {
                await dst.WriteAsync(buffer.AsMemory(0, read));
                downloaded += read;

                if (total > 0)
                {
                    var pct = (int)(downloaded * 100 / total);
                    _bar.Invoke(() => _bar.Value = pct);
                    _statusLabel.Invoke(() =>
                        _statusLabel.Text = $"Downloading OpenRA {_modVersion}…  {downloaded / 1_048_576} / {total / 1_048_576} MB");
                }
            }
            return true;
        }
        catch
        {
            return false;
        }
    }
}
