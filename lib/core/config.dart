enum DataSourceType {
  hive,
  mock,
}

class AppConfig {
  AppConfig({
    this.dataSourceType = DataSourceType.hive,
    this.hiveDbVersion = 3,
  });
  final DataSourceType dataSourceType;
  final int hiveDbVersion;

  // You can add more configuration fields here, like API endpoints, etc.
}
