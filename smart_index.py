import os
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.cluster import KMeans
from sentence_transformers import SentenceTransformer
import faiss
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class SmartIndex:
    def __init__(self, root_dir, num_clusters=10):
        self.root_dir = root_dir
        self.num_clusters = num_clusters
        self.files = []
        self.content = []
        self.vectorizer = TfidfVectorizer(stop_words='english')
        self.sentence_transformer = SentenceTransformer('all-MiniLM-L6-v2')
        self.kmeans = KMeans(n_clusters=num_clusters)
        self.faiss_index = None

    def index_files(self):
        logging.info(f"Searching for files in: {self.root_dir}")
        for root, _, files in os.walk(self.root_dir):
            for file in files:
                if file.endswith(('.txt', '.md', '.py')):
                    file_path = os.path.join(root, file)
                    logging.info(f"Found file: {file_path}")
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                        self.files.append(file_path)
                        self.content.append(content)
                    except Exception as e:
                        logging.error(f"Error reading file {file_path}: {str(e)}")
        logging.info(f"Indexed {len(self.files)} files.")
        if len(self.files) == 0:
            logging.warning("No files were found to index.")

    def create_vector_representations(self):
        if not self.content:
            raise ValueError("No content to vectorize. Please index files first.")
        tfidf_matrix = self.vectorizer.fit_transform(self.content)
        return tfidf_matrix.toarray()

    def create_semantic_representations(self):
        if not self.content:
            raise ValueError("No content to vectorize. Please index files first.")
        return self.sentence_transformer.encode(self.content)

    def cluster_documents(self, vectors):
        if vectors.shape[0] < self.num_clusters:
            logging.warning("Number of documents is less than the number of clusters. Adjusting number of clusters.")
            self.num_clusters = vectors.shape[0]
            self.kmeans = KMeans(n_clusters=self.num_clusters)
        return self.kmeans.fit_predict(vectors)

    def build_faiss_index(self, vectors):
        dimension = vectors.shape[1]
        self.faiss_index = faiss.IndexFlatL2(dimension)
        self.faiss_index.add(vectors.astype('float32'))

    def search(self, query, k=5):
        if self.faiss_index is None:
            raise ValueError("FAISS index not built. Please build the index first.")
        query_vector = self.sentence_transformer.encode([query])
        _, indices = self.faiss_index.search(query_vector.astype('float32'), k)
        return [self.files[i] for i in indices[0]]

    def build_index(self):
        logging.info("Indexing files...")
        self.index_files()

        logging.info("Creating vector representations...")
        tfidf_vectors = self.create_vector_representations()
        semantic_vectors = self.create_semantic_representations()

        logging.info("Clustering documents...")
        clusters = self.cluster_documents(tfidf_vectors)

        logging.info("Building FAISS index...")
        self.build_faiss_index(semantic_vectors)

        logging.info("Index built successfully!")
        return clusters

def main():
    root_directory = os.path.join(os.getcwd(), "test_docs")
    smart_index = SmartIndex(root_directory)
    smart_index.build_index()
    
    while True:
        query = input("Enter your project idea (or 'quit' to exit): ")
        if query.lower() == 'quit':
            break

        try:
            results = smart_index.search(query)
            print("\nRelevant documents for your project:")
            for result in results:
                print(result)
            print()
        except Exception as e:
            logging.error(f"Error during search: {str(e)}")

if __name__ == "__main__":
    main()
