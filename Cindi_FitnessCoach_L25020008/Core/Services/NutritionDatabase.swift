import Foundation

/// One food in the local nutrition table (values per 100 g + a typical serving size).
struct FoodItem {
    let name: String
    let kcalPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let servingGrams: Double
    /// Lowercased match tokens (include singular + plural).
    let keywords: [String]
}

/// A single parsed lookup result, scaled to the requested amount.
struct FoodResult: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let grams: Double
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

/// A fully local stand-in for an online calorie/nutrition API (e.g. API Ninjas): the user
/// types a free-text food query and gets calories + macros, parsed and scaled by quantity.
/// No network, no API key — the data ships in the app.
enum NutritionDatabase {
    static let foods: [FoodItem] = [
        FoodItem(name: "Egg", kcalPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11, servingGrams: 50, keywords: ["egg", "eggs"]),
        FoodItem(name: "Chicken breast", kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6, servingGrams: 120, keywords: ["chicken breast", "chicken", "chicken breasts"]),
        FoodItem(name: "White rice (cooked)", kcalPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, servingGrams: 150, keywords: ["white rice", "rice", "cooked rice"]),
        FoodItem(name: "Brown rice (cooked)", kcalPer100g: 123, proteinPer100g: 2.7, carbsPer100g: 26, fatPer100g: 1, servingGrams: 150, keywords: ["brown rice"]),
        FoodItem(name: "White bread", kcalPer100g: 265, proteinPer100g: 9, carbsPer100g: 49, fatPer100g: 3.2, servingGrams: 30, keywords: ["white bread", "bread", "toast"]),
        FoodItem(name: "Banana", kcalPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, servingGrams: 118, keywords: ["banana", "bananas"]),
        FoodItem(name: "Apple", kcalPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, servingGrams: 180, keywords: ["apple", "apples"]),
        FoodItem(name: "Orange", kcalPer100g: 47, proteinPer100g: 0.9, carbsPer100g: 12, fatPer100g: 0.1, servingGrams: 130, keywords: ["orange", "oranges"]),
        FoodItem(name: "Whole milk", kcalPer100g: 61, proteinPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 3.3, servingGrams: 240, keywords: ["whole milk", "milk"]),
        FoodItem(name: "Oats (dry)", kcalPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7, servingGrams: 40, keywords: ["oats", "oatmeal", "oat"]),
        FoodItem(name: "Salmon (cooked)", kcalPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13, servingGrams: 120, keywords: ["salmon"]),
        FoodItem(name: "Beef (lean, cooked)", kcalPer100g: 250, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 15, servingGrams: 120, keywords: ["beef", "steak"]),
        FoodItem(name: "Potato (boiled)", kcalPer100g: 87, proteinPer100g: 1.9, carbsPer100g: 20, fatPer100g: 0.1, servingGrams: 150, keywords: ["potato", "potatoes"]),
        FoodItem(name: "Sweet potato", kcalPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20, fatPer100g: 0.1, servingGrams: 150, keywords: ["sweet potato", "sweet potatoes"]),
        FoodItem(name: "Pasta (cooked)", kcalPer100g: 158, proteinPer100g: 5.8, carbsPer100g: 31, fatPer100g: 0.9, servingGrams: 150, keywords: ["pasta", "spaghetti", "noodles"]),
        FoodItem(name: "Broccoli", kcalPer100g: 34, proteinPer100g: 2.8, carbsPer100g: 7, fatPer100g: 0.4, servingGrams: 100, keywords: ["broccoli"]),
        FoodItem(name: "Almonds", kcalPer100g: 579, proteinPer100g: 21, carbsPer100g: 22, fatPer100g: 49, servingGrams: 28, keywords: ["almonds", "almond"]),
        FoodItem(name: "Peanut butter", kcalPer100g: 588, proteinPer100g: 25, carbsPer100g: 20, fatPer100g: 50, servingGrams: 32, keywords: ["peanut butter"]),
        FoodItem(name: "Greek yogurt", kcalPer100g: 59, proteinPer100g: 10, carbsPer100g: 3.6, fatPer100g: 0.4, servingGrams: 170, keywords: ["greek yogurt", "yogurt", "yoghurt"]),
        FoodItem(name: "Cheddar cheese", kcalPer100g: 403, proteinPer100g: 25, carbsPer100g: 1.3, fatPer100g: 33, servingGrams: 30, keywords: ["cheddar", "cheese"]),
        FoodItem(name: "Avocado", kcalPer100g: 160, proteinPer100g: 2, carbsPer100g: 9, fatPer100g: 15, servingGrams: 100, keywords: ["avocado", "avocados"]),
        FoodItem(name: "Tofu", kcalPer100g: 76, proteinPer100g: 8, carbsPer100g: 1.9, fatPer100g: 4.8, servingGrams: 100, keywords: ["tofu"]),
        FoodItem(name: "Tuna (canned)", kcalPer100g: 132, proteinPer100g: 28, carbsPer100g: 0, fatPer100g: 1, servingGrams: 100, keywords: ["tuna"]),
        FoodItem(name: "Shrimp (cooked)", kcalPer100g: 99, proteinPer100g: 24, carbsPer100g: 0.2, fatPer100g: 0.3, servingGrams: 85, keywords: ["shrimp", "prawn", "prawns"]),
        FoodItem(name: "Pork (cooked)", kcalPer100g: 242, proteinPer100g: 27, carbsPer100g: 0, fatPer100g: 14, servingGrams: 120, keywords: ["pork"]),
        FoodItem(name: "Lentils (cooked)", kcalPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0.4, servingGrams: 150, keywords: ["lentils", "lentil", "dal"]),
        FoodItem(name: "Black beans (cooked)", kcalPer100g: 132, proteinPer100g: 8.9, carbsPer100g: 24, fatPer100g: 0.5, servingGrams: 150, keywords: ["black beans", "beans"]),
        FoodItem(name: "Chocolate", kcalPer100g: 546, proteinPer100g: 4.9, carbsPer100g: 61, fatPer100g: 31, servingGrams: 25, keywords: ["chocolate"]),
        FoodItem(name: "Pizza", kcalPer100g: 266, proteinPer100g: 11, carbsPer100g: 33, fatPer100g: 10, servingGrams: 107, keywords: ["pizza"]),
        FoodItem(name: "Burger", kcalPer100g: 295, proteinPer100g: 17, carbsPer100g: 24, fatPer100g: 14, servingGrams: 150, keywords: ["burger", "hamburger", "cheeseburger"]),
        FoodItem(name: "French fries", kcalPer100g: 312, proteinPer100g: 3.4, carbsPer100g: 41, fatPer100g: 15, servingGrams: 117, keywords: ["fries", "french fries", "chips"]),
        FoodItem(name: "Coffee (black)", kcalPer100g: 1, proteinPer100g: 0.1, carbsPer100g: 0, fatPer100g: 0, servingGrams: 240, keywords: ["coffee", "black coffee"]),
        FoodItem(name: "Orange juice", kcalPer100g: 45, proteinPer100g: 0.7, carbsPer100g: 10, fatPer100g: 0.2, servingGrams: 240, keywords: ["orange juice", "juice"])
    ]

    /// Parses a free-text query (e.g. "2 eggs, 100g rice and 1 banana") into nutrition results.
    static func lookup(_ query: String) -> [FoodResult] {
        query
            .lowercased()
            .replacingOccurrences(of: " and ", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap(parseSegment)
    }

    private static func parseSegment(_ segment: String) -> FoodResult? {
        var quantity: Double = 1
        var explicitGrams: Double?
        var tokens = segment.split(separator: " ").map(String.init)

        // Leading number → quantity or grams (when followed by a weight unit).
        if let first = tokens.first, let number = parseNumber(first) {
            tokens.removeFirst()
            if let unit = tokens.first?.lowercased() {
                if ["g", "gram", "grams", "gr"].contains(unit) {
                    explicitGrams = number
                    tokens.removeFirst()
                } else if ["kg", "kilogram", "kilograms"].contains(unit) {
                    explicitGrams = number * 1000
                    tokens.removeFirst()
                } else {
                    quantity = number
                }
            } else {
                quantity = number
            }
        }

        let name = tokens.joined(separator: " ")
        guard let food = match(name) else { return nil }

        let grams = explicitGrams ?? (quantity * food.servingGrams)
        let factor = grams / 100.0
        return FoodResult(
            name: food.name,
            grams: (grams).rounded(),
            calories: (food.kcalPer100g * factor).rounded(),
            protein: ((food.proteinPer100g * factor) * 10).rounded() / 10,
            carbs: ((food.carbsPer100g * factor) * 10).rounded() / 10,
            fat: ((food.fatPer100g * factor) * 10).rounded() / 10
        )
    }

    private static func parseNumber(_ string: String) -> Double? {
        Double(string.replacingOccurrences(of: ",", with: "."))
    }

    /// Finds the food whose longest keyword appears in (or contains) the query text.
    private static func match(_ text: String) -> FoodItem? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }

        var best: (food: FoodItem, score: Int)?
        for food in foods {
            for keyword in food.keywords where cleaned.contains(keyword) || keyword.contains(cleaned) {
                if best == nil || keyword.count > best!.score {
                    best = (food, keyword.count)
                }
            }
        }
        return best?.food
    }
}
