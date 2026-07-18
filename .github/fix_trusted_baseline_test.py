from pathlib import Path

path = Path('test/trusted_baseline_test.dart')
text = path.read_text(encoding='utf-8')
old = """      algorithms: const <HashAlgorithmDescriptor>[
        HashAlgorithmDescriptor(
          id: 'sha256',
          label: 'SHA-256',
          family: 'SHA-2',
          outputBits: 256,
          security: AlgorithmSecurity.recommended,
        ),
      ],
"""
new = """      algorithms: <HashAlgorithmDescriptor>[
        AlgorithmRegistry().descriptor('sha256'),
      ],
"""
if old not in text:
    raise SystemExit('Trusted baseline descriptor block not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
