import 'dart:async';

import 'package:flutter/material.dart';

class EditableStorageDataCellConfig {
  const EditableStorageDataCellConfig({
    required this.width,
    required this.index,
    required this.trackingEditStatus,
    required this.onRefresh,
    this.initialValue,
    this.onFieldSubmitted,
  });

  final double width;
  final int index;
  final List<bool> trackingEditStatus;
  final VoidCallback onRefresh;
  final String? initialValue;
  final Future<void> Function(String newValue)? onFieldSubmitted;
}

DataCell buildEditableStorageDataCell(EditableStorageDataCellConfig config) {
  return DataCell(
    SizedBox(
      width: config.width,
      child: Builder(
        builder: (context) {
          return !config.trackingEditStatus[config.index]
              ? Text(
                  config.initialValue ?? "",
                  style: const TextStyle(fontSize: 16.0),
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                )
              : TextFormField(
                  initialValue: config.initialValue,
                  onFieldSubmitted: (newValue) async {
                    if (newValue != config.initialValue &&
                        config.onFieldSubmitted != null) {
                      await config.onFieldSubmitted!(newValue);
                    }
                    config.trackingEditStatus[config.index] = false;
                    config.onRefresh();
                  },
                );
        },
      ),
    ),
    onTap: () {
      config.trackingEditStatus[config.index] =
          !config.trackingEditStatus[config.index];
      config.onRefresh();
    },
  );
}

String? requiredStorageText(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter some text';
  }
  return null;
}

class AddWebStorageItemForm extends StatelessWidget {
  const AddWebStorageItemForm({
    required this.formKey,
    required this.nameController,
    required this.valueController,
    required this.labelName,
    required this.labelValue,
    required this.onAdded,
    required this.onRefresh,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController valueController;
  final String labelName;
  final String labelValue;
  final FutureOr<void> Function(String name, String value) onAdded;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: labelName),
                validator: requiredStorageText,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(right: 10.0),
              child: TextFormField(
                controller: valueController,
                decoration: InputDecoration(labelText: labelValue),
                validator: requiredStorageText,
              ),
            ),
          ),
          TextButton(
            child: const Text("Add Item"),
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              await onAdded(nameController.text, valueController.text);
              formKey.currentState!.reset();
              onRefresh();
            },
          ),
        ],
      ),
    );
  }
}
