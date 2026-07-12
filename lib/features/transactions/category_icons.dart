import 'package:flutter/material.dart';

IconData categoryIconData(String categoryId) {
  return switch (categoryId) {
    'food' => Icons.restaurant_rounded,
    'drink' => Icons.local_cafe_rounded,
    'groceries' => Icons.local_grocery_store_rounded,
    'transport' => Icons.directions_bus_rounded,
    'shopping' => Icons.shopping_bag_rounded,
    'bills' => Icons.receipt_long_rounded,
    'rent' => Icons.home_work_rounded,
    'health' => Icons.favorite_rounded,
    'education' => Icons.school_rounded,
    'entertainment' => Icons.movie_rounded,
    'travel' => Icons.flight_takeoff_rounded,
    'family' => Icons.family_restroom_rounded,
    'insurance' => Icons.verified_user_rounded,
    'tax' => Icons.account_balance_rounded,
    'donation' => Icons.volunteer_activism_rounded,
    'transfer' => Icons.sync_alt_rounded,
    'internal_transfer' => Icons.sync_alt_rounded,
    'salary' => Icons.payments_rounded,
    'side_job' => Icons.work_history_rounded,
    'business' => Icons.storefront_rounded,
    'bonus' => Icons.redeem_rounded,
    'investment' => Icons.trending_up_rounded,
    'interest' => Icons.savings_rounded,
    'sale' => Icons.sell_rounded,
    'allowance' => Icons.wallet_rounded,
    'gift' => Icons.card_giftcard_rounded,
    'refund' => Icons.assignment_return_rounded,
    _ => Icons.category_rounded,
  };
}
