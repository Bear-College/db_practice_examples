// Mirrors 06_array_operators/example.py ($all, $size, $elemMatch)

using MongoDB.Bson;
using MongoDB.Driver;

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "array_operators_people";

var coll = new MongoClient(mongoUri).GetDatabase(dbName).GetCollection<BsonDocument>(collectionName);

Console.WriteLine($"Mongo URI: {mongoUri}");
Console.WriteLine($"Database:  {dbName}");
Console.WriteLine($"Collection:{collectionName}\n");

await coll.DeleteManyAsync(new BsonDocument());
await coll.InsertManyAsync([
    new BsonDocument {
        ["name"] = "Anna",
        ["skills"] = new BsonArray { "Python", "JavaScript", "SQL" },
        ["grades"] = new BsonArray {
            new BsonDocument { ["subject"] = "math", ["score"] = 95 },
            new BsonDocument { ["subject"] = "history", ["score"] = 88 },
        },
    },
    new BsonDocument {
        ["name"] = "Bohdan",
        ["skills"] = new BsonArray { "Python", "Go" },
        ["grades"] = new BsonArray {
            new BsonDocument { ["subject"] = "math", ["score"] = 89 },
            new BsonDocument { ["subject"] = "physics", ["score"] = 91 },
        },
    },
    new BsonDocument {
        ["name"] = "Chris",
        ["skills"] = new BsonArray { "JavaScript", "TypeScript", "Node.js" },
        ["grades"] = new BsonArray {
            new BsonDocument { ["subject"] = "math", ["score"] = 78 },
            new BsonDocument { ["subject"] = "biology", ["score"] = 84 },
        },
    },
    new BsonDocument {
        ["name"] = "Daria",
        ["skills"] = new BsonArray { "Python", "JavaScript" },
        ["grades"] = new BsonArray {
            new BsonDocument { ["subject"] = "math", ["score"] = 92 },
            new BsonDocument { ["subject"] = "chemistry", ["score"] = 94 },
        },
    },
]);

await RunQuery(coll, "$all (array contains all values)",
    new BsonDocument("skills", new BsonDocument("$all", new BsonArray { "Python", "JavaScript" })));
await RunQuery(coll, "$size (array length equals 3)",
    new BsonDocument("skills", new BsonDocument("$size", 3)));
await RunQuery(coll, "$elemMatch (array has element matching condition)",
    new BsonDocument("grades", new BsonDocument("$elemMatch", new BsonDocument("score", new BsonDocument("$gt", 90)))));

return;

static string Pretty(List<BsonDocument> docs)
{
    if (docs.Count == 0) return "[]";
    return "[" + string.Join(", ", docs.Select(Summarize)) + "]";
}

static string Summarize(BsonDocument d)
{
    var skills = string.Join(",", d["skills"].AsBsonArray.Select(x => x.ToString()!.Trim('"')));
    var grades = string.Join(",", d["grades"].AsBsonArray.Select(g =>
        g.AsBsonDocument["subject"].ToString()!.Trim('"') + "=" + g.AsBsonDocument["score"].ToString()));
    return $"{d["name"].ToString()!.Trim('"')} (skills=[{skills}], grades=[{grades}])";
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
