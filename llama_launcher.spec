# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec for Llama Server Launcher (Mac Edition — TorranceTech)
Produces a standalone .app bundle with all dependencies included.
"""

import sys
from pathlib import Path

block_cipher = None

# Absolute path to the project root (where this spec lives)
ROOT = Path(SPECPATH)

a = Analysis(
    [str(ROOT / 'llamacpp-server-launcher.py')],
    pathex=[str(ROOT)],
    binaries=[],
    datas=[
        # Include the config directory (chat templates, version)
        (str(ROOT / 'config'), 'config'),
        # Include images (used in README but not at runtime — kept for completeness)
        (str(ROOT / 'images'), 'images'),
        # Include the modules package explicitly so all submodules are found
        (str(ROOT / 'modules'), 'modules'),
    ],
    hiddenimports=[
        'tkinter',
        'tkinter.ttk',
        'tkinter.messagebox',
        'tkinter.filedialog',
        'tkinter.scrolledtext',
        'tkinter.font',
        'tkinter.colorchooser',
        '_tkinter',
        'requests',
        'requests.adapters',
        'requests.auth',
        'requests.cookies',
        'requests.exceptions',
        'requests.models',
        'requests.sessions',
        'urllib3',
        'certifi',
        'psutil',
        'threading',
        'subprocess',
        'webbrowser',
        'json',
        'pathlib',
        'shlex',
        'shutil',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # Exclude heavy packages not needed at runtime
        'torch',
        'numpy',
        'matplotlib',
        'scipy',
        'pandas',
        'PIL',
        'cv2',
        'sklearn',
        'IPython',
        'jupyter',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='Llama Server Launcher',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    target_arch='arm64',
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='Llama Server Launcher',
)

app = BUNDLE(
    coll,
    name='Llama Server Launcher.app',
    icon='images/app_icon.icns',
    bundle_identifier='com.torrancetech.llama-server-launcher',
    version='1.0.0',
    info_plist={
        'CFBundleDisplayName': 'Llama Server Launcher',
        'CFBundleShortVersionString': '1.0.0',
        'NSHighResolutionCapable': True,
        'NSRequiresAquaSystemAppearance': False,
        'LSMinimumSystemVersion': '12.0',
        'CFBundleDocumentTypes': [],
        'NSHumanReadableCopyright': 'TorranceTech — Fork of llama-server-launcher by thad0ctor',
    },
)
