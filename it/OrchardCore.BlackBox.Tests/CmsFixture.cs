using DotNet.Testcontainers.Builders;
using DotNet.Testcontainers.Containers;
using Testcontainers.PostgreSql;

namespace OrchardCore.BlackBox.Tests;

public sealed class CmsFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _db = new PostgreSqlBuilder()
        .WithImage("postgres:17-alpine")
        .WithDatabase("orchard").WithUsername("orchard").WithPassword("orchard")
        .Build();

    private IContainer? _cms;

    public HttpClient Client { get; private set; } = default!;
    public string ImageRef { get; } =
        Environment.GetEnvironmentVariable("IMAGE_REF") ?? "orchardcore-cms:v3.0.1";

    public async ValueTask InitializeAsync()
    {
        await _db.StartAsync();

        _cms = new ContainerBuilder()
            .WithImage(ImageRef)
            .WithPortBinding(8080, true)
            .WithEnvironment("ASPNETCORE_URLS", "http://+:8080")
            .WithEnvironment("OrchardCore__Default__State", "Uninitialized")
            .WithWaitStrategy(Wait.ForUnixContainer()
                .UntilHttpRequestIsSucceeded(r => r.ForPort(8080).ForStatusCodeMatching(c => (int)c < 500)))
            .WithStartupCallback((_, _) => Task.CompletedTask)
            .Build();

        await _cms.StartAsync();
        Client = new HttpClient
        {
            BaseAddress = new Uri($"http://{_cms.Hostname}:{_cms.GetMappedPublicPort(8080)}"),
            Timeout = TimeSpan.FromSeconds(60),
        };
    }

    public async ValueTask DisposeAsync()
    {
        Client?.Dispose();
        if (_cms is not null) await _cms.DisposeAsync();
        await _db.DisposeAsync();
    }
}

[CollectionDefinition("cms")]
public sealed class CmsCollection : ICollectionFixture<CmsFixture>;
