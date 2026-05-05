// Mirrors 07_pagination_sorting/example.py

using MongoDB.Bson;
using MongoDB.Driver;

var mongoUri = Environment.GetEnvironmentVariable("MONGODB_URI") ?? "mongodb://localhost:27017";
var dbName = Environment.GetEnvironmentVariable("MONGODB_DB") ?? "edu_academy_seed";
const string collectionName = "pagination_sorting_products";

var coll = new MongoClient(mongoUri).GetDatabase(dbName).GetCollection<BsonDocument>(collectionName);

Console.WriteLine($"Mongo URI: {mongoUri}");
Console.WriteLine($"Database:  {dbName}");
Console.WriteLine($"Collection:{collectionName}");

await coll.DeleteManyAsync(new BsonDocument());
await coll.InsertManyAsync([
    new() { ["name"] = "iPhone 14", ["category"] = "Smartphone", ["price"] = 899, ["rating"] = 4.8 },
    new() { ["name"] = "Galaxy S23", ["category"] = "Smartphone", ["price"] = 799, ["rating"] = 4.7 },
    new() { ["name"] = "Pixel 8", ["category"] = "Smartphone", ["price"] = 699, ["rating"] = 4.6 },
    new() { ["name"] = "MacBook Air", ["category"] = "Laptop", ["price"] = 1299, ["rating"] = 4.9 },
    new() { ["name"] = "ThinkPad X1", ["category"] = "Laptop", ["price"] = 1399, ["rating"] = 4.8 },
    new() { ["name"] = "iPad Pro", ["category"] = "Tablet", ["price"] = 999, ["rating"] = 4.7 },
    new() { ["name"] = "Kindle Paperwhite", ["category"] = "Tablet", ["price"] = 159, ["rating"] = 4.5 },
    new() { ["name"] = "Sony WH-1000XM5", ["category"] = "Audio", ["price"] = 399, ["rating"] = 4.8 },
    new() { ["name"] = "AirPods Pro", ["category"] = "Audio", ["price"] = 249, ["rating"] = 4.6 },
    new() { ["name"] = "Logitech MX Master 3S", ["category"] = "Accessories", ["price"] = 99, ["rating"] = 4.9 },
]);

PrintRows("Sorted by price ASC", await FetchSorted(coll, new BsonDocument("price", 1)));
PrintRows("Sorted by rating DESC, then price ASC",
    await FetchSorted(coll, new BsonDocument { ["rating"] = -1, ["price"] = 1 }));

const int pageSize = 3;
var page1 = await FetchPage(coll, page: 1, perPage: pageSize, new BsonDocument("name", 1));
var page2 = await FetchPage(coll, page: 2, perPage: pageSize, new BsonDocument("name", 1));
var page3 = await FetchPage(coll, page: 3, perPage: pageSize, new BsonDocument("name", 1));
PrintRows($"Page 1 (size={pageSize}, sort=name ASC)", page1);
PrintRows($"Page 2 (size={pageSize}, sort=name ASC)", page2);
PrintRows($"Page 3 (size={pageSize}, sort=name ASC)", page3);

Console.WriteLine($"\nTotal documents: {await coll.CountDocumentsAsync(Builders<BsonDocument>.Filter.Empty)}");

return;

static async Task<List<BsonDocument>> FetchSorted(IMongoCollection<BsonDocument> coll, BsonDocument sortKeys) =>
    await coll.Find(Builders<BsonDocument>.Filter.Empty)
        .Sort(sortKeys).Project(Builders<BsonDocument>.Projection.Exclude("_id")).ToListAsync();

static async Task<List<BsonDocument>> FetchPage(IMongoCollection<BsonDocument> coll, int page, int perPage, BsonDocument sortKeys)
{
    if (page < 1)
        throw new ArgumentException("page must be >= 1", nameof(page));
    var skip = (page - 1) * perPage;
    return await coll.Find(Builders<BsonDocument>.Filter.Empty)
        .Sort(sortKeys)
        .Skip(skip)
        .Limit(perPage)
        .Project(Builders<BsonDocument>.Projection.Exclude("_id"))
        .ToListAsync();
}

static void PrintRows(string title, List<BsonDocument> docs)
{
    Console.WriteLine($"\n{title}");
    if (docs.Count == 0)
    {
        Console.WriteLine("  (no documents)");
        return;
    }
    foreach (var d in docs)
        Console.WriteLine(
            $"  name={d["name"].ToString()!.Trim('"')}, category={d["category"].ToString()!.Trim('"')}, " +
            $"price={d["price"]}, rating={d["rating"]}");
}
