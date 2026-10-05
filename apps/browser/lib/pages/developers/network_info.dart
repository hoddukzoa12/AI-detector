// import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infocutter_app/custom_image.dart';
import 'package:infocutter_app/models/webview_model.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';
// import 'package:charts_flutter/flutter.dart' as charts;

class NetworkInfo extends StatefulWidget {
  const NetworkInfo({super.key});

  @override
  State<NetworkInfo> createState() => _NetworkInfoState();
}

class _NetworkInfoState extends State<NetworkInfo> {
  @override
  Widget build(BuildContext context) {
    return _buildNetworkInfo();
  }

  Widget _buildNetworkInfo() {
    return LayoutBuilder(builder: (context, constraints) {
      return Selector<WebViewModel, List<LoadedResource>>(
        selector: (context, webViewModel) => webViewModel.loadedResources,
        builder: (context, loadedResources, child) {
          return _buildResourceList(constraints, loadedResources);
        },
      );
    });
  }

  Widget _buildResourceList(
    BoxConstraints constraints,
    List<LoadedResource> loadedResources,
  ) {
    final children = <Widget>[
      _buildHeaderRow(constraints),
      ...loadedResources.reversed.map((resource) {
        return _buildResourceRow(
            constraints, _NetworkResourceRow.from(resource));
      }),
    ];

    return ListView.builder(
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

  Widget _buildHeaderRow(BoxConstraints constraints) => Row(
        children: <Widget>[
          _headerCell("Name", width: constraints.maxWidth / 3.0),
          _headerCell("Domain", width: constraints.maxWidth / 4),
          _headerCell("Type", width: constraints.maxWidth / 4),
          Flexible(child: _headerCell("Time")),
        ],
      );

  Widget _headerCell(String label, {double? width}) => Container(
        width: width,
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
      );

  Widget _buildResourceRow(
    BoxConstraints constraints,
    _NetworkResourceRow resource,
  ) {
    const textStyle = TextStyle(fontSize: 14.0);
    return Row(
      children: <Widget>[
        _buildNameCell(constraints, resource, textStyle),
        _resourceTextCell(
          width: constraints.maxWidth / 4,
          text: resource.domain,
          alignment: Alignment.centerRight,
          style: textStyle,
        ),
        _resourceTextCell(
          width: constraints.maxWidth / 4,
          text: resource.initiatorType,
          alignment: Alignment.center,
          style: textStyle,
        ),
        Flexible(
          child:
              _resourceTextCell(text: resource.durationLabel, style: textStyle),
        ),
      ],
    );
  }

  Widget _buildNameCell(
    BoxConstraints constraints,
    _NetworkResourceRow resource,
    TextStyle textStyle,
  ) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: resource.url.toString()));
      },
      child: Container(
        padding: _resourceCellPadding,
        width: constraints.maxWidth / 3.0,
        child: Row(
          children: <Widget>[
            SizedBox(
              height: 20.0,
              width: 20.0,
              child: _resourceIcon(resource),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                resource.name,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _resourceTextCell({
    required String text,
    required TextStyle style,
    double? width,
    AlignmentGeometry? alignment,
  }) =>
      Container(
        width: width,
        alignment: alignment,
        padding: _resourceCellPadding,
        child: Text(text, overflow: TextOverflow.ellipsis, style: style),
      );

  Widget _resourceIcon(_NetworkResourceRow resource) {
    if (resource.isRasterImage) {
      return CustomImage(url: resource.url, maxWidth: 20.0, height: 20.0);
    }
    if (resource.isSvg) {
      return SvgPicture.network(resource.url.toString(),
          width: 20.0, height: 20.0);
    }
    return Icon(resource.iconData, size: 20.0);
  }

  // List<charts.Series> seriesList;
  //
  // /// Create one series with sample hard coded data.
  // static List<charts.Series<LoadedResource, double>> _createChartData(
  //     List<LoadedResource> data) {
  //   return [
  //     new charts.Series<LoadedResource, double>(
  //       id: 'LoadedResource',
  //       // Providing a color function is optional.
  //       colorFn: (LoadedResource loadedResource, _) {
  //         return charts.Color(
  //           r: ((loadedResource.startTime + loadedResource.duration) * 0xFFFFFF)
  //               .toInt(),
  //           b: (loadedResource.startTime * 0xFFFFFF).toInt(),
  //           g: (loadedResource.duration * 0xFFFFFF).toInt(),
  //         );
  //       },
  //       domainFn: (LoadedResource loadedResource, _) =>
  //           loadedResource.startTime + loadedResource.duration,
  //       domainLowerBoundFn: (LoadedResource loadedResource, _) =>
  //           loadedResource.startTime,
  //       domainUpperBoundFn: (LoadedResource loadedResource, _) =>
  //           loadedResource.startTime + loadedResource.duration,
  //       measureFn: (LoadedResource loadedResource, _) =>
  //           data.indexOf(loadedResource),
  //       measureLowerBoundFn: (LoadedResource loadedResource, _) =>
  //           loadedResource.duration,
  //       measureUpperBoundFn: (LoadedResource loadedResource, _) =>
  //           loadedResource.duration,
  //       radiusPxFn: (LoadedResource loadedResource, _) => 2,
  //       data: data,
  //     )
  //   ];
  // }
}

const _resourceCellPadding = EdgeInsets.symmetric(
  vertical: 5.0,
  horizontal: 2.5,
);

class _NetworkResourceRow {
  const _NetworkResourceRow({
    required this.url,
    required this.name,
    required this.domain,
    required this.initiatorType,
    required this.durationLabel,
    required this.mimeType,
  });

  final Uri url;
  final String name;
  final String domain;
  final String initiatorType;
  final String durationLabel;
  final String? mimeType;

  factory _NetworkResourceRow.from(LoadedResource resource) {
    final url = resource.url ?? Uri.parse("about:blank");
    final path = url.path;
    return _NetworkResourceRow(
      url: url,
      name: path.substring(path.lastIndexOf('/') + 1),
      domain: url.host.replaceFirst("www.", ""),
      initiatorType: resource.initiatorType ?? "",
      durationLabel: resource.duration != null
          ? "${resource.duration!.toStringAsFixed(2)} ms"
          : "",
      mimeType: lookupMimeType(url.toString()),
    );
  }

  bool get isRasterImage =>
      mimeType != null &&
      mimeType!.startsWith("image/") &&
      mimeType != "image/svg+xml";

  bool get isSvg => mimeType == "image/svg+xml";

  IconData get iconData {
    switch (initiatorType) {
      case "script":
        return Icons.format_align_left;
      case "css":
        return Icons.color_lens;
      case "xmlhttprequest":
        return Icons.http;
      case "link":
        return Icons.link;
      default:
        return Icons.insert_drive_file;
    }
  }
}
