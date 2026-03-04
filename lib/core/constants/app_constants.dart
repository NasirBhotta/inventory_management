abstract class AppConstants {
  static const String appName = 'FertiTrack';
  static const String appVersion = '1.0.0';
  static const String dbName = 'inventory.db';
  static const int dbVersion = 1;
  static const String backupFolder = 'backups';
  static const String currency = 'PKR';
}

abstract class TableNames {
  static const products = 'products';
  static const sales = 'sales';
  static const saleItems = 'sale_items';
  static const stock = 'stock_movements';
}

abstract class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0; // ← this one
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}
