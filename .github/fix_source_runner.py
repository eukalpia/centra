from pathlib import Path

path = Path('lib/src/core/source.dart')
text = path.read_text(encoding='utf-8')
old = '    return runner.runCancellable(\n'
new = '    return (runner as CancellableCommandRunner).runCancellable(\n'
if old not in text:
    raise SystemExit('Cancellable runner call not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
