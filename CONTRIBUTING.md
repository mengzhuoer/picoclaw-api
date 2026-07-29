# 🤝 Contributing to PicoClaw API

Thank you for your interest in contributing! We welcome contributions of all kinds.

## How to Contribute

### Reporting Issues

- Use the [GitHub Issues](https://github.com/YOUR_USERNAME/picoclaw-api/issues) page
- Describe the issue clearly, including:
  - Your Raspberry Pi model and OS version
  - What you expected to happen
  - What actually happened
  - Relevant logs (`journalctl -u picoclaw-api --no-pager -n 20`)

### Submitting Pull Requests

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/your-feature-name`
3. **Commit** your changes: `git commit -m 'Add your feature'`
4. **Push** to the branch: `git push origin feature/your-feature-name`
5. **Open** a Pull Request

### Coding Style

- Python: Follow [PEP 8](https://peps.python.org/pep-0008/)
- Shell: Use 4-space indentation
- Commit messages: Use present tense ("Add feature" not "Added feature")

### Development Setup

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/picoclaw-api.git
cd picoclaw-api

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r picoclaw-api/app/requirements.txt

# Run the API locally (without systemd)
cd picoclaw-api/app
python -m uvicorn main:app --host 0.0.0.0 --port 9000 --reload
```

## Project Structure

```
picoclaw-api/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI routes
│   ├── provider_manager.py  # Provider management
│   ├── config.py            # Configuration
│   └── providers/
│       ├── __init__.py      # Base provider class
│       ├── local_llama.py   # Local llama.cpp provider
│       └── cloud_apis.py    # Cloud API providers
├── static/                  # CSS/JS
├── templates/               # HTML templates
└── install.sh               # Installation script
```

## Feature Ideas

- [ ] Support for more cloud API providers
- [ ] Model quantization tools
- [ ] Performance monitoring dashboard
- [ ] Multi-model concurrent inference
- [ ] Voice input/output support
- [ ] Docker support

## Code of Conduct

Be kind and respectful to other contributors. We're all here to learn and build something great together.

---

**🦞 Thank you for contributing!**
