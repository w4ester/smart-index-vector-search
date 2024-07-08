import os
import numpy as np
import chromadb
from chromadb.config import Settings
from chromadb.utils import embedding_functions

class SmartIndex:
    def __init__(self, root_dir):
        self.root_dir = root_dir
        self.chroma_client = chromadb.Client(Settings(persist_directory="./chroma_db"))
        self.embedding_function = embedding_functions.SentenceTransformerEmbeddingFunction(model_name="all-MiniLM-L6-v2")
        self.collection = self.chroma_client.get_or_create_collection(
            name="edinfinite_docs", 
            embedding_function=self.embedding_function
        )

    def build_index(self):
        print("Starting to build index...")
        for root, _, files in os.walk(self.root_dir):
            for file in files:
                file_path = os.path.join(root, file)
                print(f"Indexing file: {file_path}")
                self.add_document(file_path)
        print("Finished building index.")

    def add_document(self, file_path):
        with open(file_path, 'r') as file:
            content = file.read()
        self.collection.add(
            documents=[content],
            metadatas=[{"source": file_path}],
            ids=[file_path]
        )

    def search(self, query, k=5, threshold=0.5):
        print(f"Searching for query: '{query}'")
        if not query.strip():
            print("Empty query received. Returning no results.")
            return []

        results = self.collection.query(
            query_texts=[query],
            n_results=k,
            include=['metadatas', 'distances']
        )
        print(f"Raw ChromaDB results: {results}")
        
        formatted_results = []
        for i, (doc, metadata, distance) in enumerate(zip(results['documents'][0], results['metadatas'][0], results['distances'][0])):
            similarity = 1 - (distance / 2)  # Convert distance to similarity
            
            print(f"Processing result {i}: file={metadata['source']}, distance={distance}, similarity={similarity}")
            
            if similarity > threshold:
                formatted_results.append({
                    "explanation": f"Found information in file: {os.path.basename(metadata['source'])} (Relevance: {similarity:.2f})",
                    "content": doc[:500] + '...' if len(doc) > 500 else doc,
                    "similarity": similarity
                })
            else:
                print(f"Result {i} below threshold ({threshold}), skipping")
        
        formatted_results.sort(key=lambda x: x['similarity'], reverse=True)
        
        print(f"Formatted search results: {formatted_results}")
        return formatted_results