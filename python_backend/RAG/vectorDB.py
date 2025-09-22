import os
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import Chroma
import sys, os
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from RAG.helper import extract_text_from_pdf


# === Paths ===
text_file_path = "data/vehicle-act.txt"
chroma_path = "vector_store/chroma_index"


def load_or_create_vectordb():
    # === STEP 1: Load or extract text ===
    if not os.path.exists(text_file_path):
        print("Extracting text from PDF...")
        text = extract_text_from_pdf("vehicle-act.pdf")
        os.makedirs("data", exist_ok=True)
        with open(text_file_path, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print("Loading text from file...")
        with open(text_file_path, "r", encoding="utf-8") as f:
            text = f.read()

    # === STEP 2: Split text ===
    splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
    chunks = splitter.create_documents([text])

    # === STEP 3: Setup embeddings + ChromaDB ===
    embeddings = HuggingFaceEmbeddings(model_name="BAAI/bge-small-en-v1.5")

    if os.path.exists(chroma_path):
        print("Loading ChromaDB from disk...")
        vector_store = Chroma(
            persist_directory=chroma_path,
            embedding_function=embeddings
        )
    else:
        print("Creating new ChromaDB...")
        vector_store = Chroma.from_documents(
            chunks, embeddings, persist_directory=chroma_path
        )
        vector_store.persist()

    return vector_store


if __name__ == "__main__":
    load_or_create_vectordb()