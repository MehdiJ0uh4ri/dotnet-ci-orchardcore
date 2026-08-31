using System.Diagnostics;
using System.Text.Json;

namespace OrchardCore.BlackBox.Tests;

public sealed class ImageContractTests
{
    private static string Inspect(string image, string format)
    {
        var psi = new ProcessStartInfo("docker", $"inspect --format {format} {image}")
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        using var p = Process.Start(psi)!;
        var stdout = p.StandardOutput.ReadToEnd();
        p.WaitForExit();
        Assert.True(p.ExitCode == 0, p.StandardError.ReadToEnd());
        return stdout.Trim();
    }

    private readonly string _image =
        Environment.GetEnvironmentVariable("IMAGE_REF") ?? "orchardcore-cms:v3.0.1";

    [Fact]
    public void Runs_as_non_root()
    {
        Assert.Equal("1654:1654", Inspect(_image, "'{{.Config.User}}'").Trim('\''));
    }

    [Fact]
    public void Carries_upstream_revision_label()
    {
        var labels = JsonDocument.Parse(Inspect(_image, "'{{json .Config.Labels}}'").Trim('\''));
        var rev = labels.RootElement.GetProperty("org.opencontainers.image.revision").GetString();
        Assert.False(string.IsNullOrWhiteSpace(rev));
        Assert.Equal(40, rev!.Length);
    }
}
