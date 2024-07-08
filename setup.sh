#!/bin/bash

# Create project structure
mkdir -p frontend/src frontend/public backend/utils data/sample_docs
touch frontend/src/App.svelte frontend/src/main.js frontend/src/Search.svelte frontend/public/favicon.ico frontend/index.html frontend/package.json frontend/vite.config.js backend/main.py backend/smart_index.py backend/requirements.txt Dockerfile docker-compose.yml README.md

# Frontend setup
cat << EOT > frontend/package.json
{
  "name": "smart-index-frontend",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "devDependencies": {
    "@sveltejs/vite-plugin-svelte": "^2.0.3",
    "svelte": "^3.57.0",
    "vite": "^4.3.2"
  }
}
EOT

cat << EOT > frontend/vite.config.js
import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

export default defineConfig({
  plugins: [svelte()],
  server: {
    host: '0.0.0.0',
    port: 5173
  }
})
EOT

cat << EOT > frontend/src/main.js
import App from './App.svelte'

const app = new App({
  target: document.body
})

export default app
EOT

cat << EOT > frontend/src/App.svelte
<script>
  import Search from './Search.svelte';
</script>

<main>
  <h1>SmartIndex for Edinfinite</h1>
  <Search />
</main>

<style>
  main {
    text-align: center;
    padding: 1em;
    max-width: 240px;
    margin: 0 auto;
  }

  h1 {
    color: #ff3e00;
    text-transform: uppercase;
    font-size: 4em;
    font-weight: 100;
  }

  @media (min-width: 640px) {
    main {
      max-width: none;
    }
  }
</style>
EOT

cat << EOT > frontend/src/Search.svelte
<script>
  let query = '';
  let results = [];
  let isLoading = false;

  async function handleSubmit() {
    isLoading = true;
    const response = await fetch('http://localhost:8000/search', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query }),
    });
    results = await response.json();
    isLoading = false;
  }
</script>

<form on:submit|preventDefault={handleSubmit}>
  <input bind:value={query} placeholder="What do you want to learn about?">
  <button type="submit" disabled={isLoading}>
    {isLoading ? 'Searching...' : 'Search'}
  </button>
</form>

{#if results.length > 0}
  <h2>Here's what I found:</h2>
  {#each results as result}
    <div class="result">
      <p>{result.explanation}</p>
      <p>{result.content.slice(0, 200)}...</p>
      {#if result.image_path}
        <img src={result.image_path} alt="Related image" />
      {/if}
    </div>
  {/each}
{/if}

<style>
  form {
    margin-bottom: 20px;
  }

  input {
    width: 70%;
    padding: 10px;
    font-size: 16px;
  }

  button {
    padding: 10px 20px;
    font-size: 16px;
    background-color: #4CAF50;
    color: white;
    border: none;
    cursor: pointer;
  }

  button:disabled {
    background-color: #cccccc;
    cursor: not-allowed;
  }

  .result {
    background-color: white;
    padding: 15px;
    margin-bottom: 15px;
    border-radius: 5px;
    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
    text-align: left;
  }

  img {
    max-width: 100%;
    height: auto;
    margin-top: 10px;
  }
</style>
EOT

cat << EOT > frontend/index.html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Smart Index for Kids</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.js"></script>
  </body>
</html>
EOT

# Backend setup
cat << EOT > backend/requirements.txt
fastapi
uvicorn
chromadb
sentence-transformers
python-multipart
python-docx
openpyxl
pdf2image
pytesseract
Pillow
EOT

cat << EOT > backend/main.py
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from smart_index import SmartIndex
import shutil
import os

app = FastAPI()

# Setup CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

smart_index = SmartIndex("./data/sample_docs")
smart_index.build_index()

class Query(BaseModel):
    query: str

@app.post("/search")
async def search(query: Query):
    results = smart_index.search(query.query)
    return results

@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    file_path = f"./data/sample_docs/{file.filename}"
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    smart_index.add_document(file_path)
    return {"filename": file.filename, "status": "File uploaded and indexed successfully"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOT

cat << EOT > backend/smart_index.py
import os
import chromadb
from chromadb.config import Settings
from chromadb.utils import embedding_functions
from utils.document_processor import process_document

class SmartIndex:
    def __init__(self, root_dir):
        self.root_dir = root_dir
        self.chroma_client = chromadb.Client(Settings(persist_directory="./chroma_db"))
        self.collection = self.chroma_client.get_or_create_collection(name="kids_docs")
        self.embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(model_name="all-MiniLM-L6-v2")

    def build_index(self):
        for root, _, files in os.walk(self.root_dir):
            for file in files:
                file_path = os.path.join(root, file)
                self.add_document(file_path)

    def add_document(self, file_path):
        content, metadata = process_document(file_path)
        if content:
            self.collection.add(
                documents=[content],
                metadatas=[metadata],
                ids=[file_path]
            )

    def search(self, query, k=3):
        results = self.collection.query(
            query_texts=[query],
            n_results=k
        )
        
        formatted_results = []
        for i, doc in enumerate(results['documents'][0]):
            formatted_results.append({
                "explanation": f"I found this information about '{query}' in a file called '{os.path.basename(results['ids'][0][i])}'. It talks about {query} in a way that's easy for kids to understand!",
                "content": doc,
                "image_path": results['metadatas'][0][i].get('image_path')
            })
        
        return formatted_results
EOT

mkdir -p backend/utils
cat << EOT > backend/utils/document_processor.py
import os
from docx import Document
from openpyxl import load_workbook
import PyPDF2
from pdf2image import convert_from_path
import pytesseract
from PIL import Image

def process_document(file_path):
    _, file_extension = os.path.splitext(file_path)
    file_extension = file_extension.lower()

    if file_extension == '.txt':
        return process_text(file_path)
    elif file_extension == '.docx':
        return process_docx(file_path)
    elif file_extension in ['.xls', '.xlsx']:
        return process_excel(file_path)
    elif file_extension == '.pdf':
        return process_pdf(file_path)
    elif file_extension in ['.png', '.jpg', '.jpeg']:
        return process_image(file_path)
    else:
        print(f"Unsupported file type: {file_extension}")
        return None, None

def process_text(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    return content, {"source": file_path}

def process_docx(file_path):
    doc = Document(file_path)
    content = "\n".join([paragraph.text for paragraph in doc.paragraphs])
    return content, {"source": file_path}

def process_excel(file_path):
    wb = load_workbook(file_path)
    content = []
    for sheet in wb.sheetnames:
        ws = wb[sheet]
        for row in ws.iter_rows(values_only=True):
            content.append(" ".join(str(cell) for cell in row if cell))
    return "\n".join(content), {"source": file_path}

def process_pdf(file_path):
    with open(file_path, 'rb') as file:
        reader = PyPDF2.PdfReader(file)
        content = []
        for page in reader.pages:
            content.append(page.extract_text())
    return "\n".join(content), {"source": file_path}

def process_image(file_path):
    image = Image.open(file_path)
    content = pytesseract.image_to_string(image)
    return content, {"source": file_path, "image_path": file_path}
EOT

# Docker setup
cat << EOT > Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY backend/requirements.txt .
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        tesseract-ocr \
        libtesseract-dev \
        poppler-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOT

cat << EOT > docker-compose.yml
version: '3'
services:
  backend:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
      - ./chroma_db:/app/chroma_db
  frontend:
    image: node:14
    working_dir: /app
    volumes:
      - ./frontend:/app
    ports:
      - "5173:5173"
    command: bash -c "npm install && npm run dev -- --host 0.0.0.0"
EOT

# README
cat << EOT > README.md
# SmartIndex for the kids

This project is a kid-friendly Smart Index Vector Search System using Svelte with Vite for the frontend, Python FastAPI for the backend, and ChromaDB for vector storage and retrieval.

## Features

- Search through various document types (TXT, DOCX, XLS, XLSX, PDF, PNG, JPG)
- Citizen-friendly interface and explanations
- Easy document upload and indexing

## Setup

1. Install Docker and Docker Compose on your system.
2. Clone this repository and navigate to the project root.
3. Run \`docker-compose up --build\` to start the application.
4. Access the frontend at http://localhost:5173

## Usage

- Use the search bar to ask questions or look for information.
- Upload new documents using the upload feature (to be implemented in the frontend).

## Adding New Documents

To add new documents:
1. Place them in the \`data/sample_docs\` directory.
2. Restart the Docker containers to reindex the new documents.

## Supported File Types

- Text files (.txt)
- Word documents (.docx)
- Excel spreadsheets (.xls, .xlsx)
- PDF files (.pdf)
- Images (.png, .jpg, .jpeg)

Enjoy learning with Edinfinite and the Smart Index!
EOT

# Sample documents
echo "Elephants are the largest land animals on Earth. They have long trunks that they use like an arm." > data/sample_docs/elephants.txt
echo "The solar system has eight planets: Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, and Neptune." > data/sample_docs/solar_system.txt
echo "Dinosaurs lived millions of years ago. The T-Rex was one of the biggest meat-eating dinosaurs." > data/sample_docs/dinosaurs.txt

# Git setup
git init
echo "node_modules/" >> .gitignore
echo "chroma_db/" >> .gitignore
echo "__pycache__/" >> .gitignore
git add .
git commit -m "here we go...a mind set for making education journey even better...if only I had one other mind it would be a world beyond infinitely better...Will from Edinfinite. Thank you for your interest in making things better for yourself and for kids! Let's Go...and be even more kind to each other!"

echo "Setup complete! Run 'docker-compose up --build' to start the application."
