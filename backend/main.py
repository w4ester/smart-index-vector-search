import os
import logging
import chromadb
from chromadb.config import Settings
from chromadb.utils import embedding_functions

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from smart_index import SmartIndex
import shutil


app = FastAPI();

class SmartIndex:
    def __init__(self, root_dir):
        self.root_dir = root_dir
        persistence_dir = os.path.join(os.getcwd(), "chroma_db")
        logger.info(f"Using persistence directory: {persistence_dir}")
        self.chroma_client = chromadb.Client(Settings(persist_directory=persistence_dir))
        self.embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(model_name="all-MiniLM-L6-v2")
        self.collection = self.chroma_client.get_or_create_collection(
            name="edinfinite_docs", 
            embedding_function=self.embedding_function
        )
        logger.info(f"Initialized collection: {self.collection.name}")

    def build_index(self):
        logger.info("Starting to build index...")
        for root, _, files in os.walk(self.root_dir):
            for file in files:
                file_path = os.path.join(root, file)
                logger.info(f"Indexing file: {file_path}")
                self.add_document(file_path)
        logger.info("Finished building index.")

    def add_document(self, file_path):
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                content = file.read()
            self.collection.add(
                documents=[content],
                metadatas=[{"source": file_path}],
                ids=[file_path]
            )
            logger.info(f"Added document: {file_path}")
        except Exception as e:
            logger.error(f"Error adding document {file_path}: {str(e)}")

    def search(self, query, k=5, threshold=0.5):
        logger.info(f"Searching for query: '{query}'")
        if not query.strip():
            logger.info("Empty query received. Returning no results.")
            return []

        results = self.collection.query(
            query_texts=[query],
            n_results=k,
            include=['metadatas', 'distances']
        )
        logger.info(f"Raw ChromaDB results: {results}")
        
        formatted_results = []
        for i, (doc, metadata, distance) in enumerate(zip(results['documents'][0], results['metadatas'][0], results['distances'][0])):
            similarity = 1 - (distance / 2)  # Convert distance to similarity
            
            logger.info(f"Processing result {i}: file={metadata['source']}, distance={distance}, similarity={similarity}")
            
            if similarity > threshold:
                formatted_results.append({
                    "explanation": f"Found information in file: {os.path.basename(metadata['source'])} (Relevance: {similarity:.2f})",
                    "content": doc[:500] + '...' if len(doc) > 500 else doc,
                    "similarity": similarity
                })
            else:
                logger.info(f"Result {i} below threshold ({threshold}), skipping")
        
        formatted_results.sort(key=lambda x: x['similarity'], reverse=True)
        
        logger.info(f"Formatted search results: {formatted_results}")
        return formatted_results
    
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
