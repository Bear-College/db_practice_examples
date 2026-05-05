// Mirrors 10_odm/01_selection_operators/example.py (MongoEngine queries -> BSON filters).

using MongoDB.Bson;
using MongoDB.Driver;

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "odm_selection_operators_people";

var coll = new MongoClient(mongoUri).GetDatabase(dbName).GetCollection<BsonDocument>(collectionName);

await coll.Database.DropCollectionAsync(collectionName);

await coll.InsertManyAsync([
    new() { ["name"] = "Vlad", ["age"] = 25, ["status"] = "active", ["active"] = true, ["email"] = "vlad@gmail.com" },
    new() { ["name"] = "Anna", ["age"] = 30, ["status"] = "pending", ["active"] = true },
    new() { ["name"] = "Bohdan", ["age"] = 17, ["status"] = "deleted", ["active"] = false, ["email"] = "bohdan@example.com" },
    new() { ["name"] = "Chris", ["age"] = 19, ["status"] = "active", ["active"] = true, ["email"] = "chris@gmail.com" },
    new() { ["name"] = "Daria", ["age"] = 65, ["status"] = "pending", ["active"] = false },
]);

await PrintResult(coll, "$eq   age=25", new BsonDocument("age", 25));
await PrintResult(coll, "$ne   age!=30", new BsonDocument("age", new BsonDocument("$ne", 30)));
await PrintResult(coll, "$gt   age>18", new BsonDocument("age", new BsonDocument("$gt", 18)));
await PrintResult(coll, "$gte  age>=18", new BsonDocument("age", new BsonDocument("$gte", 18)));
await PrintResult(coll, "$lt   age<65", new BsonDocument("age", new BsonDocument("$lt", 65)));
await PrintResult(coll, "$lte  age<=65", new BsonDocument("age", new BsonDocument("$lte", 65)));
await PrintResult(coll, "$in   status in [active,pending]",
    new BsonDocument("status", new BsonDocument("$in", new BsonArray { "active", "pending" })));
await PrintResult(coll, "$nin  status not in [deleted]",
    new BsonDocument("status", new BsonDocument("$nin", new BsonArray { "deleted" })));

await PrintResult(coll, "$and  age>18 AND active=True",
    new BsonDocument("$and", new BsonArray
    {
        new BsonDocument("age", new BsonDocument("$gt", 18)),
        new BsonDocument("active", true),
    }));
await PrintResult(coll, "$or   age<18 OR active=False",
    new BsonDocument("$or", new BsonArray
    {
        new BsonDocument("age", new BsonDocument("$lt", 18)),
        new BsonDocument("active", false),
    }));
await PrintResult(coll, "$not  NOT(age<18)",
    new BsonDocument("age", new BsonDocument("$not", new BsonDocument("$lt", 18))));

await PrintResult(coll, "$exists email exists", new BsonDocument("email", new BsonDocument("$exists", true)));
await PrintResult(coll, "$regex name starts with Vlad",
    new BsonDocument("name", new BsonDocument("$regex", "^Vlad")));

return;

static async Task PrintResult(IMongoCollection<BsonDocument> coll, string label, BsonDocument query)
{
    var names = await coll.Find(query).Sort(new BsonDocument("name", 1))
        .Project(Builders<BsonDocument>.Projection.Include("name")).ToListAsync();
    var list = names.Select(d => d["name"].AsString).ToList();
    Console.WriteLine($"{label}: count={list.Count} -> [{string.Join(", ", list)}]");
}
