
# CV Extractor Web App (Notebook → Web UI)

This project turns your **Jupyter notebook model** (that extracts CV fields using a HuggingFace LLM + LangChain) into a **polished web app**:

- **FastAPI** backend with two endpoints:
  - `POST /extract/text` — send raw text
  - `POST /extract/pdf` — upload a PDF
- **Beautiful Frontend** (HTML/CSS/JS) with file upload, live progress, and structured cards.

> Default model: **`mistralai/Mistral-Nemo-Instruct-2407`**. You can change it via `MODEL_NAME` env var.

---

## 1) Install

Create a virtual environment (recommended), then:

```bash
cd backend
pip install -r requirements.txt
```

> If you're using a **private** model on Hugging Face, set your token:
> ```bash
> setx HUGGINGFACEHUB_API_TOKEN "hf_xxx"      # Windows PowerShell
> export HUGGINGFACEHUB_API_TOKEN=hf_xxx       # macOS/Linux
> ```

Optionally choose a different model:
```bash
setx MODEL_NAME "mistralai/Mistral-7B-Instruct-v0.2"  # Windows
export MODEL_NAME="mistralai/Mistral-7B-Instruct-v0.2" # macOS/Linux
```

> **Note:** Large models require GPU (CUDA). On CPU, inference will be slow.


## 2) Run the backend

```bash
python app_api.py
```
You should see the server on `http://127.0.0.1:8000`  
Health check: open `http://127.0.0.1:8000/health`

Endpoints:
- `POST /extract/pdf` (multipart form-data, field name `file`)
- `POST /extract/text` (JSON: `{ "text": "..." }`)


## 3) Run the frontend

Open `frontend/index.html` in your browser.  
If your backend is on a different host/port, edit `API_BASE` at the top of `frontend/app.js`.


## 4) Deploying

- **Render/Railway/Fly.io**: start command:
  ```bash
  uvicorn app_api:app --host 0.0.0.0 --port $PORT
  ```
- **Docker** (optional):
  ```dockerfile
  FROM python:3.11-slim
  WORKDIR /app
  COPY backend/requirements.txt ./
  RUN pip install --no-cache-dir -r requirements.txt
  COPY backend ./backend
  WORKDIR /app/backend
  ENV PORT=8000
  CMD ["uvicorn", "app_api:app", "--host", "0.0.0.0", "--port", "8000"]
  ```

---

## How it works (summary)

- `model_logic.py` loads the HF model + tokenizer once, defines a **schema** using LangChain (`fullname`, `email`, `education`, `skills`, `experience`), builds a **prompt** with clear instructions and example, then calls `generate()` to obtain output, and robustly **parses JSON** (with fallbacks if the LLM adds extra text).
- `/extract/pdf` saves the uploaded PDF to a temp file, extracts text with **LangChain's `PyPDFLoader`**, and runs inference through the same function.
- Frontend presents the results in **cards** and a **JSON** view.


## Troubleshooting

- **Slow / OOM**: use a **smaller model**, e.g. `mistralai/Mistral-7B-Instruct-v0.2` or any instruct model you have cached; or enable GPU.
- **HF auth errors**: set `HUGGINGFACEHUB_API_TOKEN`.
- **CORS**: if serving the UI from another origin, CORS is already enabled; restrict `allow_origins` in `app_api.py` for production.
- **Parsing errors**: the code auto-falls back to finding a JSON object in the text.

---

© You — happily shipped 🎉
