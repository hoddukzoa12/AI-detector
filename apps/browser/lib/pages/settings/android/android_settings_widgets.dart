import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// 폭 50 짜리 숫자 입력 trailing 을 가진 설정 행의 추출본.
Widget androidNumberTile({
  required String title,
  required String subtitle,
  required String? initialValue,
  required ValueChanged<String> onSubmitted,
}) {
  return ListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: SizedBox(
      width: 50.0,
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: const TextInputType.numberWithOptions(),
        onFieldSubmitted: onSubmitted,
      ),
    ),
  );
}

/// 텍스트 입력 trailing 을 가진 설정 행의 추출본.
Widget androidTextTile({
  required String title,
  required String subtitle,
  required double width,
  required String? initialValue,
  required ValueChanged<String> onSubmitted,
}) {
  return ListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: SizedBox(
      width: width,
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: TextInputType.text,
        onFieldSubmitted: onSubmitted,
      ),
    ),
  );
}

/// 색 선택 다이얼로그를 여는 trailing 버튼을 가진 설정 행의 추출본.
Widget androidColorTile({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String? currentColor,
  required ValueChanged<Color> onColorChanged,
}) {
  return ListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: SizedBox(
        width: 140.0,
        child: ElevatedButton(
          child: Text(
            currentColor ?? 'Pick a color!',
            style: const TextStyle(fontSize: 12.5),
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  content: SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: const Color(0xffffffff),
                      onColorChanged: onColorChanged,
                      pickerAreaHeightPercent: 0.8,
                    ),
                  ),
                );
              },
            );
          },
        )),
  );
}

/// 섹션들이 똑같이 반복하던 열거형 드롭다운의 추출본.
///
/// 항목 라벨은 원본과 같이 `value.toString()` 이고 글자 크기도 12.5 로 같다.
DropdownButton<T> androidEnumDropdown<T>({
  required String hint,
  required Iterable<T> values,
  required T? value,
  required ValueChanged<T?> onChanged,
}) {
  return DropdownButton<T>(
    hint: Text(hint),
    onChanged: onChanged,
    value: value,
    items: values.map((item) {
      return DropdownMenuItem<T>(
        value: item,
        child: Text(
          item.toString(),
          style: const TextStyle(fontSize: 12.5),
        ),
      );
    }).toList(),
  );
}

/// 위 드롭다운을 원본과 같은 좌우 20 / 아래 10 여백 컨테이너로 감싼 형태.
Widget androidEnumDropdownRow<T>({
  required String hint,
  required Iterable<T> values,
  required T? value,
  required ValueChanged<T?> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 10.0),
    alignment: Alignment.center,
    child: androidEnumDropdown<T>(
      hint: hint,
      values: values,
      value: value,
      onChanged: onChanged,
    ),
  );
}
