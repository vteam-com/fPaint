part of 'app_updater.dart';

/// The Windows [AppUpdater]: the build is the files of the executable's
/// folder, zipped. PowerShell unpacks it; the replacer waits for fPaint to
/// quit and free its files, copies them over the installed ones with
/// `robocopy` (which retries a file still locked), and starts [executable].
class WindowsAppUpdater extends AppUpdater {
  /// Creates the updater of the folder holding [executable].
  WindowsAppUpdater({
    required super.client,
    required super.executable,
    required super.processId,
    super.run,
    super.start,
  });

  static const String _powerShell = 'powershell';
  static const List<String> _powerShellOptions = <String>[
    '-NoProfile',
    '-NonInteractive',
    '-WindowStyle',
    'Hidden',
    '-Command',
  ];

  @override
  String get assetName => AppUpdates.windowsAsset;

  /// The folder holding [executable].
  @override
  String get installPath => p.dirname(executable);

  /// The build's files are at the archive's root.
  @override
  String appIn(String unpacked) => unpacked;

  @override
  Future<void> startReplacer(String newApp, String staging) async {
    final String command = <String>[
      'Wait-Process -Id $processId -ErrorAction SilentlyContinue',
      'robocopy ${powerShellLiteral(newApp)} ${powerShellLiteral(installPath)} /E /R:10 /W:1 | Out-Null',
      'Remove-Item -LiteralPath ${powerShellLiteral(staging)} -Recurse -Force',
      'Start-Process -FilePath ${powerShellLiteral(executable)}',
    ].join('; ');
    await start(_powerShell, <String>[..._powerShellOptions, command], mode: ProcessStartMode.detached);
  }

  @override
  Future<void> unpack(String archive, String into) => runChecked(_powerShell, <String>[
    ..._powerShellOptions,
    'Expand-Archive -LiteralPath ${powerShellLiteral(archive)} -DestinationPath ${powerShellLiteral(into)} -Force',
  ]);

  /// [value] as a single-quoted PowerShell string literal.
  static String powerShellLiteral(String value) => "'${value.replaceAll("'", "''")}'";
}
