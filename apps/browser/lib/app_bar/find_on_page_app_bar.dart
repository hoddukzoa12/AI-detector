import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:infocutter_app/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/window_model.dart';

class FindOnPageAppBar extends StatefulWidget {
  final void Function()? hideFindOnPage;

  const FindOnPageAppBar({super.key, this.hideFindOnPage});

  @override
  State<FindOnPageAppBar> createState() => _FindOnPageAppBarState();
}

class _FindOnPageAppBarState extends State<FindOnPageAppBar> {
  final TextEditingController _finOnPageController = TextEditingController();

  OutlineInputBorder outlineBorder = const OutlineInputBorder(
    borderSide: BorderSide(color: Colors.transparent, width: 0.0),
    borderRadius: BorderRadius.all(
      Radius.circular(50.0),
    ),
  );

  @override
  void dispose() {
    _finOnPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final webViewModel = windowModel.getCurrentWebViewModel();
    final findInteractionController = webViewModel?.findInteractionController;
    final l10n = AppLocalizations.of(context);

    return AppBar(
      titleSpacing: 10.0,
      title: _buildSearchField(findInteractionController, l10n),
      actions: _buildActions(findInteractionController),
    );
  }

  Widget _buildSearchField(
    FindInteractionController? findInteractionController,
    AppLocalizations l10n,
  ) =>
      SizedBox(
        height: 40.0,
        child: TextField(
          onSubmitted: (value) {
            findInteractionController?.findAll(find: value);
          },
          controller: _finOnPageController,
          textInputAction: TextInputAction.go,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(10.0),
            filled: true,
            fillColor: Colors.white,
            border: outlineBorder,
            focusedBorder: outlineBorder,
            enabledBorder: outlineBorder,
            hintText: l10n.findOnPageHint,
            hintStyle: const TextStyle(color: Colors.black54, fontSize: 16.0),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 16.0),
        ),
      );

  List<Widget> _buildActions(
    FindInteractionController? findInteractionController,
  ) =>
      [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: () {
            findInteractionController?.findNext(forward: false);
          },
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () {
            findInteractionController?.findNext();
          },
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _clearFind(findInteractionController);
          },
        ),
      ];

  void _clearFind(FindInteractionController? findInteractionController) {
    findInteractionController?.clearMatches();
    _finOnPageController.text = "";
    widget.hideFindOnPage?.call();
  }
}
