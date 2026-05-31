import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/providers/shell_provider.dart';

void main() {
  late ShellProvider provider;

  setUp(() {
    provider = ShellProvider();
    // Reset to defaults
    provider.loadedFileName = '';
    provider.deviceSizeSmall = false;
    provider.canvasPlacement = CanvasAutoPlacement.fit;
    provider.shellMode = ShellMode.full;
  });

  group('ShellProvider initial/default state', () {
    test('loadedFileName defaults to empty', () {
      expect(provider.loadedFileName, isEmpty);
    });

    test('deviceSizeSmall defaults to false', () {
      expect(provider.deviceSizeSmall, isFalse);
    });

    test('canvasPlacement defaults to fit', () {
      expect(provider.canvasPlacement, CanvasAutoPlacement.fit);
    });

    test('shellMode defaults to full', () {
      expect(provider.shellMode, ShellMode.full);
    });

    test('isSidePanelExpanded defaults to true', () {
      expect(provider.isSidePanelExpanded, isTrue);
    });

    test('showMenu defaults to false', () {
      expect(provider.showMenu, isFalse);
    });
  });

  group('loadedFileName', () {
    test('can be set and read', () {
      provider.loadedFileName = 'test.png';
      expect(provider.loadedFileName, 'test.png');
    });

    test('can be cleared', () {
      provider.loadedFileName = 'test.ora';
      provider.loadedFileName = '';
      expect(provider.loadedFileName, isEmpty);
    });
  });

  group('shellMode', () {
    test('can be set to hidden', () {
      provider.shellMode = ShellMode.hidden;
      expect(provider.shellMode, ShellMode.hidden);
    });

    test('can be set to minimal', () {
      provider.shellMode = ShellMode.minimal;
      expect(provider.shellMode, ShellMode.minimal);
    });

    test('can be set to full', () {
      provider.shellMode = ShellMode.hidden;
      provider.shellMode = ShellMode.full;
      expect(provider.shellMode, ShellMode.full);
    });

    test('mainScreenLayoutListenable ignores non-layout shell updates', () {
      int providerNotifications = 0;
      int mainScreenLayoutNotifications = 0;

      provider.addListener(() => providerNotifications++);
      provider.mainScreenLayoutListenable.addListener(() => mainScreenLayoutNotifications++);

      provider.requestCanvasFit();

      expect(providerNotifications, 1);
      expect(mainScreenLayoutNotifications, 0);

      provider.interactionInputModality = InteractionInputModality.touch;

      expect(providerNotifications, 2);
      expect(mainScreenLayoutNotifications, 0);

      provider.deviceSizeSmall = true;

      expect(providerNotifications, 3);
      expect(mainScreenLayoutNotifications, 1);

      provider.shellMode = ShellMode.hidden;

      expect(providerNotifications, 4);
      expect(mainScreenLayoutNotifications, 2);
    });
  });

  group('isSidePanelExpanded', () {
    test('setting to false notifies listeners', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      provider.isSidePanelExpanded = false;
      expect(provider.isSidePanelExpanded, isFalse);
      expect(notifyCount, 1);
    });

    test('setting to true notifies listeners', () {
      provider.isSidePanelExpanded = false;
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      provider.isSidePanelExpanded = true;
      expect(provider.isSidePanelExpanded, isTrue);
      expect(notifyCount, 1);
    });

    test('sidePanelExpandedListenable ignores unrelated shell updates', () {
      int providerNotifications = 0;
      int sidePanelExpandedNotifications = 0;

      provider.addListener(() => providerNotifications++);
      provider.sidePanelExpandedListenable.addListener(() => sidePanelExpandedNotifications++);

      provider.showMenu = true;

      expect(providerNotifications, 1);
      expect(sidePanelExpandedNotifications, 0);

      provider.isSidePanelExpanded = false;

      expect(providerNotifications, 2);
      expect(sidePanelExpandedNotifications, 1);
    });
  });

  group('showMenu', () {
    test('setting to true notifies listeners', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      provider.showMenu = true;
      expect(provider.showMenu, isTrue);
      expect(notifyCount, 1);
    });

    test('setting to false notifies listeners', () {
      provider.showMenu = true;
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      provider.showMenu = false;
      expect(provider.showMenu, isFalse);
      expect(notifyCount, 1);
    });

    test('toggling works correctly', () {
      expect(provider.showMenu, isFalse);
      provider.showMenu = true;
      expect(provider.showMenu, isTrue);
      provider.showMenu = false;
      expect(provider.showMenu, isFalse);
    });
  });

  group('canvasPlacement', () {
    test('can be set to manual', () {
      provider.canvasPlacement = CanvasAutoPlacement.manual;
      expect(provider.canvasPlacement, CanvasAutoPlacement.manual);
    });

    test('can be set back to fit', () {
      provider.canvasPlacement = CanvasAutoPlacement.manual;
      provider.canvasPlacement = CanvasAutoPlacement.fit;
      expect(provider.canvasPlacement, CanvasAutoPlacement.fit);
    });

    test('requestCanvasFit sets placement to fit', () {
      provider.canvasPlacement = CanvasAutoPlacement.manual;
      provider.requestCanvasFit();
      expect(provider.canvasPlacement, CanvasAutoPlacement.fit);
    });
  });

  group('deviceSizeSmall', () {
    test('can be set to true', () {
      provider.deviceSizeSmall = true;
      expect(provider.deviceSizeSmall, isTrue);
    });

    test('can be set to false', () {
      provider.deviceSizeSmall = true;
      provider.deviceSizeSmall = false;
      expect(provider.deviceSizeSmall, isFalse);
    });
  });

  group('update', () {
    test('notifies listeners', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      provider.update();
      expect(notifyCount, 1);
    });

    test('multiple calls notify multiple times', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);
      provider.update();
      provider.update();
      provider.update();
      expect(notifyCount, 3);
    });
  });

  group('ShellMode enum', () {
    test('has all expected values', () {
      expect(
        ShellMode.values,
        containsAll(<ShellMode>[
          ShellMode.hidden,
          ShellMode.minimal,
          ShellMode.full,
        ]),
      );
    });

    test('has exactly 3 values', () {
      expect(ShellMode.values.length, 3);
    });
  });
}
