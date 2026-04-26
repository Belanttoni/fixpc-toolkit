// FixPC Toolkit — SensorBridge
// Reads hardware sensor data via LibreHardwareMonitorLib and writes JSON to stdout.
// Called by HardwareCollect.ps1 as an external process so dependency loading is
// handled by the .NET runtime naturally, without any PowerShell assembly tricks.
//
// Output schema (stdout):
//   {
//     "source": "SensorBridge",
//     "temperatures": [ { "name": "...", "hardwareName": "...", "value": 45.5 }, ... ],
//     "fans":         [ { "name": "...", "hardwareName": "...", "value": 1200.0 }, ... ],
//     "levels":       [ { "name": "...", "hardwareName": "...", "value": 85.0 }, ... ]
//   }
// On error:
//   { "error": "message" }
//
// Exit code: 0 = success, 1 = error.

using System.Text.Json;
using System.Text.Json.Serialization;
using LibreHardwareMonitor.Hardware;

namespace FixPC.SensorBridge;

internal sealed class SensorEntry
{
    [JsonPropertyName("name")]
    public string Name { get; init; } = string.Empty;

    [JsonPropertyName("hardwareName")]
    public string HardwareName { get; init; } = string.Empty;

    [JsonPropertyName("value")]
    public float Value { get; init; }
}

internal sealed class SensorResult
{
    [JsonPropertyName("source")]
    public string Source { get; init; } = "SensorBridge";

    [JsonPropertyName("temperatures")]
    public List<SensorEntry> Temperatures { get; init; } = [];

    [JsonPropertyName("fans")]
    public List<SensorEntry> Fans { get; init; } = [];

    [JsonPropertyName("levels")]
    public List<SensorEntry> Levels { get; init; } = [];
}

internal static class Program
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        WriteIndented = false,
        DefaultIgnoreCondition = JsonIgnoreCondition.Never
    };

    static int Main()
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;

        try
        {
            var result = CollectSensors();
            Console.WriteLine(JsonSerializer.Serialize(result, JsonOpts));
            return 0;
        }
        catch (Exception ex)
        {
            var err = new { error = ex.Message };
            Console.WriteLine(JsonSerializer.Serialize(err));
            return 1;
        }
    }

    static SensorResult CollectSensors()
    {
        var temps  = new List<SensorEntry>();
        var fans   = new List<SensorEntry>();
        var levels = new List<SensorEntry>();

        var computer = new Computer { IsCpuEnabled = true };
        computer.Open();

        try
        {
            // First pass: update all hardware so sensors have current values
            foreach (var hw in computer.Hardware)
            {
                hw.Update();
                foreach (var sub in hw.SubHardware)
                    sub.Update();
            }

            // Second pass: collect sensor readings
            foreach (var hw in computer.Hardware)
            {
                Collect(hw, hw.Name, temps, fans, levels);
                foreach (var sub in hw.SubHardware)
                    Collect(sub, hw.Name, temps, fans, levels);
            }
        }
        finally
        {
            computer.Close();
        }

        return new SensorResult
        {
            Temperatures = temps,
            Fans         = fans,
            Levels       = levels
        };
    }

    static void Collect(
        IHardware hw,
        string hardwareName,
        List<SensorEntry> temps,
        List<SensorEntry> fans,
        List<SensorEntry> levels)
    {
        foreach (var sensor in hw.Sensors)
        {
            if (sensor.Value is not float val) continue;

            var entry = new SensorEntry
            {
                Name         = sensor.Name,
                HardwareName = hardwareName,
                Value        = val
            };

            switch (sensor.SensorType)
            {
                case SensorType.Temperature:
                    // Sanity-check: only plausible CPU temperature readings
                    if (val > 0f && val <= 120f)
                        temps.Add(entry);
                    break;

                case SensorType.Fan:
                    fans.Add(entry);
                    break;

                case SensorType.Level:
                    levels.Add(entry);
                    break;
            }
        }
    }
}
