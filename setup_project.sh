# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install required packages
pip install numpy scikit-learn sentence-transformers faiss-cpu pytest termcolor pyfiglet 

# Create smart_index.py
cat << EOT > smart_index.py
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
    root_directory = os.path.expanduser("~/smart_index_project")  # Change this to your preferred directory
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
EOT

# Create test_smart_index.py
cat << EOT > test_smart_index.py
import pytest
import tempfile
import os
from smart_index import SmartIndex

@pytest.fixture
def temp_dir_with_files():
    with tempfile.TemporaryDirectory() as tmpdirname:
        # Create some test files
        for i in range(5):
            with open(os.path.join(tmpdirname, f"test_file_{i}.txt"), "w") as f:
                f.write(f"This is test file {i} content.")
        yield tmpdirname

def test_index_files(temp_dir_with_files):
    smart_index = SmartIndex(temp_dir_with_files)
    smart_index.index_files()
    assert len(smart_index.files) == 5
    assert len(smart_index.content) == 5

def test_create_vector_representations(temp_dir_with_files):
    smart_index = SmartIndex(temp_dir_with_files)
    smart_index.index_files()
    vectors = smart_index.create_vector_representations()
    assert vectors.shape == (5, len(smart_index.vectorizer.get_feature_names_out()))

def test_create_semantic_representations(temp_dir_with_files):
    smart_index = SmartIndex(temp_dir_with_files)
    smart_index.index_files()
    vectors = smart_index.create_semantic_representations()
    assert vectors.shape == (5, 384)  # 384 is the default dimension for 'all-MiniLM-L6-v2'

def test_cluster_documents(temp_dir_with_files):
    smart_index = SmartIndex(temp_dir_with_files, num_clusters=2)
    smart_index.index_files()
    vectors = smart_index.create_vector_representations()
    clusters = smart_index.cluster_documents(vectors)
    assert len(clusters) == 5
    assert set(clusters) == {0, 1}

def test_build_faiss_index(temp_dir_with_files):
    smart_index = SmartIndex(temp_dir_with_files)
    smart_index.index_files()
    vectors = smart_index.create_semantic_representations()
    smart_index.build_faiss_index(vectors)
    assert smart_index.faiss_index is not None

def test_search(temp_dir_with_files):
    smart_index = SmartIndex(temp_dir_with_files)
    smart_index.build_index()
    results = smart_index.search("test file")
    assert len(results) == 5  # Should return all files as they all contain "test file"

def test_build_index(temp_dir_with_files):
    smart_index = SmartIndex(temp_dir_with_files)
    clusters = smart_index.build_index()
    assert len(clusters) == 5
    assert smart_index.faiss_index is not None

def test_error_handling():
    smart_index = SmartIndex("/non/existent/path")
    with pytest.raises(ValueError):
        smart_index.create_vector_representations()
    with pytest.raises(ValueError):
        smart_index.create_semantic_representations()
    with pytest.raises(ValueError):
        smart_index.search("test query")
EOT

# Create README.md
cat << EOT > README.md
# Smart Index Vector Search System

This project implements a smart index system for vector database k-cluster searches on local drives. It allows users to search for relevant documents based on project ideas or queries, utilizing TF-IDF vectorization, semantic embeddings, k-means clustering, and FAISS for efficient similarity search.

## Features

- Index text files from a specified local directory
- Create TF-IDF and semantic vector representations of documents
- Cluster similar documents using k-means
- Perform fast similarity search using FAISS
- Search for relevant documents based on user queries

## Requirements

- Python 3.7+
- numpy
- scikit-learn
- sentence-transformers
- faiss-cpu
- pytest
- termcolor
- pyfiglet

## Installation

1. Run the setup script:
   \`\`\`
   ./setup_project.sh
   \`\`\`

2. Activate the virtual environment:
   \`\`\`
   source venv/bin/activate
   \`\`\`

## Usage

1. Update the \`root_directory\` in the \`main\` function of \`smart_index.py\` to point to your local drive containing the documents you want to index.

2. Run the script:
   \`\`\`
   python smart_index.py
   \`\`\`

3. Enter your project ideas or queries when prompted. The system will return the most relevant documents from the indexed local drive.

4. Type 'quit' to exit the program.

## Running Tests

To run the unit tests:

\`\`\`
pytest test_smart_index.py
\`\`\`

## Contributing

Feel free to contribute to this project by submitting pull requests or opening issues for any bugs or feature requests.

## License

This project is licensed under the MIT License.
EOT

# Create sample documents for testing
mkdir -p sample_docs
echo "This is a sample document about Python programming." > sample_docs/python_intro.txt
echo "Machine learning is a subset of artificial intelligence." > sample_docs/ml_intro.md
echo "print('Hello, Jess!')" > sample_docs/hello_world.py

# Initialize git repository
git init
git add .
git commit -m "Initial commit"

# Create .gitignore
cat << EOT > .gitignore
venv/
__pycache__/
*.pyc
*.pyo
*.pyd
.pytest_cache/
EOT

git add .gitignore
git commit -m "Add .gitignore"

echo "Setup complete! Your Smart Index Vector Search System is now ready."
echo "To activate the virtual environment and run the main script:"
echo "source venv/bin/activate"
echo "python smart_index.py"
