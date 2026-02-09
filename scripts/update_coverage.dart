import 'dart:io';

void main() {
  final lcovFile = File('coverage/lcov.info');
  if (!lcovFile.existsSync()) {
    print(
        'Error: coverage/lcov.info not found. Run flutter test --coverage first.');
    exit(1);
  }

  final content = lcovFile.readAsStringSync();
  final records = content.split('end_of_record');

  int totalLF = 0;
  int totalLH = 0;

  int domainProvidersLF = 0;
  int domainProvidersLH = 0;

  int dataLF = 0;
  int dataLH = 0;

  for (final record in records) {
    if (record.trim().isEmpty) continue;

    final lines = record.trim().split('\n');
    String? sf;
    int? lf;
    int? lh;

    for (final line in lines) {
      if (line.startsWith('SF:')) sf = line.substring(3);
      if (line.startsWith('LF:')) {
        final val = line.substring(3).trim();
        if (val.isNotEmpty) lf = int.parse(val);
      }
      if (line.startsWith('LH:')) {
        final val = line.substring(3).trim();
        if (val.isNotEmpty) lh = int.parse(val);
      }
    }

    if (sf != null && lf != null && lh != null) {
      totalLF += lf;
      totalLH += lh;

      if (sf.contains('lib/domain') || sf.contains('lib/providers')) {
        domainProvidersLF += lf;
        domainProvidersLH += lh;
      }

      if (sf.contains('lib/data')) {
        dataLF += lf;
        dataLH += lh;
      }
    }
  }

  final totalPct = totalLF > 0 ? (totalLH / totalLF * 100) : 0.0;
  final dpPct = domainProvidersLF > 0
      ? (domainProvidersLH / domainProvidersLF * 100)
      : 0.0;
  final dataPct = dataLF > 0 ? (dataLH / dataLF * 100) : 0.0;

  final readmeFile = File('README.md');
  if (!readmeFile.existsSync()) {
    print('Error: README.md not found.');
    exit(1);
  }

  String readmeContent = readmeFile.readAsStringSync();

  // Flexible regex to find the coverage table
  final tableRegex = RegExp(
    r'\| Category \| Coverage \(Lines\) \|\s*\n\|-+\|-+\|\s*\n\| \*\*Total Project\*\* \| .*? \|\s*\n\| \*\*Domain & Providers\*\* \| .*? \|\s*\n\| \*\*Data Layer\*\* \| .*? \|',
    multiLine: true,
  );

  final newTable = '''
| Category | Coverage (Lines) |
|----------|------------------|
| **Total Project** | ${totalPct.toStringAsFixed(1)}% |
| **Domain & Providers** | ${dpPct.toStringAsFixed(1)}% |
| **Data Layer** | ${dataPct.toStringAsFixed(1)}% |''';

  if (tableRegex.hasMatch(readmeContent)) {
    readmeContent = readmeContent.replaceFirst(tableRegex, newTable.trim());
    readmeFile.writeAsStringSync(readmeContent);
    print(
        'Successfully updated README.md with coverage: Total: ${totalPct.toStringAsFixed(1)}%');
  } else {
    print(
        'Error: Could not find coverage table in README.md. Please ensure it exists with the correct format.');
    exit(1);
  }
}
