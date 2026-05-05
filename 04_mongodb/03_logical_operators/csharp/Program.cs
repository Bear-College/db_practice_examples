// Mirrors 03_logical_operators/example.py

using MongoDB.Bson;
using MongoDB.Driver;

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "logical_operators_people";

var coll = new MongoClient(mongoUri).GetDatabase(dbName).GetCollection<BsonDocument>(collectionName);

Console.WriteLine($"Mongo URI: {mongoUri}");
Console.WriteLine($"Database:  {dbName}");
Console.WriteLine($"Collection:{collectionName}\n");

await coll.DeleteManyAsync(new BsonDocument());
await coll.InsertManyAsync([
    new BsonDocument { ["name"] = "Anna", ["age"] = 17, ["city"] = "Chicago" },
    new BsonDocument { ["name"] = "Bohdan", ["age"] = 18, ["city"] = "New York" },
    new BsonDocument { ["name"] = "Chris", ["age"] = 25, ["city"] = "Los Angeles" },
    new BsonDocument { ["name"] = "Daria", ["age"] = 30, ["city"] = "Kyiv" },
    new BsonDocument { ["name"] = "Emma", ["age"] = 45, ["city"] = "New York" },
    new BsonDocument { ["name"] = "Farid", ["age"] = 60, ["city"] = "Berlin" },
    new BsonDocument { ["name"] = "Hanna", ["age"] = 61, ["city"] = "Warsaw" },
]);

await RunQuery(coll, "$and (logical AND)", new BsonDocument("$and", new BsonArray
{
    new BsonDocument("age", new BsonDocument("$gte", 18)),
    new BsonDocument("city", "New York"),
}));
await RunQuery(coll, "$or (logical OR)", new BsonDocument("$or", new BsonArray
{
    new BsonDocument("age", new BsonDocument("$lt", 18)),
    new BsonDocument("age", new BsonDocument("$gt", 60)),
}));
await RunQuery(coll, "$not (logical NOT)", new BsonDocument("age", new BsonDocument("$not", new BsonDocument("$gte", 18))));

return;

static string Pretty(List<BsonDocument> docs)
{
    if (docs.Count == 0) return "[]";
    static string V(BsonDocument d, string k) => d.Contains(k) ? d[k].ToString()!.Trim('"') : "";
    return "[" + string.Join(", ",
        docs.Select(d => $"{V(d, "name")} (age={V(d, "age")}, city={V(d, "city")})")) + "]";
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
