/// The aggregate records a business operation is allowed to edit.
class MenuWriteScope {
  const MenuWriteScope({
    this.recipeIds = const {},
    this.restaurantIds = const {},
    this.allRecipes = false,
    this.allRestaurants = false,
  }) : _recipe = null,
       _restaurant = null;
  const MenuWriteScope.recipe(String id)
    : recipeIds = const {},
      restaurantIds = const {},
      allRecipes = false,
      allRestaurants = false,
      _recipe = id,
      _restaurant = null;
  const MenuWriteScope.restaurant(String id)
    : recipeIds = const {},
      restaurantIds = const {},
      allRecipes = false,
      allRestaurants = false,
      _restaurant = id,
      _recipe = null;
  final Set<String> recipeIds;
  final Set<String> restaurantIds;
  final bool allRecipes, allRestaurants;
  final String? _recipe, _restaurant;
  Set<String> get recipes => {...recipeIds, ?_recipe};
  Set<String> get restaurants => {...restaurantIds, ?_restaurant};
  static const settings = MenuWriteScope();
  static const recipesAll = MenuWriteScope(allRecipes: true);
  static const restaurantsAll = MenuWriteScope(allRestaurants: true);
  static const all = MenuWriteScope(allRecipes: true, allRestaurants: true);
}
