# SmartIndex for the Edinfinite

This project is a friendly Smart Index Vector Search System using Svelte with Vite for the frontend, Python FastAPI for the backend, and ChromaDB for vector storage and retrieval.

## Features

- Search through various document types (TXT, DOCX, XLS, XLSX, PDF, PNG, JPG)
- Citizen-friendly interface and explanations
- Easy document upload and indexing

## Setup

1. Install Docker and Docker Compose on your system.
2. Clone this repository and navigate to the project root.
3. Run `docker-compose up --build` to start the application.
4. Access the frontend at http://localhost:5174

## Usage

- Use the search bar to ask questions or look for information.
- Upload new documents using the upload feature (to be implemented in the frontend).

## Adding New Documents

To add new documents:
1. Place them in the `data/sample_docs` directory.
2. Restart the Docker containers to reindex the new documents.

## Supported File Types

- Text files (.txt)
- Word documents (.docx)
- Excel spreadsheets (.xls, .xlsx)
- PDF files (.pdf)
- Images (.png, .jpg, .jpeg)

Enjoy learning with Edinfinite and just one of its terrific tools -
Smart Index!
