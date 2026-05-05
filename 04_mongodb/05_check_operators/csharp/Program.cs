// Mirrors 05_check_operators/example.py ($exists, $type)

using MongoDB.Bson;
using MongoDB.Driver;

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "check_operators_people";

var coll = new MongoClient(mongoUri).GetDatabase(dbName).GetCollection<BsonDocument>(collectionName);

Console.WriteLine($"Mongo URI: {mongoUri}");
Console.WriteLine($"Database:  {dbName}");
Console.WriteLine($"Collection:{collectionName}\n");

await coll.DeleteManyAsync(new BsonDocument());
await coll.InsertManyAsync([
    new BsonDocument { ["name"] = "Anna", ["age"] = 17, ["phone"] = "+1-202-555-0101" },
    new BsonDocument { ["name"] = "Bohdan", ["age"] = 18 },
    new BsonDocument { ["name"] = "Chris", ["age"] = 25, ["phone"] = "+1-202-555-0102" },
    new BsonDocument { ["name"] = "Daria", ["age"] = 30.5, ["phone"] = "+380-44-555-0103" },
    new BsonDocument { ["name"] = "Emma", ["age"] = "45", ["phone"] = "+1-202-555-0104" },
]);

await RunQuery(coll, "$exists (field exists)", new BsonDocument("phone", new BsonDocument("$exists", true)));
await RunQuery(coll, "$type (field type is int)", new BsonDocument("age", new BsonDocument("$type", "int")));

return;

static string Pretty(List<BsonDocument> docs)
{
    if (docs.Count == 0) return "[]";
    static string N(BsonDocument d, string k) => d.GetValue(k, BsonNull.Value).IsBsonNull ? "N/A" : d[k].ToString()!.Trim('"');
    return "[" + string.Join(", ",
        docs.Select(d =>
        {
            var age = d.Contains("age") ? d["age"] : BsonNull.Value;
            var ageType = age.IsBsonNull ? "null" :
                age.IsInt32 ? "int" :
                age.IsInt64 ? "long" :
                age.IsDouble ? "float" :
                age.IsString ? "str" : age.BsonType.ToString().ToLowerInvariant();
            return $"{d["name"].ToString()!.Trim('"')} (age={N(d, "age")}, phone={N(d, "phone")}, age_type={ageType})";
        })) + "]";
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
