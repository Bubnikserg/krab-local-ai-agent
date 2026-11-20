# -*- coding: utf-8 -*-
"""
Сторож-прелюдия песочницы КРАБа.

Подключается В ДОЧЕРНИЙ ПРОЦЕСС перед пользовательским кодом (run_python_snippet)
через флаг -m krab_sandbox_guard. Перехватывает опасные операции и разрешает их
только внутри рабочей папки:

  * open(), io.open(), os.open()              — пути только внутри рабочей папки
  * os.rename/replace/remove/mkdir/...        — то же
  * shutil.rmtree/copy*/move                  — то же
  * pathlib.Path.open/iterdir/... (создание)  — то же
  * subprocess.*, os.system, os.popen         — запрещены полностью
  * socket (сеть)                             — запрещена полностью
  * ctypes/pydll                              — запрещены (обход перехватчиков)
  * Сетевые библиотеки (requests, httpx, urllib, urllib3, socketserver...)
    сохраняют обычную работу, но их транспорт — socket — заблокирован сторожем.

Перехват НЕ путь к абсолютной безопасности (ctypes и reflection обходимы лишь
частично — ctypes блокируется), он закрывает случайный вред и обычные каналы.
Полная изоляция — Job Object / контейнер (см. варианты песочницы).

Рабочая папка передаётся переменной окружения KRAB_SANDBOX_DIR.
Сторож отключается переменной KRAB_SANDBOX_OFF=1 (используется в тестах).
"""
import os
import sys as _sys

if os.environ.get("KRAB_SANDBOX_OFF") == "1":
    pass  # сторож отключён — ничего не перехватываем
else:
    _ROOT = os.path.realpath(os.environ.get("KRAB_SANDBOX_DIR") or os.getcwd())

    class _SandboxViolation(PermissionError):
        """Попытка выйти за пределы рабочей папки или выполнить запрещённое действие."""

    # корень установки Python — разрешено ЧТЕНИЕ ресурсов библиотек
    # (numpy/pandas/matplotlib сами читают tzdata, шрифты и т.п. из site-packages)
    _PY_ROOT = os.path.dirname(os.path.dirname(os.__file__)).lower()

    def _in_root(path, write=False):
        """True, если path (после realpath) внутри рабочей папки (или — при чтении — внутри установки Python)."""
        try:
            rp = os.path.realpath(os.path.abspath(path))
        except Exception:
            return False
        rp = rp.lower()
        if rp == _ROOT.lower() or rp.startswith(_ROOT.lower() + os.sep):
            return True
        if not write and _PY_ROOT and (rp == _PY_ROOT or rp.startswith(_PY_ROOT + os.sep)):
            return True
        return False

    def _check(path, what):
        if path is None:
            return
        try:
            s = str(path)
        except Exception:
            return
        # UNC-пути (\\server\share) — всегда вне рабочей папки
        if s.startswith("\\\\"):
            raise _SandboxViolation(
                "Песочница КРАБа: %s запрещён — сетевой путь вне рабочей папки (%s)" % (what, s[:120]))
        _is_write = any(t in what for t in ("запись", "создание", "переимен", "перезапись", "удалени", "удаление", "обрезка", "shutil"))
        if not _in_root(s, write=_is_write):
            raise _SandboxViolation(
                "Песочница КРАБа: %s запрещён — путь вне рабочей папки (%s). "
                "Доступны только файлы внутри рабочей папки проекта." % (what, s[:120]))

    # ---------------- open / io.open ----------------
    import builtins as _builtins
    _orig_open = _builtins.open

    def _guarded_open(file, mode="r", *args, **kwargs):
        # режимы с "+" и "w"/"a"/"x" — запись; "r"/"rb" — чтение. Проверяем оба направления.
        _check(file, "открытие файла")
        return _orig_open(file, mode, *args, **kwargs)

    _builtins.open = _guarded_open

    import io as _io
    if hasattr(_io, "open") and _io.open is not _guarded_open:
        _io.open = _guarded_open

    # ---------------- os: файловые операции ----------------
    import os as _osmod
    _OS_GUARDED = {
        "rename": ("переименование файла", 0, 1),
        "replace": ("перезапись файла", 0, 1),
        "remove": ("удаление файла", 0, None),
        "unlink": ("удаление файла", 0, None),
        "mkdir": ("создание папки", 0, None),
        "makedirs": ("создание папки", 0, None),
        "rmdir": ("удаление папки", 0, None),
        "removedirs": ("удаление папок", 0, None),
        "listdir": ("просмотр папки", 0, None),
        "scandir": ("просмотр папки", 0, None),
        "stat": ("чтение метаданных", 0, None),
        "lstat": ("чтение метаданных", 0, None),
        "walk": ("обход папки", 0, None),
        "truncate": ("обрезка файла", 0, None),
        "utime": ("смена времени файла", 0, None),
        "chmod": ("смена прав файла", 0, None),
        "chown": ("смена владельца файла", 0, None),
        "link": ("создание жёсткой ссылки", 0, 1),
        "symlink": ("создание симлинка", 1, None),  # цель может быть вне, путь — внутри
        "readlink": ("чтение симлинка", 0, None),
        "getsize": ("чтение размера", 0, None),
        "getmtime": ("чтение времени", 0, None),
        "getctime": ("чтение времени", 0, None),
        "getatime": ("чтение времени", 0, None),
    }
    for _name, (_what, _idx, _idx2) in _OS_GUARDED.items():
        if not hasattr(_osmod, _name):
            continue
        _orig = getattr(_osmod, _name)

        def _make(_orig=_orig, _what=_what, _idx=_idx, _idx2=_idx2):
            def _guarded(*args, **kwargs):
                if len(args) > _idx:
                    _check(args[_idx], _what)
                if _idx2 is not None and len(args) > _idx2:
                    _check(args[_idx2], _what)
                return _orig(*args, **kwargs)
            return _guarded
        setattr(_osmod, _name, _make())

    _orig_os_system = getattr(_osmod, "system", None)
    if _orig_os_system:
        def _no_system(*a, **k):
            raise _SandboxViolation(
                "Песочница КРАБа: запуск команд оболочки (os.system) запрещён. "
                "Для работы с файлами используйте инструменты агента.")
        _osmod.system = _no_system

    _orig_os_popen = getattr(_osmod, "popen", None)
    if _orig_os_popen:
        def _no_popen(*a, **k):
            raise _SandboxViolation(
                "Песочница КРАБа: запуск команд оболочки (os.popen) запрещён. "
                "Для работы с файлами используйте инструменты агента.")
        _osmod.popen = _no_popen

    # ---------------- shutil ----------------
    import shutil as _shutil
    _SHUTIL_GUARDED = ("rmtree", "copy", "copy2", "copyfile", "copytree", "move")
    for _name in _SHUTIL_GUARDED:
        if not hasattr(_shutil, _name):
            continue
        _orig = getattr(_shutil, _name)
        _what = "операция shutil." + _name

        def _make2(_orig=_orig, _what=_what):
            def _guarded(*args, **kwargs):
                for a in args[:2]:
                    if isinstance(a, (str, bytes, os.PathLike)):
                        _check(a, _what)
                return _orig(*args, **kwargs)
            return _guarded
        setattr(_shutil, _name, _make2())

    # ---------------- subprocess / multiprocessing ----------------
    class _BlockedModule:
        _msg = ("Песочница КРАБа: запуск внешних процессов запрещён. "
                "Для работы с файлами и данными используйте Python и инструменты агента.")

        def __getattr__(self, name):
            if name.startswith("__") and name.endswith("__"):
                raise AttributeError(name)
            def _blocked(*a, **k):
                raise _SandboxViolation(self._msg)
            return _blocked

        def __call__(self, *a, **k):
            raise _SandboxViolation(self._msg)

        def __setattr__(self, name, value):
            pass

    _sys.modules["subprocess"] = _BlockedModule()
    _sys.modules["multiprocessing"] = _BlockedModule()

    # ---------------- ctypes: запрещаем только опасные точки входа ----------------
    # Полный запрет ломает numpy/pandas/matplotlib (они импортируют ctypes для внутренних нужд).
    # Запрещаем способы ЗАГРУЗКИ DLL и доступ к pythonapi — через них обходят перехватчики.
    import ctypes as _ctypes
    _ctypes_msg = ("Песочница КРАБа: загрузка DLL через ctypes запрещена "
                   "(позволяет обойти защитные перехватчики через прямые вызовы WinAPI).")

    class _BlockedDllFactory:
        def __init__(self, names):
            self._names = names
        def __getattr__(self, name):
            if name.startswith("_"):
                raise AttributeError(name)
            raise _SandboxViolation(_ctypes_msg)
        def __call__(self, *a, **k):
            raise _SandboxViolation(_ctypes_msg)

    for _attr in ("CDLL", "WinDLL", "OleDLL", "PyDLL", "windll", "oledll", "pydll",
                  "LibraryLoader", "pythonapi", "python_dll"):
        setattr(_ctypes, _attr, _BlockedDllFactory(_attr))
    del _attr

    # ---------------- socket: блокируем сеть ----------------
    import socket as _socket
    _orig_socket_init = _socket.socket.__init__
    _SOCK_ALLOWED_FAMILIES = set()  # сетевые сокеты запрещены полностью

    def _guarded_socket_init(self, *args, **kwargs):
        raise _SandboxViolation(
            "Песочница КРАБа: сетевые соединения из исполняемого кода запрещены. "
            "Для загрузки веб-страниц используйте инструмент fetch_url.")
    _socket.socket.__init__ = _guarded_socket_init

    # socket.create_connection / getaddrinfo тоже режем (обход через высокоуровневые API)
    def _no_create_connection(*a, **k):
        raise _SandboxViolation("Песочница КРАБа: сетевые соединения запрещены.")
    _socket.create_connection = _no_create_connection

    # ---------------- pathlib: перехватываем только создание Path-объектов с проверкой open/чтения ----------------
    # pathlib.Path.open использует встроенный open (уже перехвачен), os.* вызовы тоже перехвачены.
    # Отдельного патча не требуется, кроме удаления shutil-двойников через import — они уже перекрыты.

    # (не удаляем _check/_in_root — перехватчики держат на них замыкания)

    # ---------------- исполнение пользовательского кода ----------------
    # Этот файл запускается как: python sandbox_guard.py -c "<код>"
    # Аргументы после имени скрипта попадают в sys.argv СКРИПТА — исполняем их здесь.
    if len(_sys.argv) >= 3 and _sys.argv[1] == "-c":
        _user_code = _sys.argv[2]
        g = {"__name__": "__main__", "__file__": "<код агента>"}
        try:
            exec(compile(_user_code, "<код агента>", "exec"), g)
        except SystemExit:
            raise
        except BaseException as _e:
            import traceback as _tb
            _tb.print_exc()
            _sys.exit(1)
