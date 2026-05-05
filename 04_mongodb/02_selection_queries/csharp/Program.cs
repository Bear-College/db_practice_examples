// Mirrors 02_selection_queries/example.py

using MongoDB.Bson;
using MongoDB.Driver;

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "selection_queries_people";

var client = new MongoClient(mongoUri);
var coll = client.GetDatabase(dbName).GetCollection<BsonDocument>(collectionName);

Console.WriteLine($"Mongo URI: {mongoUri}");
Console.WriteLine($"Database:  {dbName}");
Console.WriteLine($"Collection:{collectionName}\n");

await coll.DeleteManyAsync(new BsonDocument());
await coll.InsertManyAsync([
    new BsonDocument {
        ["name"] = "Anna", ["age"] = 17, ["city"] = "Chicago",
        ["profile"] = new BsonDocument { ["city"] = "Chicago", ["experience"] = 1, ["role"] = "intern" },
    },
    new BsonDocument {
        ["name"] = "Bohdan", ["age"] = 18, ["city"] = "New York",
        ["profile"] = new BsonDocument { ["city"] = "New York", ["experience"] = 2, ["role"] = "junior" },
    },
    new BsonDocument {
        ["name"] = "Chris", ["age"] = 25, ["city"] = "Los Angeles",
        ["profile"] = new BsonDocument { ["city"] = "Los Angeles", ["experience"] = 4, ["role"] = "developer" },
    },
    new BsonDocument {
        ["name"] = "Daria", ["age"] = 30, ["city"] = "Kyiv",
        ["profile"] = new BsonDocument { ["city"] = "Kyiv", ["experience"] = 7, ["role"] = "lead" },
    },
    new BsonDocument {
        ["name"] = "Emma", ["age"] = 45, ["city"] = "New York",
        ["profile"] = new BsonDocument { ["city"] = "New York", ["experience"] = 15, ["role"] = "architect" },
    },
    new BsonDocument {
        ["name"] = "Farid", ["age"] = 60, ["city"] = "Berlin",
        ["profile"] = new BsonDocument { ["city"] = "Berlin", ["experience"] = 20, ["role"] = "principal" },
    },
    new BsonDocument {
        ["name"] = "Hanna", ["age"] = 61, ["city"] = "Warsaw",
        ["profile"] = new BsonDocument { ["city"] = "Warsaw", ["experience"] = 21, ["role"] = "advisor" },
    },
]);

await RunQuery(coll, "$eq  (equals)", new BsonDocument("age", new BsonDocument("$eq", 25)));
await RunQuery(coll, "$ne  (not equals)", new BsonDocument("age", new BsonDocument("$ne", 25)));
await RunQuery(coll, "$gt  (greater than)", new BsonDocument("age", new BsonDocument("$gt", 25)));
await RunQuery(coll, "$lt  (less than)", new BsonDocument("age", new BsonDocument("$lt", 30)));
await RunQuery(coll, "$gte (greater or equals)", new BsonDocument("age", new BsonDocument("$gte", 18)));
await RunQuery(coll, "$lte (less or equals)", new BsonDocument("age", new BsonDocument("$lte", 60)));
await RunQuery(coll, "$in  (in list)",
    new BsonDocument("city", new BsonDocument("$in", new BsonArray { "New York", "Los Angeles" })));
await RunQuery(coll, "$nin (not in list)",
    new BsonDocument("city", new BsonDocument("$nin", new BsonArray { "New York", "Los Angeles" })));
await RunQuery(coll, "Nested $eq on profile.city",
    new BsonDocument("profile.city", new BsonDocument("$eq", "New York")));
await RunQuery(coll, "Nested $gte on profile.experience",
    new BsonDocument("profile.experience", new BsonDocument("$gte", 10)));
await RunQuery(coll, "Nested $in on profile.role",
    new BsonDocument("profile.role", new BsonDocument("$in", new BsonArray { "developer", "architect" })));

return;

static string Pretty(List<BsonDocument> docs)
{
    if (docs.Count == 0) return "[]";
    static string Rd(BsonDocument? d, string k) =>
        d?.Contains(k) == true ? d[k].IsBsonNull ? "" : d[k].ToString()!.Trim('"') : "";
    var rows = docs.Select(d =>
    {
        var profile = d["profile"].AsBsonDocument;
        return $"{Rd(d, "name")} (age={Rd(d, "age")}, city={Rd(d, "city")}, " +
               $"profile.city={Rd(profile, "city")}, profile.experience={Rd(profile, "experience")})";
    });
    return "[" + string.Join(", ", rows) + "]";
}

static async Task RunQuery(IMongoCollection<BsonDocument> coll, string label, BsonDocument query)
{
    var cursor = coll.Find(query).Sort(new BsonDocument("name", 1)).Project(Builders<BsonDocument>.Projection.Exclude("_id"));
    var docs = await cursor.ToListAsync();
    Console.WriteLine($"{label}");
    Console.WriteLine($"  query={query}");
    Console.WriteLine($"  count={docs.Count}");
    Console.WriteLine($"  docs={Pretty(docs)}\n");
}
