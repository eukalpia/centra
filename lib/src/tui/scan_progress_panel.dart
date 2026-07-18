import 'package:cinder/cinder.dart';

import '../core/scan_control.dart';

const _progressAccent = Color(0x64D8CB);
const _progressSurface = Color(0x151B23);
const _progressSurfaceStrong = Color(0x1D2632);
const _progressMuted = Color(0x7D8A99);
const _progressText = Color(0xE6EDF3);
const _progressWarning = Color(0xE3B341);

class ScanProgressPanel extends StatelessWidget {
  const ScanProgressPanel({
    super.key,
    required this.progress,
    required this.translate,
    required this.onCancel,
    required this.onCancelAndEdit,
    this.cancelling = false,
  });

  final ScanProgress progress;
  final String Function(String key) translate;
  final VoidCallback onCancel;
  final VoidCallback onCancelAndEdit;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.fraction;
    final percent = fraction == null ? null : (fraction * 100).floor();
    return Container(
      decoration: BoxDecoration(
        color: _progressSurface,
        border: BoxBorder.all(
          color: _progressAccent,
          style: BoxBorderStyle.rounded,
        ),
        title: BorderTitle(
          text: translate('scanProgress'),
          style: const TextStyle(
            color: _progressAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _phaseRow('ssh-connect', translate('phaseConnect')),
          _phaseRow('ssh-inventory', translate('phaseInventory')),
          _phaseRow('ssh-download', translate('phaseTransfer')),
          _phaseRow('hashing', translate('phaseHashing')),
          const SizedBox(height: 1),
          _bar(fraction, percent),
          const SizedBox(height: 1),
          Text(
            translate('currentFile'),
            style: const TextStyle(color: _progressMuted),
          ),
          Container(
            color: _progressSurfaceStrong,
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              progress.currentPath ?? '—',
              maxLines: 1,
              style: const TextStyle(color: _progressText),
            ),
          ),
          const SizedBox(height: 1),
          Row(
            children: <Widget>[
              Expanded(
                child: _metric(
                  translate('transferred'),
                  formatBytes(progress.transferredBytes),
                ),
              ),
              Expanded(
                child: _metric(
                  translate('speed'),
                  progress.bytesPerSecond == null
                      ? translate('calculating')
                      : '${formatBytes(progress.bytesPerSecond!.round())}/s',
                ),
              ),
              Expanded(
                child: _metric(
                  translate('elapsed'),
                  formatDuration(progress.elapsed),
                ),
              ),
              Expanded(
                child: _metric(
                  translate('remaining'),
                  progress.eta == null
                      ? translate('calculating')
                      : '~${formatDuration(progress.eta!)}',
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _metric(
                  translate('files'),
                  '${progress.completed}/${progress.discovered}',
                ),
              ),
              Expanded(
                child: _metric(
                  translate('directories'),
                  progress.directories.toString(),
                ),
              ),
              Expanded(
                child: _metric(
                  translate('skipped'),
                  progress.skipped.toString(),
                ),
              ),
              Expanded(
                child: _metric(
                  translate('readErrors'),
                  progress.readErrors.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Row(
            children: <Widget>[
              _button(
                cancelling ? translate('cancelling') : translate('stopScan'),
                cancelling ? null : onCancel,
                warning: true,
              ),
              const SizedBox(width: 1),
              _button(
                translate('stopAndChangeSource'),
                cancelling ? null : onCancelAndEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phaseRow(String phase, String label) {
    final order = <String>[
      'ssh-connect',
      'source-prepare',
      'estimate',
      'ssh-inventory',
      'inventory',
      'ssh-download',
      'hashing',
      'writing',
      'complete',
    ];
    final current = order.indexOf(progress.phase);
    final target = phase == 'ssh-connect'
        ? 0
        : phase == 'ssh-inventory'
            ? 3
            : phase == 'ssh-download'
                ? 5
                : 6;
    final complete = current > target || progress.phase == 'complete';
    final active = current == target ||
        (phase == 'ssh-connect' && progress.phase == 'source-prepare') ||
        (phase == 'ssh-inventory' && progress.phase == 'inventory');
    final marker = complete
        ? '✓'
        : active
            ? '›'
            : '·';
    final suffix = active && progress.discovered > 0
        ? '  ${progress.completed}/${progress.discovered}'
        : '';
    return Text(
      '$marker $label$suffix',
      style: TextStyle(
        color: complete
            ? const Color(0x56D364)
            : active
                ? _progressAccent
                : _progressMuted,
      ),
    );
  }

  Widget _bar(double? fraction, int? percent) {
    const width = 48;
    final filled = fraction == null ? 0 : (fraction * width).round();
    final bar = '${'█' * filled}${'░' * (width - filled)}';
    return Text(
      percent == null ? '[$bar]  —' : '[$bar]  $percent%',
      style: const TextStyle(color: _progressAccent),
    );
  }

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: _progressMuted)),
          Text(value, style: const TextStyle(color: _progressText)),
        ],
      );

  Widget _button(
    String label,
    VoidCallback? onTap, {
    bool warning = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          color: onTap == null
              ? const Color(0x27313D)
              : warning
                  ? _progressWarning
                  : _progressSurfaceStrong,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null
                  ? _progressMuted
                  : warning
                      ? const Color(0x0D1117)
                      : _progressText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = <String>['KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes.toDouble();
  var unit = -1;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : value >= 10 ? 1 : 2)} ${units[unit]}';
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
