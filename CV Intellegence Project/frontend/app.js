
// Change this if your backend is hosted elsewhere
const API_BASE = "http://127.0.0.1:8000";

const dropzone = document.getElementById('dropzone');
const fileInput = document.getElementById('fileInput');
const browseBtn = document.getElementById('browseBtn');
const selectedName = document.getElementById('selectedName');
const extractBtn = document.getElementById('extractBtn');
const statusEl = document.getElementById('status');
const cards = document.getElementById('cards');
const jsonOut = document.getElementById('jsonOut');

let selectedFile = null;

// --- Dropzone interactions ---
dropzone.addEventListener('dragover', (e) => {
  e.preventDefault();
  dropzone.classList.add('dragover');
});
dropzone.addEventListener('dragleave', () => dropzone.classList.remove('dragover'));
dropzone.addEventListener('drop', (e) => {
  e.preventDefault();
  dropzone.classList.remove('dragover');
  if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
    const f = e.dataTransfer.files[0];
    setFile(f);
  }
});
browseBtn.addEventListener('click', (e) => {
  e.preventDefault();
  fileInput.click();
});
fileInput.addEventListener('change', () => {
  if (fileInput.files && fileInput.files.length > 0) {
    setFile(fileInput.files[0]);
  }
});

function setFile(f) {
  if (!f || !f.name.toLowerCase().endsWith('.pdf')) {
    alert('Please choose a PDF file.');
    return;
  }
  selectedFile = f;
  selectedName.textContent = f.name + ' (' + Math.round(f.size/1024) + ' KB)';
  extractBtn.disabled = false;
  statusEl.textContent = '';
  clearResults();
}

function clearResults() {
  cards.innerHTML = '';
  jsonOut.textContent = '';
}

extractBtn.addEventListener('click', async () => {
  if (!selectedFile) return;
  extractBtn.disabled = true;
  statusEl.textContent = 'Uploading & extracting...';
  clearResults();

  try {
    const form = new FormData();
    form.append('file', selectedFile);
    const res = await fetch(`${API_BASE}/extract/pdf`, {
      method: 'POST',
      body: form
    });
    if (!res.ok) {
      const detail = await res.json().catch(() => ({}));
      throw new Error(detail.detail || `HTTP ${res.status}`);
    }
    const data = await res.json();
    renderResults(data);
    statusEl.textContent = 'Done ✅';
  } catch (err) {
    console.error(err);
    statusEl.textContent = 'Error: ' + err.message;
  } finally {
    extractBtn.disabled = false;
  }
});

function renderResults(data) {
  // JSON pretty
  jsonOut.textContent = JSON.stringify(data, null, 2);

  // Cards
  cards.appendChild(card('Full Name', data.fullname || '—'));
  cards.appendChild(card('Email', data.email || '—'));
  cards.appendChild(card('Skills', data.skills || '—'));
  cards.appendChild(card('Experience', data.experience || '—'));
  cards.appendChild(card('Education', data.education || '—'));
}

function card(title, content) {
  const el = document.createElement('div');
  el.className = 'card';
  const h = document.createElement('h3');
  h.textContent = title;
  const p = document.createElement('p');
  p.textContent = content;
  el.appendChild(h);
  el.appendChild(p);
  return el;
}
