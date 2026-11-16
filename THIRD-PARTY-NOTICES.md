# Сторонние компоненты

Архив релиза КРАБа содержит сторонние программы и библиотеки. Их лицензии и авторские права
принадлежат соответствующим правообладателям. Полные тексты лицензий — в указанных файлах внутри архива.

## Среда выполнения

| Компонент | Лицензия | Где текст лицензии |
|---|---|---|
| Python 3.13 (переносимая сборка, python-build-standalone) | PSF License | `bin\python\LICENSE.txt` |
| Tesseract OCR 5 (сборка UB Mannheim) и языковые данные `rus`, `eng`, `osd` | Apache License 2.0 | `bin\Tesseract-OCR\doc\` |

## Библиотеки Python

Установлены в `bin\python\Lib\site-packages`; текст лицензии каждой — в её папке `*.dist-info`.

| Библиотека | Лицензия |
|---|---|
| fastapi, starlette, uvicorn, h11, anyio, sniffio | MIT / BSD-3 |
| openai, httpx2, httpcore2, jiter | Apache 2.0 / BSD-3 / MIT |
| pydantic, pydantic_core, annotated_types, annotated_doc, typing_extensions, typing_inspection | MIT / PSF |
| python-dotenv | BSD-3 |
| python-docx, python-pptx, lxml, xlsxwriter, openpyxl, et_xmlfile, xlrd | MIT / BSD-3 |
| pypdf | BSD-3 |
| pandas, numpy, python-dateutil, tzdata | BSD-3 / Apache 2.0 |
| matplotlib, contourpy, cycler, fonttools, kiwisolver, pyparsing, pillow | PSF-based / BSD / MIT / HPND |
| requests, urllib3, certifi, charset_normalizer, idna, truststore | Apache 2.0 / MIT / MPL 2.0 / BSD |
| pytesseract | Apache 2.0 |
| olefile | BSD-2 |
| click, packaging, opentelemetry-api, pip | BSD-3 / Apache 2.0 / MIT |

Точный перечень версий — в папках `*.dist-info`. Если вы обнаружили ошибку в этом списке, сообщите через Issues.
