using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using Microsoft.Win32;
using System.Diagnostics;
using System.IO;

namespace WindowsDCRC;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class MainWindow : Window
{
    private ObservableCollection<DisplayConfiguration> _configurations = new();

    public MainWindow()
    {
        InitializeComponent();
        Loaded += MainWindow_Loaded;
    }

    private void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        SetStatus("Ready");
        SetVersionStatus();
        RefreshConfigurations();
    }

    private void RefreshConfigurations()
    {
        try
        {
            SetStatus("Refreshing...");
            var results = DisplayConfigurationScanner.Scan();
            _configurations = new ObservableCollection<DisplayConfiguration>(results);
            ConfigGrid.ItemsSource = _configurations;
            UpdateDeleteButtonText();
            UpdateDetectedCount();
            SetStatus("Ready");
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, $"Failed to read registry: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            SetStatus("Error");
        }
    }

    private void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        RefreshConfigurations();
    }

    private void ConfigGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        UpdateDeleteButtonText();
    }

    private void UpdateDeleteButtonText()
    {
        if (ConfigGrid.SelectedItems != null && ConfigGrid.SelectedItems.Count > 0)
        {
            DeleteButton.Content = "Backup .reg and Delete Selected";
        }
        else
        {
            DeleteButton.Content = "Backup .reg and Delete All";
        }
    }

    private void DeleteButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var itemsToDelete = new List<DisplayConfiguration>();
            if (ConfigGrid.SelectedItems != null && ConfigGrid.SelectedItems.Count > 0)
            {
                foreach (var obj in ConfigGrid.SelectedItems)
                {
                    if (obj is DisplayConfiguration cfg)
                    {
                        itemsToDelete.Add(cfg);
                    }
                }
            }
            else
            {
                itemsToDelete.AddRange(_configurations);
            }

            if (itemsToDelete.Count == 0)
            {
                return;
            }

            var confirm = MessageBox.Show(this,
                $"This will first create a .reg backup, then delete {(ConfigGrid.SelectedItems != null && ConfigGrid.SelectedItems.Count > 0 ? "the selected" : "ALL")} {itemsToDelete.Count} configuration(s).\n\nProceed?",
                "Backup .reg and Delete",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning,
                MessageBoxResult.No);

            if (confirm != MessageBoxResult.Yes)
            {
                return;
            }

            var saveDialog = new Microsoft.Win32.SaveFileDialog
            {
                Title = "Backup configurations to .reg",
                Filter = "Registration Entries (*.reg)|*.reg|All files (*.*)|*.*",
                FileName = "WindowsDCRC_Backup.reg",
                OverwritePrompt = true
            };

            if (saveDialog.ShowDialog(this) != true)
            {
                return; // backup canceled; do not delete
            }

            // Backup selected/all
            SetStatus("Exporting...");
            var ok = DisplayConfigurationScanner.ExportRegFile(itemsToDelete.Select(s => s.RegistryKeyName), saveDialog.FileName);
            if (!ok)
            {
                MessageBox.Show(this, "Backup failed or nothing exported. Deletion cancelled.", "Backup .reg", MessageBoxButton.OK, MessageBoxImage.Exclamation);
                SetStatus("No export");
                return;
            }

            // Proceed to delete
            SetStatus("Deleting...");
            DisplayConfigurationScanner.DeleteConfigurations(itemsToDelete.Select(i => i.RegistryKeyName));
            RefreshConfigurations();
            SetStatus("Ready");
        }
        catch (UnauthorizedAccessException)
        {
            MessageBox.Show(this, "Access denied. Please run as Administrator to delete registry entries.", "Permission Required", MessageBoxButton.OK, MessageBoxImage.Exclamation);
            SetStatus("Access denied");
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, $"Failed to delete: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            SetStatus("Error");
        }
    }

    private void ExportButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var saveDialog = new Microsoft.Win32.SaveFileDialog
            {
                Title = "Backup configurations to .reg",
                Filter = "Registration Entries (*.reg)|*.reg|All files (*.*)|*.*",
                FileName = "WindowsDCRC_Backup.reg",
                OverwritePrompt = true
            };

            if (saveDialog.ShowDialog(this) != true)
            {
                return;
            }

            var selected = new List<DisplayConfiguration>();
            if (ConfigGrid.SelectedItems != null && ConfigGrid.SelectedItems.Count > 0)
            {
                foreach (var obj in ConfigGrid.SelectedItems)
                {
                    if (obj is DisplayConfiguration cfg)
                    {
                        selected.Add(cfg);
                    }
                }
            }
            else
            {
                selected.AddRange(_configurations);
            }

            SetStatus("Exporting...");
            var ok = DisplayConfigurationScanner.ExportRegFile(selected.Select(s => s.RegistryKeyName), saveDialog.FileName);
            if (ok)
            {
                MessageBox.Show(this, "Backup complete.", "Backup .reg", MessageBoxButton.OK, MessageBoxImage.Information);
                SetStatus("Backup complete");
            }
            else
            {
                MessageBox.Show(this, "Nothing was exported.", "Backup .reg", MessageBoxButton.OK, MessageBoxImage.Information);
                SetStatus("No export");
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, $"Failed to backup: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            SetStatus("Error");
        }
    }

    private void AboutButton_Click(object sender, RoutedEventArgs e)
    {
        var info = new StringBuilder();
        info.AppendLine("🔎 What This Tool Does");
        info.AppendLine();
        info.AppendLine("Windows DCRC helps you clean up and manage display profiles saved in your system’s registry. It's especially useful if you frequently switch between different monitor setups or want to reset configurations that may be causing issues.");
        info.AppendLine();
        info.AppendLine("• ✅ Scans the registry for all saved display profiles");
        info.AppendLine("• 📊 Shows detailed info per profile: resolution, position, rotation, scaling, and refresh rate");
        info.AppendLine("• 💾 Backs up selected or all profiles into a safe .reg file (easy to restore later)");
        info.AppendLine("• 🗑️ Removes unwanted profiles from both 32-bit and 64-bit registry views (admin rights required)");
        info.AppendLine();
        info.AppendLine("🛠️ How to Use It");
        info.AppendLine();
        info.AppendLine("1. Click \"Backup .reg\" to save your current display settings — always do this first!");
        info.AppendLine("2. Select one or more profiles you'd like to remove, then click \"Delete Selected\" and confirm.");
        info.AppendLine("3. Click \"Refresh\" to see the updated list.");
        info.AppendLine("4. If needed, double-click the backed-up .reg file to restore your settings, then click \"Refresh\" again.");
        info.AppendLine();
        info.AppendLine("“⚠️ Tip: Always back up before deleting — registry changes can’t be undone! ”");

        var textBlock = new TextBlock
        {
            Text = info.ToString(),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(16)
        };
        var contentPanel = new StackPanel
        {
            Orientation = Orientation.Vertical
        };
        contentPanel.Children.Add(textBlock);

        var root = new DockPanel();
        var buttonsPanel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 8, 16, 16)
        };
        var okButton = new Button
        {
            Content = "OK",
            Width = 80,
            Height = 30,
            IsDefault = true,
            IsCancel = true
        };
        okButton.Click += (_, __) =>
        {
            if (Window.GetWindow((DependencyObject)sender!) is Window parent)
            {
                // no-op; handled on dialog window
            }
        };
        buttonsPanel.Children.Add(okButton);
        DockPanel.SetDock(buttonsPanel, Dock.Bottom);
        root.Children.Add(buttonsPanel);

        // High-resolution app image appended after the text
        var imagePath = System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Assets", "AppImage_FullSize.png");
        if (!File.Exists(imagePath))
        {
            var altLarge = new[] { "AppImage_256x256.png", "AppImage_128x128.png" }
                .Select(n => System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Assets", n))
                .FirstOrDefault(File.Exists);
            if (altLarge != null) imagePath = altLarge;
        }
        if (File.Exists(imagePath))
        {
            var bottomImage = new Image
            {
                Source = new BitmapImage(new Uri(imagePath, UriKind.Absolute)),
                Height = 256,
                Margin = new Thickness(16, 8, 16, 8),
                Stretch = Stretch.Uniform,
                HorizontalAlignment = HorizontalAlignment.Center
            };
            contentPanel.Children.Add(bottomImage);
        }
        // Content fills remaining space
        root.Children.Add(contentPanel);

        var dialog = new Window
        {
            Title = "About Windows DCRC",
            Owner = this,
            Content = root,
            Width = 780,
            SizeToContent = SizeToContent.Height,
            ResizeMode = ResizeMode.CanResize,
            WindowStartupLocation = WindowStartupLocation.CenterOwner
        };
        okButton.Click += (_, __) => dialog.Close();
        dialog.ShowDialog();
    }

    private void SetStatus(string message)
    {
        if (StatusReadyText != null)
        {
            StatusReadyText.Text = message;
        }
    }

    private void UpdateDetectedCount()
    {
        if (StatusDetectedCountText != null)
        {
            StatusDetectedCountText.Text = (_configurations?.Count ?? 0).ToString();
        }
    }

    private void SetVersionStatus()
    {
        try
        {
            if (StatusVersionText != null)
            {
                StatusVersionText.Text = WindowsDCRC.BuildInfo.Version;
            }
            if (StatusBuildDateText != null)
            {
                StatusBuildDateText.Text = WindowsDCRC.BuildInfo.BuildDateUtc;
            }
        }
        catch { }
    }
}

public class DisplayConfiguration
{
    public string RegistryKeyName { get; set; } = string.Empty;
    public string? SetId { get; set; }
    public DateTime? Timestamp { get; set; }
    public string TimestampDisplay => Timestamp?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty;

    public List<DisplayNode> Displays { get; set; } = new();

    public int DisplayCount => Displays.Count;
    public string ResolutionSummary => string.Join(", ", Displays.Select(d => $"{d.Width}x{d.Height}"));
    public string PositionSummary => string.Join(", ", Displays.Select(d => $"({d.PositionX},{d.PositionY})"));
    public string RotationSummary => string.Join(", ", Displays.Select(d => d.RotationDisplay));
    public string ScalingSummary => string.Join(", ", Displays.Select(d => d.ScalingDisplay));
    public string RefreshRateSummary => string.Join(", ", Displays.Select(d => d.RefreshHzDisplay));
}

public class DisplayNode
{
    public int Width { get; set; }
    public int Height { get; set; }
    public int PositionX { get; set; }
    public int PositionY { get; set; }
    public int Rotation { get; set; }
    public int Scaling { get; set; }
    public double? RefreshHz { get; set; }

    public string RotationDisplay => Rotation switch
    {
        1 => "0°",
        2 => "90°",
        3 => "180°",
        4 => "270°",
        _ => Rotation.ToString()
    };

    public string ScalingDisplay => Scaling.ToString();
    public string RefreshHzDisplay => RefreshHz.HasValue ? $"{Math.Round(RefreshHz.Value, 1)}" : string.Empty;
}

public static class DisplayConfigurationScanner
{
    private const string ConfigurationRegPath = @"SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration";

    public static List<DisplayConfiguration> Scan()
    {
        var results = new List<DisplayConfiguration>();

        foreach (var view in new[] { RegistryView.Registry64, RegistryView.Registry32 })
        {
            try
            {
                using var baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view);
                using var configKey = baseKey.OpenSubKey(ConfigurationRegPath, writable: false);
                if (configKey == null)
                {
                    continue;
                }

                foreach (var subKeyName in configKey.GetSubKeyNames())
                {
                    using var entryKey = configKey.OpenSubKey(subKeyName, writable: false);
                    if (entryKey == null)
                    {
                        continue;
                    }

                    var entry = new DisplayConfiguration
                    {
                        RegistryKeyName = subKeyName,
                        SetId = entryKey.GetValue("SetId") as string
                    };

                    var tsBytes = entryKey.GetValue("Timestamp") as byte[];
                    if (tsBytes != null && tsBytes.Length >= 8)
                    {
                        try
                        {
                            long fileTime = BitConverter.ToInt64(tsBytes, 0);
                            entry.Timestamp = DateTime.FromFileTimeUtc(fileTime).ToLocalTime();
                        }
                        catch { /* ignore timestamp parse errors */ }
                    }

                    foreach (var displaySubName in entryKey.GetSubKeyNames())
                    {
                        // Expect names like "00", "01", etc.
                        if (displaySubName.Length != 2 || !displaySubName.All(char.IsDigit))
                        {
                            continue;
                        }

                        using var displayKey = entryKey.OpenSubKey(displaySubName, writable: false);
                        if (displayKey == null)
                        {
                            continue;
                        }

                        var node = new DisplayNode
                        {
                            Width = ReadInt(displayKey, "PrimSurfSize.cx"),
                            Height = ReadInt(displayKey, "PrimSurfSize.cy"),
                            PositionX = ReadInt(displayKey, "Position.cx"),
                            PositionY = ReadInt(displayKey, "Position.cy")
                        };

                        using var detailKey = displayKey.OpenSubKey("00", writable: false);
                        if (detailKey != null)
                        {
                            node.Rotation = ReadInt(detailKey, "Rotation");
                            node.Scaling = ReadInt(detailKey, "Scaling");

                            var num = ReadUInt(detailKey, "VSyncFreq.Numerator");
                            var den = ReadUInt(detailKey, "VSyncFreq.Denominator");
                            if (num > 0 && den > 0)
                            {
                                node.RefreshHz = (double)num / den;
                            }
                        }

                        entry.Displays.Add(node);
                    }

                    results.Add(entry);
                }
            }
            catch
            {
                // Continue with next view on error
            }
        }

        // De-duplicate by key name across views
        return results
            .GroupBy(r => r.RegistryKeyName, StringComparer.OrdinalIgnoreCase)
            .Select(g => g.First())
            .OrderBy(r => r.RegistryKeyName, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    public static void DeleteConfigurations(IEnumerable<string> keyNames)
    {
        foreach (var view in new[] { RegistryView.Registry64, RegistryView.Registry32 })
        {
            using var baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, view);
            using var configKey = baseKey.OpenSubKey(ConfigurationRegPath, writable: true);
            if (configKey == null)
            {
                continue;
            }

            foreach (var keyName in keyNames.Distinct(StringComparer.OrdinalIgnoreCase))
            {
                try
                {
                    // Delete directly under Configuration
                    baseKey.DeleteSubKeyTree($"{ConfigurationRegPath}\\{keyName}", throwOnMissingSubKey: false);
                }
                catch (ArgumentException)
                {
                    // Missing key; ignore
                }
            }
        }
    }

    public static bool ExportRegFile(IEnumerable<string> keyNames, string outputRegFile)
    {
        var names = keyNames?
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(n => n, StringComparer.OrdinalIgnoreCase)
            .ToList() ?? new List<string>();
        if (names.Count == 0)
        {
            return false;
        }

        // We'll export with reg.exe for each key and concatenate into a single file with header
        var tempDir = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "WindowsDCRC_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempDir);
        var tempFiles = new List<string>();
        try
        {
            foreach (var name in names)
            {
                string keyPath = $@"HKEY_LOCAL_MACHINE\{ConfigurationRegPath}\{name}";
                string tmp = System.IO.Path.Combine(tempDir, name + ".reg");

                var psi = new ProcessStartInfo
                {
                    FileName = "reg.exe",
                    Arguments = $"export \"{keyPath}\" \"{tmp}\" /y",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };
                using var proc = Process.Start(psi);
                if (proc == null)
                {
                    continue;
                }
                proc.WaitForExit(15000);
                if (proc.ExitCode == 0 && File.Exists(tmp))
                {
                    tempFiles.Add(tmp);
                }
            }

            if (tempFiles.Count == 0)
            {
                return false;
            }

            using var writer = new StreamWriter(outputRegFile, false, Encoding.Unicode);
            writer.WriteLine("Windows Registry Editor Version 5.00");
            writer.WriteLine();
            // Include the base [Configuration] section to match Windows export of the parent key
            writer.WriteLine($@"[HKEY_LOCAL_MACHINE\{ConfigurationRegPath}]");
            writer.WriteLine();

            foreach (var tf in tempFiles)
            {
                // Skip the header line(s) and append contents
                bool firstLine = true;
                bool skippingLeadingBlanks = false;
                foreach (var line in File.ReadLines(tf, Encoding.Unicode))
                {
                    if (firstLine && line.StartsWith("Windows Registry Editor Version", StringComparison.OrdinalIgnoreCase))
                    {
                        firstLine = false;
                        skippingLeadingBlanks = true;
                        continue;
                    }
                    firstLine = false;
                    if (skippingLeadingBlanks)
                    {
                        if (string.IsNullOrWhiteSpace(line))
                        {
                            continue;
                        }
                        skippingLeadingBlanks = false;
                    }
                    writer.WriteLine(line);
                }
                writer.WriteLine();
            }
            return true;
        }
        finally
        {
            try { Directory.Delete(tempDir, true); } catch { }
        }
    }

    private static int ReadInt(RegistryKey key, string valueName)
    {
        try
        {
            object? val = key.GetValue(valueName);
            if (val == null) return 0;
            return Convert.ToInt32(val);
        }
        catch
        {
            return 0;
        }
    }

    private static uint ReadUInt(RegistryKey key, string valueName)
    {
        try
        {
            object? val = key.GetValue(valueName);
            if (val == null) return 0u;
            return Convert.ToUInt32(val);
        }
        catch
        {
            return 0u;
        }
    }
}