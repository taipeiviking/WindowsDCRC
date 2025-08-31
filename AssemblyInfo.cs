using System.Windows;
using System.Reflection;
using System.IO;

[assembly:ThemeInfo(
    ResourceDictionaryLocation.None,            //where theme specific resource dictionaries are located
                                                //(used if a resource is not found in the page,
                                                // or application resource dictionaries)
    ResourceDictionaryLocation.SourceAssembly   //where the generic resource dictionary is located
                                                //(used if a resource is not found in the page,
                                                // app, or any theme specific resource dictionaries)
)]

namespace WindowsDCRC
{
    internal static partial class BuildInfo
    {
        internal static string Version
        {
            get
            {
                // Prefer generated constant if available (accessed via reflection to avoid design-time compile issues)
                var generated = typeof(BuildInfo).GetField("GeneratedVersion", BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static);
                if (generated != null)
                {
                    var val = generated.GetRawConstantValue()?.ToString();
                    if (!string.IsNullOrEmpty(val)) return val!;
                }
                var asm = Assembly.GetExecutingAssembly();
                return asm.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
                        ?? asm.GetName().Version?.ToString() ?? "1.0.0";
            }
        }

        internal static string BuildDateUtc
        {
            get
            {
                var asm = Assembly.GetExecutingAssembly();
                // Prefer generated constant if available
                var generatedDate = typeof(BuildInfo).GetField("GeneratedBuildDateUtc", BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static);
                if (generatedDate != null)
                {
                    var val = generatedDate.GetRawConstantValue()?.ToString();
                    if (!string.IsNullOrEmpty(val)) return val!;
                }
                foreach (var data in asm.GetCustomAttributes<AssemblyMetadataAttribute>())
                {
                    if (data.Key == "BuildDateUtc") return data.Value ?? string.Empty;
                }
                try
                {
                    var path = asm.Location;
                    if (!string.IsNullOrEmpty(path) && File.Exists(path))
                    {
                        var dt = File.GetLastWriteTime(path);
                        return dt.ToString("yyyy-MM-dd HH:mm:ss");
                    }
                }
                catch { }
                return string.Empty;
            }
        }
    }
}
