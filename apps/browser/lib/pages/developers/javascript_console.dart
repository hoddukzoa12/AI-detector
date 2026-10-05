import 'package:flutter/material.dart';
import 'package:infocutter_app/javascript_console_result.dart';
import 'package:infocutter_app/models/javascript_console_log.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:provider/provider.dart';

import '../../models/window_model.dart';

class JavaScriptConsole extends StatefulWidget {
  const JavaScriptConsole({super.key});

  @override
  State<JavaScriptConsole> createState() => _JavaScriptConsoleState();
}

class _JavaScriptConsoleState extends State<JavaScriptConsole> {
  final TextEditingController _customJavaScriptController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int currentJavaScriptHistory = 0;

  @override
  void dispose() {
    _customJavaScriptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildJavaScriptConsole();
  }

  Widget _buildJavaScriptConsole() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Flexible(child: _buildConsoleLogList()),
        const Divider(),
        _buildConsoleInputBar(),
      ],
    );
  }

  Widget _buildConsoleLogList() {
    return Selector<WebViewModel, List<JavaScriptConsoleLog>>(
      selector: (context, webViewModel) => webViewModel.javaScriptConsoleLogs,
      builder: (context, javaScriptConsoleLogs, child) {
        return ListView.builder(
          controller: _scrollController,
          itemCount: javaScriptConsoleLogs.length,
          itemBuilder: (context, index) {
            return JavaScriptConsoleResult(log: javaScriptConsoleLogs[index]);
          },
        );
      },
    );
  }

  Widget _buildConsoleInputBar() => SizedBox(
        height: 75.0,
        child: Row(
          children: <Widget>[
            Flexible(child: _buildConsoleInputField()),
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {
                evaluateJavaScript(_customJavaScriptController.text);
              },
            ),
            _buildHistoryControls(),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: _clearConsole,
            )
          ],
        ),
      );

  Widget _buildConsoleInputField() => TextField(
        expands: true,
        onSubmitted: evaluateJavaScript,
        controller: _customJavaScriptController,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        decoration: const InputDecoration(
          hintText: "document.querySelector('body') ...",
          prefixIcon: Icon(Icons.keyboard_arrow_right, color: Colors.blue),
          border: InputBorder.none,
        ),
      );

  Widget _buildHistoryControls() {
    return Selector<WebViewModel, List<String>>(
      selector: (context, webViewModel) =>
          webViewModel.javaScriptConsoleHistory,
      builder: (context, javaScriptConsoleHistory, child) {
        currentJavaScriptHistory = javaScriptConsoleHistory.length;
        return Column(
          children: <Widget>[
            _historyButton(Icons.keyboard_arrow_up, () {
              _showPreviousHistory(javaScriptConsoleHistory);
            }),
            _historyButton(Icons.keyboard_arrow_down, () {
              _showNextHistory(javaScriptConsoleHistory);
            }),
          ],
        );
      },
    );
  }

  Widget _historyButton(IconData icon, VoidCallback onPressed) => SizedBox(
        height: 35.0,
        child: IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      );

  void _showPreviousHistory(List<String> history) {
    currentJavaScriptHistory--;
    if (currentJavaScriptHistory < 0) {
      currentJavaScriptHistory = 0;
      return;
    }
    _customJavaScriptController.text = history[currentJavaScriptHistory];
  }

  void _showNextHistory(List<String> history) {
    if (currentJavaScriptHistory + 1 >= history.length) {
      currentJavaScriptHistory = history.length;
      _customJavaScriptController.text = "";
      return;
    }
    currentJavaScriptHistory++;
    _customJavaScriptController.text = history[currentJavaScriptHistory];
  }

  void _clearConsole() {
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    var webViewModel = windowModel.getCurrentWebViewModel();
    if (webViewModel == null) return;

    webViewModel.setJavaScriptConsoleLogs([]);
    var currentWebViewModel = Provider.of<WebViewModel>(context, listen: false);
    currentWebViewModel.updateWithValue(webViewModel);
  }

  void evaluateJavaScript(String source) async {
    final windowModel = Provider.of<WindowModel>(context, listen: false);
    final webViewModel = windowModel.getCurrentWebViewModel();

    if (webViewModel != null) {
      var currentWebViewModel =
          Provider.of<WebViewModel>(context, listen: false);

      if (source.isNotEmpty &&
          (webViewModel.javaScriptConsoleHistory.isEmpty ||
              (webViewModel.javaScriptConsoleHistory.isNotEmpty &&
                  webViewModel.javaScriptConsoleHistory.last != source))) {
        webViewModel.addJavaScriptConsoleHistory(source);
        currentWebViewModel.updateWithValue(webViewModel);
      }

      var result = await webViewModel.webViewController
          ?.evaluateJavascript(source: source);

      webViewModel.addJavaScriptConsoleLog(
          JavaScriptConsoleLog(message: result.toString()));
      currentWebViewModel.updateWithValue(webViewModel);

      setState(() {
        Future.delayed(const Duration(milliseconds: 100), () async {
          await _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.ease);
          // must be repeated, otherwise it won't scroll to the bottom sometimes
          await _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.ease);
        });
      });
    }
  }
}
