from pathlib import Path

path = Path('lib/src/tui/production_dashboard.dart')
text = path.read_text(encoding='utf-8')
old = """  @override
  Widget build(BuildContext context) => KeyboardListener(
        focusNode: focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Container(
"""
new = """  @override
  Widget build(BuildContext context) => Focus(
        focusNode: focusNode,
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Container(
"""
if old not in text:
    raise SystemExit('Dashboard keyboard wrapper not found')
text = text.replace(old, new, 1)
start = text.index('  void _onKey(')
end = text.index('\n  String _translate', start)
replacement = """  bool _onKey(KeyboardEvent event) {
    if (event.matches(LogicalKey.keyQ, ctrl: true) ||
        event.logicalKey == LogicalKey.keyQ) {
      shutdownApp();
      return true;
    }
    if (stage == _DashboardStage.idle) {
      if (event.logicalKey == LogicalKey.keyN) {
        widget.onNewProfile();
        return true;
      }
      if (event.logicalKey == LogicalKey.keyS) {
        _beginScan();
        return true;
      }
      if (event.logicalKey == LogicalKey.keyP && profile != null) {
        setState(() => stage = _DashboardStage.policy);
        return true;
      }
      if (event.logicalKey == LogicalKey.comma) {
        widget.onSettings();
        return true;
      }
      if (event.logicalKey == LogicalKey.arrowDown &&
          selected + 1 < widget.profiles.length) {
        setState(() => selected++);
        return true;
      }
      if (event.logicalKey == LogicalKey.arrowUp && selected > 0) {
        setState(() => selected--);
        return true;
      }
    } else if ((stage == _DashboardStage.preparing ||
            stage == _DashboardStage.scanning) &&
        event.logicalKey == LogicalKey.escape) {
      _cancel(false);
      return true;
    }
    return false;
  }
"""
text = text[:start] + replacement + text[end:]
path.write_text(text, encoding='utf-8')

path = Path('lib/src/tui/centra_app.dart')
text = path.read_text(encoding='utf-8')
text = text.replace("import 'ssh_source_picker.dart';\n", '', 1)
path.write_text(text, encoding='utf-8')

path = Path('lib/src/tui/source_change_panel.dart')
text = path.read_text(encoding='utf-8')
text = text.replace("import '../core/docker_browser.dart';\n", '', 1)
path.write_text(text, encoding='utf-8')
