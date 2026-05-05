// Mirrors 01_crud/example.py — CRUD + collection cleanup + drop.
// env: MONGODB_URI (default mongodb://localhost:27017), MONGODB_DB (default edu_academy_seed)

using MongoDB.Bson;
using MongoDB.Driver;

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "products";

var client = new MongoClient(mongoUri);
var db = client.GetDatabase(dbName);
var products = db.GetCollection<BsonDocument>(collectionName);

Console.WriteLine($"Mongo URI: {mongoUri}");
Console.WriteLine($"Database:  {dbName}");
Console.WriteLine($"Collection:{collectionName}");

await products.DeleteManyAsync(new BsonDocument());

await products.InsertOneAsync(Mk("iPhone 14", "Phone", 999));

await products.InsertManyAsync([
    Mk("Galaxy S23", "Phone", 899),
    Mk("MacBook Air", "Laptop", 1299),
    Mk("Pixel 8", "Phone", 799),
]);

PrintDocs("After INSERT operations:",
    await products.Find(new BsonDocument()).Sort(new BsonDocument("name", 1))
        .Project(Builders<BsonDocument>.Projection.Exclude("_id")).ToListAsync());

var oneResult = await products.UpdateOneAsync(
    new BsonDocument("name", "iPhone 14"),
    new BsonDocument("$set", new BsonDocument("price", 899)));
Console.WriteLine($"\nupdate_one matched={oneResult.MatchedCount}, modified={oneResult.ModifiedCount}");

var manyResult = await products.UpdateManyAsync(
    new BsonDocument("category", "Phone"),
    new BsonDocument("$set", new BsonDocument("category", "Smartphone")));
Console.WriteLine($"update_many matched={manyResult.MatchedCount}, modified={manyResult.ModifiedCount}");

PrintDocs("After UPDATE operations:",
    await products.Find(new BsonDocument()).Sort(new BsonDocument("name", 1))
        .Project(Builders<BsonDocument>.Projection.Exclude("_id")).ToListAsync());

var delOne = await products.DeleteOneAsync(new BsonDocument("name", "iPhone 14"));
Console.WriteLine($"\ndelete_one deleted={delOne.DeletedCount}");

var delManyFiltered = await products.DeleteManyAsync(new BsonDocument("category", "Smartphone"));
Console.WriteLine($"delete_many(category=Smartphone) deleted={delManyFiltered.DeletedCount}");

PrintDocs("After DELETE (filtered) operations:",
    await products.Find(new BsonDocument()).Sort(new BsonDocument("name", 1))
        .Project(Builders<BsonDocument>.Projection.Exclude("_id")).ToListAsync());

var cleared = await products.DeleteManyAsync(new BsonDocument());
Console.WriteLine($"\ndelete_many({{}}) deleted={cleared.DeletedCount}");
Console.WriteLine($"Remaining docs in collection: {await products.CountDocumentsAsync(Builders<BsonDocument>.Filter.Empty)}");

await db.DropCollectionAsync(collectionName);
var names = await db.ListCollectionNames().ToListAsync();
Console.WriteLine($"Collection exists after drop: {names.Contains(collectionName)}");

return;

static BsonDocument Mk(string name, string category, int price) =>
    new() { ["name"] = name, ["category"] = category, ["price"] = price };

static void PrintDocs(string title, List<BsonDocument> docs)
{
    Console.WriteLine($"\n{title}");
    if (docs.Count == 0)
    {
        Console.WriteLine("  (no documents)");
        return;
    }
    foreach (var doc in docs)
        Console.WriteLine(
            $"  name={doc["name"]}, category={doc["category"]}, price={doc["price"]}");
}
