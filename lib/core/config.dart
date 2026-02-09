enum DataSourceType {
  hive,
  mock,
}

class AppConfig {
  final DataSourceType dataSourceType;

  AppConfig({
    this.dataSourceType = DataSourceType.hive,
  });

  // You can add more configuration fields here, like API endpoints, etc.
}
