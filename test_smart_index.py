import pytest
import os
from smart_index import SmartIndex

@pytest.fixture
def test_dir_with_files():
    test_dir = os.path.join(os.getcwd(), "test_docs")
    return test_dir

def test_index_files(test_dir_with_files):
    smart_index = SmartIndex(test_dir_with_files)
    smart_index.index_files()
    assert len(smart_index.files) == 3  # We have 3 files in test_docs
    assert len(smart_index.content) == 3

def test_create_vector_representations(test_dir_with_files):
    smart_index = SmartIndex(test_dir_with_files)
    smart_index.index_files()
    vectors = smart_index.create_vector_representations()
    assert vectors.shape == (3, len(smart_index.vectorizer.get_feature_names_out()))

def test_create_semantic_representations(test_dir_with_files):
    smart_index = SmartIndex(test_dir_with_files)
    smart_index.index_files()
    vectors = smart_index.create_semantic_representations()
    assert vectors.shape == (3, 384)  # 384 is the default dimension for 'all-MiniLM-L6-v2'

def test_cluster_documents(test_dir_with_files):
    smart_index = SmartIndex(test_dir_with_files, num_clusters=2)
    smart_index.index_files()
    vectors = smart_index.create_vector_representations()
    clusters = smart_index.cluster_documents(vectors)
    assert len(clusters) == 3
    assert set(clusters) == {0, 1}

def test_build_faiss_index(test_dir_with_files):
    smart_index = SmartIndex(test_dir_with_files)
    smart_index.index_files()
    vectors = smart_index.create_semantic_representations()
    smart_index.build_faiss_index(vectors)
    assert smart_index.faiss_index is not None

def test_search(test_dir_with_files):
    smart_index = SmartIndex(test_dir_with_files)
    smart_index.build_index()
    results = smart_index.search("artificial intelligence")
    assert len(results) == 3  # Should return all files as they all contain related content

def test_build_index(test_dir_with_files):
    smart_index = SmartIndex(test_dir_with_files)
    clusters = smart_index.build_index()
    assert len(clusters) == 3
    assert smart_index.faiss_index is not None

def test_error_handling():
    smart_index = SmartIndex("/non/existent/path")
    with pytest.raises(ValueError):
        smart_index.create_vector_representations()
    with pytest.raises(ValueError):
        smart_index.create_semantic_representations()
    with pytest.raises(ValueError):
        smart_index.search("test query")
