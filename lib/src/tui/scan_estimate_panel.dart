import 'package:cinder/cinder.dart';

import '../core/scan_control.dart';
import 'scan_progress_panel.dart';

const _estimateAccent = Color(0x64D8CB);
const _estimateBackground = Color(0x0D1117);
const _estimateSurface = Color(0x151B23);
const _estimateSurfaceStrong = Color(0x1D2632);
const _estimateMuted = Color(0x7D8A99);
const _estimateText = Color(0xE6EDF3);
const _estimateWarning = Color(0xE3B341);

class ScanEstimatePanel extends StatefulWidget {
  const ScanEstimatePanel({
    super.key,
    required this.estimate,
    required this.fullVerification,
    required this.translate,
    required this.onStart,
    required this.onCancel,
    required this.onChangeSource,
  });

  final ScanEstimate estimate;
  final bool fullVerification;
  final String Function(String key) translate;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final VoidCallback onChangeSource;

  @override
  State<ScanEstimatePanel> createState() => _ScanEstimatePanelState();
}

class _ScanEstimatePanelState extends State<ScanEstimatePanel> {
  var showAllExclusions = false;

  @override
  Widget build(BuildContext context) {
    final exclusions = showAllExclusions
        ? widget.estimate.exclusions
        : widget.estimate.exclusions.take(8).toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        color: _estimateBackground,
        border: BoxBorder.all(
          color: _estimateAccent,
          style: BoxBorderStyle.rounded,
        ),
        title: BorderTitle(
          text: widget.translate('scanEstimate'),
          style: const TextStyle(
            color: _estimateAccent,
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
                  widget.translate('files'),
                  widget.estimate.files.toString(),
                ),
              ),
              Expanded(
                child: _metric(
                  widget.translate('directories'),
                  widget.estimate.directories.toString(),
                ),
              ),
              Expanded(
                child: _metric(
                  widget.translate('totalSize'),
                  formatBytes(widget.estimate.bytes),
                ),
              ),
              Expanded(
                child: _metric(
                  widget.translate('skipped'),
                  widget.estimate.skipped.toString(),
                ),
              ),
            ],
          ),
          _metric(widget.translate('expectedTime'), _durationRange()),
          const SizedBox(height: 1),
          Container(
            color: _estimateSurfaceStrong,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              widget.fullVerification
                  ? widget.translate('fullVerificationDescription')
                  : widget.translate('fastVerificationWarning'),
              maxLines: 2,
              style: TextStyle(
                color: widget.fullVerification
                    ? _estimateText
                    : _estimateWarning,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            widget.translate('exclusionPreview'),
            style: const TextStyle(
              color: _estimateMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Container(
              color: _estimateSurface,
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: exclusions.isEmpty
                  ? Text(
                      widget.translate('noExcludedFiles'),
                      style: const TextStyle(color: _estimateMuted),
                    )
                  : ListView.builder(
                      itemCount: exclusions.length,
                      itemBuilder: (context, index) {
                        final exclusion = exclusions[index];
                        return Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                exclusion.pattern,
                                maxLines: 1,
                                style: const TextStyle(color: _estimateText),
                              ),
                            ),
                            SizedBox(
                              width: 14,
                              child: Text(
                                '${exclusion.files} ${widget.translate('filesShort')}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: _estimateMuted),
                              ),
                            ),
                            const SizedBox(width: 1),
                            SizedBox(
                              width: 12,
                              child: Text(
                                formatBytes(exclusion.bytes),
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: _estimateMuted),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
          if (widget.estimate.exclusions.length > 8)
            GestureDetector(
              onTap: () => setState(
                () => showAllExclusions = !showAllExclusions,
              ),
              child: Text(
                showAllExclusions
                    ? widget.translate('showLess')
                    : '${widget.translate('showAll')} '
                        '(${widget.estimate.exclusions.length})',
                style: const TextStyle(color: _estimateAccent),
              ),
            ),
          const SizedBox(height: 1),
          Row(
            children: <Widget>[
              _button(widget.translate('cancel'), widget.onCancel, muted: true),
              const SizedBox(width: 1),
              _button(
                widget.translate('changeSource'),
                widget.onChangeSource,
                muted: true,
              ),
              const Spacer(),
              _button(widget.translate('startScan'), widget.onStart),
            ],
          ),
        ],
      ),
    );
  }

  String _durationRange() {
    final minimum = widget.estimate.minimumDuration;
    final maximum = widget.estimate.maximumDuration;
    if (minimum == null || maximum == null) {
      return widget.translate('calculating');
    }
    if (minimum == Duration.zero && maximum == Duration.zero) return '< 1s';
    return '${formatDuration(minimum)}–${formatDuration(maximum)}';
  }

  Widget _metric(String label, String value) => Padding(
        padding: const EdgeInsets.only(right: 1),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: const TextStyle(color: _estimateMuted)),
            ),
            Text(
              value,
              style: const TextStyle(
                color: _estimateText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Widget _button(String label, VoidCallback onTap, {bool muted = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          color: muted ? _estimateSurfaceStrong : _estimateAccent,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            style: TextStyle(
              color: muted ? _estimateText : _estimateBackground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}
