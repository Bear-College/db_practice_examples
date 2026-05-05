// Mirrors 10_odm/example.py — BSON documents (MongoEngine-style workflow analogue).
// Writes to collection odm_products.

using MongoDB.Bson;
using MongoDB.Driver;

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "odm_products";

var coll = new MongoClient(mongoUri).GetDatabase(dbName).GetCollection<BsonDocument>(collectionName);

Console.WriteLine($"Mongo URI: {mongoUri}");
Console.WriteLine($"Database:  {dbName}");

await coll.Database.DropCollectionAsync(collectionName);

await coll.InsertOneAsync(MkProduct("iPhone 14", "Smartphone", 899));
await coll.InsertManyAsync([
    MkProduct("MacBook Air", "Laptop", 1299),
    MkProduct("Galaxy S23", "Smartphone", 799),
]);

await PrintAll(coll, "All products");

var smartphones = await coll.Find(new BsonDocument("category", "Smartphone"))
    .Sort(new BsonDocument("price", -1)).Project(Builders<BsonDocument>.Projection.Exclude("_id")).ToListAsync();
Console.WriteLine($"\nSmartphones count: {smartphones.Count}");
foreach (var d in smartphones)
    Console.WriteLine($"  {d["name"].ToString()!.Trim('"')} | {d["price"]}");

await coll.UpdateOneAsync(
    new BsonDocument("name", "iPhone 14"),
    new BsonDocument("$set", new BsonDocument("price", 849)));
var iphone = await coll.Find(new BsonDocument("name", "iPhone 14")).FirstAsync();
Console.WriteLine($"\nUpdated iPhone 14 price: {iphone["price"]}");

await coll.DeleteOneAsync(new BsonDocument("name", "Galaxy S23"));
Console.WriteLine($"Remaining after delete: {await coll.CountDocumentsAsync(Builders<BsonDocument>.Filter.Empty)}");

return;

static BsonDocument MkProduct(string name, string category, int price) =>
    new() {
        ["name"] = name,
        ["category"] = category,
        ["price"] = price,
        ["created_at"] = DateTime.UtcNow,
    };

static async Task PrintAll(IMongoCollection<BsonDocument> coll, string title)
{
    var allDocs = await coll.Find(Builders<BsonDocument>.Filter.Empty)
        .Sort(new BsonDocument("name", 1)).Project(Builders<BsonDocument>.Projection.Exclude("_id")).ToListAsync();
    Console.WriteLine($"{title} count: {allDocs.Count}");
    foreach (var d in allDocs)
        Console.WriteLine($"  {d["name"].ToString()!.Trim('"')} | {d["category"].ToString()!.Trim('"')} | {d["price"]}");
}
