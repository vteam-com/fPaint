import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_operation_exception.dart';

void main() {
  group('FileOperationException', () {
    test('toString returns message when no cause', () {
      const FileOperationException exception = FileOperationException('test error');
      expect(exception.toString(), 'test error');
    });

    test('toString includes cause when present', () {
      const FileOperationException exception = FileOperationException(
        'test error',
        cause: 'root cause',
      );
      final String result = exception.toString();
      expect(result, contains('test error'));
      expect(result, contains('root cause'));
    });

    test('message property is accessible', () {
      const FileOperationException exception = FileOperationException('msg');
      expect(exception.message, 'msg');
    });

    test('cause property is accessible', () {
      const FileOperationException exception = FileOperationException('msg', cause: 42);
      expect(exception.cause, 42);
    });

    test('cause defaults to null', () {
      const FileOperationException exception = FileOperationException('msg');
      expect(exception.cause, isNull);
    });
  });

  group('FileSaveException', () {
    test('is a FileOperationException', () {
      const FileSaveException exception = FileSaveException('save failed');
      expect(exception, isA<FileOperationException>());
    });

    test('toString works correctly', () {
      const FileSaveException exception = FileSaveException('save failed', cause: 'disk full');
      expect(exception.toString(), contains('save failed'));
      expect(exception.toString(), contains('disk full'));
    });
  });

  group('JpegConversionException', () {
    test('is a FileOperationException', () {
      const JpegConversionException exception = JpegConversionException('jpeg error');
      expect(exception, isA<FileOperationException>());
    });
  });

  group('HeicConversionException', () {
    test('is a FileOperationException', () {
      const HeicConversionException exception = HeicConversionException('heic error');
      expect(exception, isA<FileOperationException>());
    });

    test('toString includes cause when present', () {
      const HeicConversionException exception = HeicConversionException(
        'heic error',
        cause: 'platform unsupported',
      );
      expect(exception.toString(), contains('heic error'));
      expect(exception.toString(), contains('platform unsupported'));
    });
  });

  group('OraFileException', () {
    test('is a FileOperationException', () {
      const OraFileException exception = OraFileException('ora error');
      expect(exception, isA<FileOperationException>());
    });
  });

  group('TiffFileException', () {
    test('is a FileOperationException', () {
      const TiffFileException exception = TiffFileException('tiff error');
      expect(exception, isA<FileOperationException>());
    });
  });

  group('WebpConversionException', () {
    test('is a FileOperationException', () {
      const WebpConversionException exception = WebpConversionException('webp error');
      expect(exception, isA<FileOperationException>());
    });
  });

  group('UnsupportedSaveFormatException', () {
    test('is a FileOperationException', () {
      const UnsupportedSaveFormatException exception = UnsupportedSaveFormatException('bmp');
      expect(exception, isA<FileOperationException>());
    });

    test('includes extension in message', () {
      const UnsupportedSaveFormatException exception = UnsupportedSaveFormatException('bmp');
      expect(exception.toString(), contains('bmp'));
    });

    test('extension property is accessible', () {
      const UnsupportedSaveFormatException exception = UnsupportedSaveFormatException('gif');
      expect(exception.extension, 'gif');
    });

    test('message includes unsupported prefix', () {
      const UnsupportedSaveFormatException exception = UnsupportedSaveFormatException('xyz');
      expect(exception.message, contains('Unsupported'));
      expect(exception.message, contains('xyz'));
    });
  });
}
