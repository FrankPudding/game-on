enum DataSourceType {
  hive,
  mock,
}

class AppConfig {
  AppConfig({
    this.dataSourceType = DataSourceType.hive,
    this.hiveDbVersion = 1,
  });
  final DataSourceType dataSourceType;
  final int hiveDbVersion;

  // You can add more configuration fields here, like API endpoints, etc.
}
