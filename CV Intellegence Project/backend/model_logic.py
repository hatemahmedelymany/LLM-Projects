
import os
import re
import json
import tempfile
from typing import Dict, Any, Optional

from dotenv import load_dotenv
from pathlib import Path

# PDF loader
from langchain_community.document_loaders import PyPDFLoader
from langchain.output_parsers import StructuredOutputParser, ResponseSchema
from langchain.prompts import PromptTemplate

# NEW: Hugging Face Inference API client (no local weights)
from huggingface_hub import InferenceClient

# --- load .env from backend folder explicitly ---
ENV_PATH = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=ENV_PATH)

HF_TOKEN = os.getenv("HUGGINGFACEHUB_API_TOKEN")
MODEL_NAME = os.getenv("MODEL_NAME") or "mistralai/Mistral-Nemo-Instruct-2407"

# Helpful guardrails
if not HF_TOKEN:
    raise RuntimeError(
        "HUGGINGFACEHUB_API_TOKEN is not set. Put it in backend/.env or your environment."
    )

# Log once at import time so you can confirm it's correct
print(f"[CFG] Using MODEL_NAME={MODEL_NAME}")

# Create a single Inference API client (NO local download)
client = InferenceClient(model=MODEL_NAME, token=HF_TOKEN)

def _generate_text(
    prompt: str,
    max_new_tokens: int = 768,
    temperature: float = 0.7,
    top_p: float = 0.95,
) -> str:
    """
    Generate text using Hugging Face Inference API.
    Always runs in the cloud (no local model downloads).
    """

    response = client.chat.completions.create(
        model=MODEL_NAME,
        messages=[{"role": "user", "content": prompt}],
        max_tokens=max_new_tokens,
        temperature=temperature,
        top_p=top_p,
    )

    # return only the text content
    return response.choices[0].message["content"]


# -------------------- Prompt & Parser --------------------
# Define the schema we want to extract
name_schema = ResponseSchema(
    name="fullname",
    description="The person's full name."
)
email_schema = ResponseSchema(
    name="email",
    description="The best email address found."
)
education_schema = ResponseSchema(
    name="education",
    description="Education section as a clean multiline string."
)
skills_schema = ResponseSchema(
    name="skills",
    description="Skills as a clean multiline string or comma-separated list."
)
experience_schema = ResponseSchema(
    name="experience",
    description="Professional experience as a clean multiline string."
)

response_schemas = [name_schema, email_schema, education_schema, skills_schema, experience_schema]
output_parser = StructuredOutputParser.from_response_schemas(response_schemas)
format_instructions = output_parser.get_format_instructions()

# A helpful priming example (shortened) to steer the model to output the schema cleanly
EXTRACTION_TEMPLATE = """You are a smart assistant that extracts data from a user's CV/resume text.

Extract the following fields and return ONLY valid JSON using this schema:
{format_instructions}

Be concise and keep original bullet points if present. If a field is missing, return an empty string for it.

Example Input:
"HATEM AHMED MOHAMED
■ hatem.elymany.34@gmail.com | ■ +20 101 217 5836 | ■ Bani Suef, Egypt
PROFESSIONAL SUMMARY
Recent Software Engineering graduate...
PROFESSIONAL EXPERIENCE
IT Support – ...
PROJECTS
• Mobile Price Classification ...
SKILLS
• Python • Machine Learning • ...
EDUCATION
Bani Suef Technological University ...
LANGUAGES
• Arabic: Native • English: Proficient"

Now extract from the following input:
"{user_input}"
"""


def _extract_json_from_text(text: str) -> Optional[str]:
    """Try to pull a JSON object from raw model text."""
    match = re.search(r'\{.*\}', text, flags=re.DOTALL)
    if match:
        return match.group(0)
    return None

def parse_with_fallback(raw_text: str) -> Dict[str, Any]:
    """Parse the model output safely with fallbacks."""
    try:
        return output_parser.parse(raw_text)
    except Exception:
        maybe_json = _extract_json_from_text(raw_text)
        if maybe_json:
            try:
                return json.loads(maybe_json)
            except Exception:
                pass
        return {"raw": raw_text}

def extract_from_text(text: str) -> Dict[str, Any]:
    """Core function: takes plain text of a CV and returns structured fields dict."""
    prompt = PromptTemplate(
        template=EXTRACTION_TEMPLATE,
        input_variables=["user_input"],
        partial_variables={"format_instructions": format_instructions},
    ).format(user_input=text)

    raw = _generate_text(prompt)
    data = parse_with_fallback(raw)

    # Guarantee all keys exist
    for key in ["fullname", "email", "education", "skills", "experience"]:
        data.setdefault(key, "")
    return data

def extract_from_pdf_bytes(pdf_bytes: bytes) -> Dict[str, Any]:
    """
    Loads a PDF from bytes, extracts text (via LangChain's PyPDFLoader), and runs the model.
    Windows-friendly: do NOT auto-delete while loader re-opens the file.
    """
    import os as _os
    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
        tmp.write(pdf_bytes)
        tmp_path = tmp.name

    try:
        loader = PyPDFLoader(tmp_path)
        docs = loader.load()
        text = "\n\n".join([d.page_content for d in docs])
        return extract_from_text(text)
    finally:
        try:
            _os.remove(tmp_path)
        except OSError:
            pass
