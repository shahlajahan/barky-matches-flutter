import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/business/petshop/working_hours_format.dart';

/// The reported defect: a Pet Shop stored `10:00_21:00` and the public profile
/// rendered it verbatim, because working hours were accepted as free text.
void main() {
  group('accepted input', () {
    test('ASCII hyphen is accepted and canonicalized', () {
      expect(WorkingHoursFormat.normalize('10:00-21:00'), '10:00–21:00');
    });

    test('en dash is accepted and preserved', () {
      expect(WorkingHoursFormat.normalize('10:00–21:00'), '10:00–21:00');
    });

    test('em dash is accepted and canonicalized', () {
      expect(WorkingHoursFormat.normalize('10:00—21:00'), '10:00–21:00');
    });

    test('surrounding and inner whitespace is tolerated', () {
      expect(WorkingHoursFormat.normalize('  10:00 - 21:00  '), '10:00–21:00');
      expect(WorkingHoursFormat.normalize('10:00   –   21:00'), '10:00–21:00');
    });

    test('single-digit hours are zero-padded to the canonical form', () {
      expect(WorkingHoursFormat.normalize('9:05-18:30'), '09:05–18:30');
    });

    test('boundary times are accepted', () {
      expect(WorkingHoursFormat.normalize('00:00-23:59'), '00:00–23:59');
    });
  });

  group('rejected input', () {
    test('the reported underscore separator is rejected', () {
      expect(WorkingHoursFormat.normalize('10:00_21:00'), isNull);
      expect(WorkingHoursFormat.isValid('10:00_21:00'), isFalse);
    });

    test('arbitrary separators are rejected', () {
      for (final raw in const [
        '10:00 to 21:00',
        '10:00/21:00',
        '10:00~21:00',
        '10:00,21:00',
        '10:00 21:00',
        '10:00:21:00',
      ]) {
        expect(WorkingHoursFormat.normalize(raw), isNull, reason: raw);
      }
    });

    test('out-of-range hours are rejected', () {
      for (final raw in const ['24:00-25:00', '25:00-26:00', '10:00-24:00']) {
        expect(WorkingHoursFormat.normalize(raw), isNull, reason: raw);
      }
    });

    test('out-of-range minutes are rejected', () {
      for (final raw in const ['10:60-21:00', '10:00-21:75', '10:99-21:00']) {
        expect(WorkingHoursFormat.normalize(raw), isNull, reason: raw);
      }
    });

    test('equal or reversed ranges are rejected', () {
      expect(WorkingHoursFormat.normalize('10:00-10:00'), isNull);
      expect(WorkingHoursFormat.normalize('21:00-10:00'), isNull);
      expect(WorkingHoursFormat.normalize('10:30-10:29'), isNull);
    });

    test('structurally malformed values are rejected', () {
      for (final raw in const [
        '',
        '   ',
        'open daily',
        '10-21',
        '10:0-21:00',
        '1000-2100',
        '10:00–',
        '–21:00',
      ]) {
        expect(WorkingHoursFormat.normalize(raw), isNull, reason: '"$raw"');
      }
      expect(WorkingHoursFormat.normalize(null), isNull);
    });

    test('an invalid value is never silently rewritten into a valid one', () {
      // Every rejected value returns null rather than a "closest" valid range.
      for (final raw in const ['10:00_21:00', '25:00-26:00', '21:00-10:00']) {
        expect(WorkingHoursFormat.normalize(raw), isNull, reason: raw);
      }
    });
  });

  group('display of stored values', () {
    test('canonical values render unchanged', () {
      expect(WorkingHoursFormat.forDisplay('10:00–21:00'), '10:00–21:00');
    });

    test('valid legacy hyphen values are canonicalized for display', () {
      expect(WorkingHoursFormat.forDisplay('10:00-21:00'), '10:00–21:00');
    });

    test('malformed legacy values are shown as stored, never crash', () {
      expect(WorkingHoursFormat.forDisplay('10:00_21:00'), '10:00_21:00');
      expect(WorkingHoursFormat.forDisplay('  open daily '), 'open daily');
    });

    test('empty and null render as absent', () {
      expect(WorkingHoursFormat.forDisplay(''), isNull);
      expect(WorkingHoursFormat.forDisplay('   '), isNull);
      expect(WorkingHoursFormat.forDisplay(null), isNull);
    });
  });
}
