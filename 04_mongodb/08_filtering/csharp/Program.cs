// Mirrors 08_filtering/example.py — combined filter patterns.

using MongoDB.Bson;
using MongoDB.Driver;

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "filtering_people";

var coll = new MongoClient(mongoUri).GetDatabase(dbName).GetCollection<BsonDocument>(collectionName);

Console.WriteLine($"Mongo URI: {mongoUri}");
Console.WriteLine($"Database:  {dbName}");
Console.WriteLine($"Collection:{collectionName}\n");

await coll.DeleteManyAsync(new BsonDocument());
await coll.InsertManyAsync([
    Mk("Anna", 17, "Chicago", "anna@gmail.com", "+1-202-555-0101", 1,
        new[] { "Python", "JavaScript", "SQL" }, (("math", 95), ("history", 88))),
    Mk("Bohdan", 18, "New York", "bohdan@outlook.com", null, 2,
        new[] { "Python", "Go" }, (("math", 89), ("physics", 91))),
    Mk("Chris", 25, "Los Angeles", "chris@gmail.com", "+1-202-555-0102", 4,
        new[] { "JavaScript", "TypeScript", "Node.js" }, (("math", 78), ("biology", 84))),
    Mk("Daria", 30, "Kyiv", "daria@yahoo.com", "+380-44-555-0103", 7,
        new[] { "Python", "JavaScript" }, (("math", 92), ("chemistry", 94))),
    Mk("Emma", 45, "New York", "emma@gmail.com", "+1-202-555-0104", 15,
        new[] { "Python", "Architecture", "Leadership" }, (("math", 90), ("management", 99))),
]);

var allDocs = await coll.Find(new BsonDocument()).Sort(new BsonDocument("name", 1))
    .Project(Builders<BsonDocument>.Projection.Include("name")).ToListAsync();
Console.WriteLine($"find() all documents\n  count={allDocs.Count}\n  names={ShortDocs(allDocs)}\n");

var one = await coll.Find(new BsonDocument("name", "Anna")).Project(Builders<BsonDocument>.Projection.Exclude("_id")).FirstOrDefaultAsync();
Console.WriteLine($"find_one() by name=Anna\n  doc={one?.ToJson() ?? "null"}\n");

await Run(coll, "Comparison: age > 25", new BsonDocument("age", new BsonDocument("$gt", 25)));
await Run(coll, "Comparison: age <= 30", new BsonDocument("age", new BsonDocument("$lte", 30)));
await Run(coll, "$in: city in [New York, Los Angeles]",
    new BsonDocument("city", new BsonDocument("$in", new BsonArray { "New York", "Los Angeles" })));
await Run(coll, "$nin: city not in [New York, Los Angeles]",
    new BsonDocument("city", new BsonDocument("$nin", new BsonArray { "New York", "Los Angeles" })));

await Run(coll, "$and: age >= 18 AND city=New York", new BsonDocument("$and", new BsonArray
{
    new BsonDocument("age", new BsonDocument("$gte", 18)),
    new BsonDocument("city", "New York"),
}));
await Run(coll, "$or: age < 18 OR age > 40", new BsonDocument("$or", new BsonArray
{
    new BsonDocument("age", new BsonDocument("$lt", 18)),
    new BsonDocument("age", new BsonDocument("$gt", 40)),
}));
await Run(coll, "$not: age NOT >= 18", new BsonDocument("age", new BsonDocument("$not", new BsonDocument("$gte", 18))));

await Run(coll, "Nested: profile.city = New York", new BsonDocument("profile.city", "New York"));
await Run(coll, "Nested: profile.experience >= 10", new BsonDocument("profile.experience", new BsonDocument("$gte", 10)));

await Run(coll, "Array $all: skills has Python + JavaScript",
    new BsonDocument("skills", new BsonDocument("$all", new BsonArray { "Python", "JavaScript" })));
await Run(coll, "Array $size: skills length = 3", new BsonDocument("skills", new BsonDocument("$size", 3)));
await Run(coll, "Array $elemMatch: grades.score > 90",
    new BsonDocument("grades", new BsonDocument("$elemMatch", new BsonDocument("score", new BsonDocument("$gt", 90)))));
await Run(coll, "Regex: email ends with @gmail.com",
    new BsonDocument("email", new BsonDocument("$regex", "@gmail.com$")));
await Run(coll, "$exists: has phone field", new BsonDocument("phone", new BsonDocument("$exists", true)));
await Run(coll, "$exists: phone field is missing", new BsonDocument("phone", new BsonDocument("$exists", false)));

return;

static BsonDocument Mk(string name, int age, string city, string email, string? phone, int experience,
    string[] skills, ((string subject, int score) a, (string subject, int score) b) grades)
{
    var doc = new BsonDocument {
        ["name"] = name, ["age"] = age, ["city"] = city, ["email"] = email,
        ["profile"] = new BsonDocument { ["city"] = city, ["experience"] = experience },
        ["skills"] = new BsonArray(skills),
        ["grades"] = new BsonArray {
            new BsonDocument { ["subject"] = grades.a.subject, ["score"] = grades.a.score },
            new BsonDocument { ["subject"] = grades.b.subject, ["score"] = grades.b.score },
        },
    };
    if (phone != null)
        doc["phone"] = phone;
    return doc;
}

static string ShortDocs(List<BsonDocument> docs)
{
    if (docs.Count == 0) return "[]";
    return "[" + string.Join(", ",
        docs.Select(d => d.Contains("name") ? d["name"].ToString()!.Trim('"') : "?")) + "]";
}

static async Task Run(IMongoCollection<BsonDocument> coll, string title, BsonDocument query)
{
    var docs = await coll.Find(query).Sort(new BsonDocument("name", 1))
        .Project(Builders<BsonDocument>.Projection.Include("name")).ToListAsync();
    Console.WriteLine($"{title}");
    Console.WriteLine($"  query={query}");
    Console.WriteLine($"  count={docs.Count}");
    Console.WriteLine($"  names={ShortDocs(docs)}\n");
}
