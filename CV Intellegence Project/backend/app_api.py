
import os
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

from model_logic import extract_from_text, extract_from_pdf_bytes

app = FastAPI(title="CV Extractor API", version="1.0.0")

# CORS for local dev + web UI
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class TextIn(BaseModel):
    text: str

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/extract/text")
def extract_text(payload: TextIn):
    if not payload.text or not payload.text.strip():
        raise HTTPException(status_code=400, detail="Empty text")
    data = extract_from_text(payload.text)
    return JSONResponse(data)

@app.post("/extract/pdf")
async def extract_pdf(file: UploadFile = File(...)):
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Please upload a PDF file.")
    pdf_bytes = await file.read()
    if not pdf_bytes:
        raise HTTPException(status_code=400, detail="Empty file")
    data = extract_from_pdf_bytes(pdf_bytes)
    return JSONResponse(data)

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run("app_api:app", host="0.0.0.0", port=port, reload=False)





