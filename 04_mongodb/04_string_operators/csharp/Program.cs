// Mirrors 04_string_operators/example.py ($regex + $text)

using MongoDB.Bson;
using MongoDB.Driver;

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "string_operators_people";

var db = new MongoClient(mongoUri).GetDatabase(dbName);
await db.DropCollectionAsync(collectionName);
var coll = db.GetCollection<BsonDocument>(collectionName);

Console.WriteLine($"Mongo URI: {mongoUri}");
Console.WriteLine($"Database:  {dbName}");
Console.WriteLine($"Collection:{collectionName}\n");

await coll.InsertManyAsync([
    new BsonDocument { ["name"] = "Anna", ["email"] = "anna@gmail.com", ["bio"] = "Frontend developer and UI engineer" },
    new BsonDocument { ["name"] = "Bohdan", ["email"] = "bohdan@outlook.com", ["bio"] = "Backend developer working with Python" },
    new BsonDocument { ["name"] = "Chris", ["email"] = "chris@gmail.com", ["bio"] = "Data analyst and SQL specialist" },
    new BsonDocument { ["name"] = "Daria", ["email"] = "daria@yahoo.com", ["bio"] = "Mobile engineer and mentor" },
]);

await coll.Indexes.CreateOneAsync(new CreateIndexModel<BsonDocument>(
    Builders<BsonDocument>.IndexKeys.Text("bio"),
    new CreateIndexOptions { Name = "ix_bio_text" }));

await RunQuery(coll, "$regex (similar to SQL LIKE)",
    new BsonDocument("email", new BsonDocument("$regex", "@gmail.com$")));
await RunQuery(coll, "$text (full-text search)",
    new BsonDocument("$text", new BsonDocument("$search", "developer")));

return;

static string Pretty(List<BsonDocument> docs)
{
    if (docs.Count == 0) return "[]";
    static string S(BsonDocument d, string k) =>
        d.Contains(k) && !d[k].IsBsonNull ? d[k].ToString()!.Trim('"') : "";
    return "[" + string.Join(", ", docs.Select(d => $"{S(d, "name")} <{S(d, "email")}>")) + "]";
}

static async Task RunQuery(IMongoCollection<BsonDocument> coll, string label, BsonDocument query)
{
    var docs = await coll.Find(query).Sort(new BsonDocument("name", 1))
        .Project(Builders<BsonDocument>.Projection.Exclude("_id")).ToListAsync();
    Console.WriteLine($"{label}");
    Console.WriteLine($"  query={query}");
    Console.WriteLine($"  count={docs.Count}");
    Console.WriteLine($"  docs={Pretty(docs)}\n");
}
