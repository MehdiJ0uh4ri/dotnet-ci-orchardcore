using System.Net;

namespace OrchardCore.BlackBox.Tests;

[Collection("cms")]
public sealed class SmokeTests(CmsFixture fx)
{
    [Fact]
    public async Task Setup_screen_is_served()
    {
        var res = await fx.Client.GetAsync("/");
        Assert.True((int)res.StatusCode < 500, $"status {(int)res.StatusCode}");
        var body = await res.Content.ReadAsStringAsync();
        Assert.Contains("Orchard", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Unknown_route_is_404_not_500()
    {
        var res = await fx.Client.GetAsync($"/{Guid.NewGuid():N}");
        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
    }

    [Fact]
    public async Task Server_header_is_not_leaking_kestrel_version()
    {
        var res = await fx.Client.GetAsync("/");
        var server = res.Headers.TryGetValues("Server", out var v) ? string.Join(",", v) : "";
        Assert.DoesNotContain("10.0", server);
    }

    [Fact]
    public async Task Static_asset_pipeline_answers()
    {
        var res = await fx.Client.GetAsync("/favicon.ico");
        Assert.True(res.StatusCode is HttpStatusCode.OK or HttpStatusCode.NotFound);
    }
}
