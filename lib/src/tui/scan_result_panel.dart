import 'package:cinder/cinder.dart';

import '../core/scanner.dart';
import '../core/services.dart';
import 'scan_progress_panel.dart';

const _resultAccent = Color(0x64D8CB);
const _resultSurface = Color(0x151B23);
const _resultSurfaceStrong = Color(0x1D2632);
const _resultMuted = Color(0x7D8A99);
const _resultText = Color(0xE6EDF3);
const _resultSuccess = Color(0x56D364);
const _resultWarning = Color(0xE3B341);
const _resultDanger = Color(0xF47067);

class ScanResultPanel extends StatefulWidget {
  const ScanResultPanel({
    super.key,
    required this.result,
    required this.translate,
    required this.onCompare,
    required this.onRepeat,
    required this.onChangeSource,
    this.artifacts,
    this.onOpenReport,
    this.onExport,
  });

  final ScanResult result;
  final ScanArtifacts? artifacts;
  final String Function(String key) translate;
  final VoidCallback? onOpenReport;
  final VoidCallback onCompare;
  final VoidCallback? onExport;
  final VoidCallback onRepeat;
  final VoidCallback onChangeSource;

  @override
  State<ScanResultPanel> createState() => _ScanResultPanelState();
}

class _ScanResultPanelState extends State<ScanResultPanel> {
  var showIssues = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.result.summary;
    final manifestArtifact = widget.artifacts?.artifacts
        .where((artifact) => artifact.kind == 'manifest')
        .firstOrNull;
    return Container(
      decoration: BoxDecoration(
        color: _resultSurface,
        border: BoxBorder.all(
          color: summary.readErrors == 0 ? _resultSuccess : _resultWarning,
          style: BoxBorderStyle.rounded,
        ),
        title: BorderTitle(
          text: widget.translate('scanCompleted'),
          style: const TextStyle(
            color: _resultSuccess,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _metric(
                  widget.translate('filesHashed'),
                  summary.filesHashed.toString(),
                ),
              ),
              Expanded(
                child: _metric(
                  widget.translate('directoriesVisited'),
                  summary.directoriesVisited.toString(),
                ),
              ),
              Expanded(
                child: _metric(
                  widget.translate('skipped'),
                  summary.skipped.toString(),
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _metric(
                  widget.translate('readErrors'),
                  summary.readErrors.toString(),
                  warning: summary.readErrors > 0,
                ),
              ),
              Expanded(
                child: _metric(
                  widget.translate('unstableFiles'),
                  summary.unstableFiles.toString(),
                  warning: summary.unstableFiles > 0,
                ),
              ),
              Expanded(
                child: _metric(
                  widget.translate('transferred'),
                  formatBytes(summary.transferredBytes),
                ),
              ),
            ],
          ),
          _metric(
              widget.translate('duration'), formatDuration(summary.duration)),
          const SizedBox(height: 1),
          Text(
            widget.translate('manifest'),
            style: const TextStyle(color: _resultMuted),
          ),
          Container(
            color: _resultSurfaceStrong,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              manifestArtifact?.file.absolute.path ?? widget.result.manifest.id,
              maxLines: 1,
              style: const TextStyle(color: _resultAccent),
            ),
          ),
          if (summary.issues.isNotEmpty) ...<Widget>[
            const SizedBox(height: 1),
            GestureDetector(
              onTap: () => setState(() => showIssues = !showIssues),
              child: Text(
                '${showIssues ? '▾' : '▸'} '
                '${widget.translate('issues')} (${summary.issues.length})',
                style: const TextStyle(
                  color: _resultWarning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (showIssues)
              Container(
                color: _resultSurfaceStrong,
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: summary.issues
                      .take(50)
                      .map(
                        (issue) => Text(
                          '${issue.path} — ${issue.code}: ${issue.message}',
                          maxLines: 2,
                          style: const TextStyle(color: _resultDanger),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
          ],
          const SizedBox(height: 1),
          Row(
            children: <Widget>[
              _button(
                widget.translate('openReport'),
                widget.onOpenReport,
                muted: true,
              ),
              const SizedBox(width: 1),
              _button(widget.translate('compare'), widget.onCompare,
                  muted: true),
              const SizedBox(width: 1),
              _button(widget.translate('export'), widget.onExport, muted: true),
              const Spacer(),
              _button(
                widget.translate('changeSource'),
                widget.onChangeSource,
                muted: true,
              ),
              const SizedBox(width: 1),
              _button(widget.translate('repeat'), widget.onRepeat),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, {bool warning = false}) => Padding(
        padding: const EdgeInsets.only(right: 1),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: const TextStyle(color: _resultMuted)),
            ),
            Text(
              value,
              style: TextStyle(
                color: warning ? _resultWarning : _resultText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Widget _button(String label, VoidCallback? onTap, {bool muted = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          color: onTap == null
              ? const Color(0x27313D)
              : muted
                  ? _resultSurfaceStrong
                  : _resultAccent,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null
                  ? _resultMuted
                  : muted
                      ? _resultText
                      : const Color(0x0D1117),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
