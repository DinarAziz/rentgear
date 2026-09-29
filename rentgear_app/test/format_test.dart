import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/core/format.dart';

TextEditingValue _type(String text, {int? cursor}) => RibuanInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor ?? text.length)),
    );

void main() {
  test('ribuan dan parseRibuan saling balik', () {
    expect(ribuan(35000), '35.000');
    expect(ribuan(750000), '750.000');
    expect(parseRibuan('1.250.000'), 1250000);
    expect(parseRibuan(''), isNull);
  });

  test('RibuanInputFormatter menambah titik ribuan dan membuang non-angka', () {
    expect(_type('35000').text, '35.000');
    expect(_type('35000').selection.baseOffset, 6);
    expect(_type('3a5.0x00').text, '35.000');
    expect(_type('').text, '');
  });

  test('RibuanInputFormatter menjaga kursor di tengah angka', () {
    // Kursor setelah "1" pada "1000" (sisa 3 digit di kanan) → setelah "1" pada "1.000".
    final v = _type('1000', cursor: 1);
    expect(v.text, '1.000');
    expect(v.selection.baseOffset, 1);
  });
}
