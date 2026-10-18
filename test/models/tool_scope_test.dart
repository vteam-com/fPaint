import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/models/tool_scope.dart';

void main() {
  group('ToolScope.apply', () {
    late List<String> calls;
    late ToolScope scope;

    setUp(() {
      calls = <String>[];
      scope = ToolScope(
        tools: const <ToolKind>{ToolKind.smudge, ToolKind.blurBrush},
        release: () => calls.add('release'),
        enter: () => calls.add('enter'),
      );
    });

    test('enters for a tool inside the scope', () {
      scope.apply(ToolKind.blurBrush);
      expect(calls, <String>['enter']);
    });

    test('releases for a tool outside the scope', () {
      scope.apply(ToolKind.brush);
      expect(calls, <String>['release']);
    });

    test('a scope without enter does nothing for its own tools', () {
      final ToolScope releaseOnly = ToolScope(
        tools: const <ToolKind>{ToolKind.fill},
        release: () => calls.add('release'),
      );
      releaseOnly.apply(ToolKind.fill);
      expect(calls, isEmpty);
    });
  });
}
