---
name: markitdown-converter
description: "Create a new MarkItDown converter or plugin. Use when: adding a new file format converter, creating a plugin package, registering converters via entry points, or understanding the converter interface. Covers DocumentConverter subclass, accepts/convert pattern, plugin registration, pyproject.toml entry points, and priority system."
---

# MarkItDown Converter/Plugin Creation

## Quick Reference

### Converter Interface

```python
from markitdown import DocumentConverter, DocumentConverterResult, StreamInfo

class MyConverter(DocumentConverter):
    ACCEPTED_MIME_TYPE_PREFIXES = ["application/vnd.myformat"]
    ACCEPTED_FILE_EXTENSIONS = [".myf"]

    def accepts(self, file_stream: BinaryIO, stream_info: StreamInfo, **kwargs) -> bool:
        # Check extension first (exact match), then MIME type prefix
        # MUST NOT change stream position — seek back if you read
        extension = (stream_info.extension or "").lower()
        if extension in self.ACCEPTED_FILE_EXTENSIONS:
            return True
        mimetype = (stream_info.mimetype or "").lower()
        return any(mimetype.startswith(p) for p in self.ACCEPTED_MIME_TYPE_PREFIXES)

    def convert(self, file_stream: BinaryIO, stream_info: StreamInfo, **kwargs) -> DocumentConverterResult:
        # Read the stream and produce Markdown
        content = file_stream.read()
        markdown = self._do_conversion(content)
        return DocumentConverterResult(markdown=markdown)
```

### Plugin Package Structure

```
packages/markitdown-myplugin/
├── pyproject.toml
└── src/
    └── markitdown_myplugin/
        ├── __init__.py
        ├── __about__.py
        ├── _plugin.py          # register_converters() + converter class(es)
        └── py.typed
```

### pyproject.toml (plugin)

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "markitdown-myplugin"
dynamic = ["version"]
requires-python = ">=3.10"
dependencies = ["markitdown>=0.1.0"]

[project.entry-points."markitdown.plugin"]
myplugin = "markitdown_myplugin"

[tool.hatch.version]
path = "src/markitdown_myplugin/__about__.py"
```

### _plugin.py Template

```python
__plugin_interface_version__ = 1

def register_converters(markitdown: MarkItDown, **kwargs):
    markitdown.register_converter(MyConverter())
```

### Priority System

| Constant | Value | Use Case |
|---|---|---|
| `PRIORITY_SPECIFIC_FILE_FORMAT` | `0.0` | Default for format-specific converters |
| `PRIORITY_GENERIC_FILE_FORMAT` | `10.0` | Catch-all (PlainText, HTML, ZIP) |
| Custom (e.g., OCR) | `-1.0` | Replace built-in converters |

Lower = tried first. Use `markitdown.register_converter(converter, priority=N)`.

## Optional Dependencies Pattern

```python
_dependency_exc_info = None
try:
    import some_package
except ImportError:
    _dependency_exc_info = sys.exc_info()

# In convert():
if _dependency_exc_info is not None:
    raise MissingDependencyException(
        "some_package", "pip install markitdown[myfeature]"
    ) from _dependency_exc_info[1]
```

## HTML-as-Intermediate Pattern

For formats that have an HTML representation, convert to HTML first, then use `_CustomMarkdownify`:

```python
from markitdown.converters import HtmlConverter

class MyConverter(DocumentConverter):
    def convert(self, file_stream, stream_info, **kwargs):
        html = self._extract_html(file_stream)
        return HtmlConverter().convert_string(html, **kwargs)
```

## Testing

- Test files go in `packages/<pkg>/tests/test_files/`
- Expected outputs in `test_files/expected_outputs/`
- Use `FileTestVector` for parametrized tests
- See `packages/markitdown-sample-plugin/tests/` for a minimal plugin test example
