// Mirrors 09_indexes/example.py

using MongoDB.Bson;
using MongoDB.Driver;

var runCreateIndexes = Environment.GetEnvironmentVariable("MONGO_RUN_CREATE_INDEXES") != "0";
var runDropIndexes = Environment.GetEnvironmentVariable("MONGO_RUN_DROP_INDEXES") == "1";

var indexesToCreate = new HashSet<string>
{
    "ix_city_single",
    "ix_city_age_compound",
    "uq_email_unique",
    "ix_bio_text",
    "ix_expires_at_ttl",
    "ix_user_id_hashed",
};

var indexesToDrop = new List<string>
{
    // "ix_city_single",
};

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "indexes_people";

var coll = new MongoClient(mongoUri).GetDatabase(dbName).GetCollection<BsonDocument>(collectionName);

Console.WriteLine($"Mongo URI: {mongoUri}");
Console.WriteLine($"Database:  {dbName}");
Console.WriteLine($"Collection:{collectionName}");

await Seed(coll);
await PrintIndexes(coll);

if (runCreateIndexes)
{
    Console.WriteLine("\nCreating indexes...");
    foreach (var spec in DesiredIndexes())
    {
        if (!indexesToCreate.Contains(spec.Name))
            continue;
        await coll.Indexes.CreateOneAsync(new CreateIndexModel<BsonDocument>(spec.Keys, spec.Options));
        Console.WriteLine($"Created index: {spec.Name} ({spec.Desc})");
    }
    await PrintIndexes(coll);
}

if (runDropIndexes)
{
    Console.WriteLine("\nDropping configured indexes...");
    foreach (var indexName in indexesToDrop)
    {
        try
        {
            await coll.Indexes.DropOneAsync(indexName);
            Console.WriteLine($"Dropped index: {indexName}");
        }
        catch (MongoCommandException e)
        {
            Console.WriteLine($"Could not drop index '{indexName}': {e.Message}");
        }
    }
    await PrintIndexes(coll);
}

Console.WriteLine("\nDemo queries using indexes:");
var cityDocs = await coll.Find(new BsonDocument("city", "New York")).Sort(new BsonDocument("name", 1))
    .Project(Builders<BsonDocument>.Projection.Exclude("_id").Include("name").Include("city")).ToListAsync();
Console.WriteLine($"  city='New York' -> {string.Join(", ", cityDocs.Select(d => d.ToJson()))}");

var textDocs = await coll.Find(new BsonDocument("$text", new BsonDocument("$search", "developer")))
    .Project(Builders<BsonDocument>.Projection.Exclude("_id").Include("name").Include("bio")).ToListAsync();
Console.WriteLine($"  $text search 'developer' -> {string.Join(", ", textDocs.Select(d => d.ToJson()))}");

return;

static async Task Seed(IMongoCollection<BsonDocument> coll)
{
    var now = DateTime.UtcNow;
    await coll.DeleteManyAsync(new BsonDocument());
    await coll.InsertManyAsync([
        new BsonDocument {
            ["user_id"] = "u1001", ["name"] = "Anna", ["email"] = "anna@example.com",
            ["city"] = "New York", ["age"] = 22, ["bio"] = "Python developer and backend engineer",
            ["expires_at"] = now.AddDays(5),
        },
        new BsonDocument {
            ["user_id"] = "u1002", ["name"] = "Bohdan", ["email"] = "bohdan@example.com",
            ["city"] = "Chicago", ["age"] = 28, ["bio"] = "JavaScript developer and frontend specialist",
            ["expires_at"] = now.AddDays(3),
        },
        new BsonDocument {
            ["user_id"] = "u1003", ["name"] = "Chris", ["email"] = "chris@example.com",
            ["city"] = "New York", ["age"] = 35, ["bio"] = "Data engineer and SQL expert",
            ["expires_at"] = now.AddDays(10),
        },
        new BsonDocument {
            ["user_id"] = "u1004", ["name"] = "Daria", ["email"] = "daria@example.com",
            ["city"] = "Kyiv", ["age"] = 30, ["bio"] = "Engineering manager and mentor",
            ["expires_at"] = now.AddDays(-1),
        },
    ]);
}

static IEnumerable<(string Name, IndexKeysDefinition<BsonDocument> Keys, CreateIndexOptions Options, string Desc)> DesiredIndexes()
{
    var b = Builders<BsonDocument>.IndexKeys;
    yield return (
        "ix_city_single",
        b.Ascending("city"),
        new CreateIndexOptions { Name = "ix_city_single" },
        "Single field index on city");
    yield return (
        "ix_city_age_compound",
        b.Ascending("city").Descending("age"),
        new CreateIndexOptions { Name = "ix_city_age_compound" },
        "Compound index on city + age");
    yield return (
        "uq_email_unique",
        b.Ascending("email"),
        new CreateIndexOptions { Name = "uq_email_unique", Unique = true },
        "Unique index on email");
    yield return (
        "ix_bio_text",
        b.Text("bio"),
        new CreateIndexOptions { Name = "ix_bio_text" },
        "Text index on bio");
    yield return (
        "ix_expires_at_ttl",
        b.Ascending("expires_at"),
        new CreateIndexOptions { Name = "ix_expires_at_ttl", ExpireAfter = TimeSpan.Zero },
        "TTL index on expires_at");
    yield return (
        "ix_user_id_hashed",
        b.Hashed("user_id"),
        new CreateIndexOptions { Name = "ix_user_id_hashed" },
        "Hashed index on user_id");
}

static async Task PrintIndexes(IMongoCollection<BsonDocument> coll)
{
    Console.WriteLine($"\nIndexes in {coll.CollectionNamespace.CollectionName}:");
    using var cursor = await coll.Indexes.ListAsync();
    var list = await cursor.ToListAsync();
    foreach (var idx in list)
    {
        var name = idx.GetValue("name", "").ToString();
        var key = idx.GetValue("key", new BsonDocument()).AsBsonDocument;
        Console.WriteLine($"  - {name}: keys={string.Join(", ", key.Elements.Select(e => $"{e.Name}={e.Value}"))}");
    }
}
