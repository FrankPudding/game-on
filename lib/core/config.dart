enum DataSourceType {
  hive,
  mock,
}

class AppConfig {
  AppConfig({
    this.dataSourceType = DataSourceType.hive,
  });
  final DataSourceType dataSourceType;

  // You can add more configuration fields here, like API endpoints, etc.
}
