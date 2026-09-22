---
name: markitdown-testing
description: "Write and run tests for MarkItDown converters. Use when: adding tests for a new converter, writing parametrized test vectors, running pytest with hatch, understanding FileTestVector pattern, or debugging test failures. Covers test file layout, FileTestVector dataclass, parametrized test patterns, remote test skipping, and coverage."
---

# MarkItDown Testing

## Quick Reference

### Test File Layout

```
packages/<pkg>/tests/
├── __init__.py
├── _test_vectors.py          # FileTestVector dataclass + test vector lists
├── test_module_vectors.py    # Parametrized tests for convert_local/stream/uri
├── test_module_misc.py       # Non-vector tests (LLM, exiftool, specific formats)
├── test_cli_vectors.py       # CLI tests (stdout, file output, stdin)
├── test_cli_misc.py          # CLI version flag, error handling
└── test_files/               # Test input files
    ├── test.docx
    ├── test.pdf
    └── expected_outputs/     # Expected conversion outputs
```

### FileTestVector

```python
@dataclasses.dataclass(frozen=True, kw_only=True)
class FileTestVector:
    filename: str              # Relative to test_files/
    mimetype: str | None       # Expected MIME type
    charset: str | None        # Expected charset
    url: str | None            # Optional URL for remote tests
    must_include: List[str]    # Strings that MUST appear in output
    must_not_include: List[str]  # Strings that MUST NOT appear
```

### Parametrized Test Pattern

```python
import pytest
from ._test_vectors import MY_TEST_VECTORS

@pytest.mark.parametrize("test_vector", MY_TEST_VECTORS)
def test_convert_local(test_vector):
    markitdown = MarkItDown()
    result = markitdown.convert(
        os.path.join(TEST_FILES_DIR, test_vector.filename)
    )
    for s in test_vector.must_include:
        assert s in result.markdown
    for s in test_vector.must_not_include:
        assert s not in result.markdown
```

### Plugin Test Pattern

```python
def test_converter():
    """Test the converter directly."""
    with open("test_files/test.rtf", "rb") as f:
        converter = MyConverter()
        result = converter.convert(
            file_stream=f,
            stream_info=StreamInfo(mimetype="text/rtf", extension=".rtf"),
        )
        assert "expected text" in result.text_content

def test_markitdown():
    """Test that MarkItDown loads the plugin."""
    md = MarkItDown(enable_plugins=True)
    result = md.convert("test_files/test.rtf")
    assert "expected text" in result.text_content
```

## Running Tests

```bash
# All tests in a package
cd packages/markitdown
hatch test

# Direct pytest
pytest

# Specific test file
pytest tests/test_module_vectors.py

# Specific test function
pytest tests/test_module_vectors.py::test_convert_local -k "test.docx"

# With coverage
hatch test -- --cov=markitdown --cov-report=term

# Type checking
hatch run types:check
```

## Test Conventions

- **Remote tests**: Skip in CI via `os.environ.get("GITHUB_ACTIONS")`
- **LLM tests**: Skip without `OPENAI_API_KEY`
- **Exiftool tests**: Skip if `exiftool` not on PATH
- **Test files**: Go in `test_files/`, expected outputs in `test_files/expected_outputs/`
- **Vector naming**: `GENERAL_TEST_VECTORS`, `DATA_URI_TEST_VECTORS`, etc.
- **Import guard**: Use `if __name__ == "__main__":` pattern for relative imports in test files
